from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.core.secret_crypto import encrypt_secret
from app.db.session import SessionLocal
from app.models.brave_settings import BraveSettings
from app.models.runtime_setting import RuntimeSetting
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.services import runtime_settings as rs
from app.services.brave_api_key import get_brave_api_key, has_brave_api_key, mask_brave_key_for_admin
from app.services.realtime.brave_provider import fetch_brave


templates = Jinja2Templates(directory="app/templates")
router = APIRouter(include_in_schema=False)


def _db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _require_admin_web(request: Request, db: Session) -> User:
    admin_user_id = request.session.get("admin_user_id")
    if not admin_user_id:
        raise HTTPException(status_code=302, headers={"Location": "/admin/login"})
    admin = db.query(User).filter(User.id == admin_user_id).one_or_none()
    if not admin or admin.role != "admin" or not admin.is_active:
        request.session.pop("admin_user_id", None)
        raise HTTPException(status_code=302, headers={"Location": "/admin/login"})
    return admin


@router.get("/admin/login", response_class=HTMLResponse)
def admin_login_page(request: Request):
    return templates.TemplateResponse("admin/login.html", {"request": request, "app_name": settings.app_name})


@router.post("/admin/login")
def admin_login_submit(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(_db),
):
    user = db.query(User).filter(User.username == username).one_or_none()
    if not user or user.role != "admin" or not verify_password(password, user.password_hash) or not user.is_active:
        return templates.TemplateResponse(
            "admin/login.html",
            {"request": request, "app_name": settings.app_name, "error": "账号或密码错误"},
            status_code=401,
        )
    request.session["admin_user_id"] = str(user.id)
    db.add(UsageEvent(user_id=user.id, session_id=None, event_type="admin_login", meta_json=None))
    db.commit()
    return RedirectResponse(url="/admin/users", status_code=303)


@router.post("/admin/logout")
def admin_logout(request: Request):
    request.session.pop("admin_user_id", None)
    return RedirectResponse(url="/admin/login", status_code=303)


@router.get("/admin/settings", response_class=HTMLResponse)
def admin_settings_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    ocfg = rs.effective_openai_config(db)
    dcfg = rs.effective_deepseek_config(db)
    gcfg = rs.effective_gemini_config(db)
    row_ob = db.get(RuntimeSetting, rs.KEY_OPENAI_BASE_URL)
    row_op = db.get(RuntimeSetting, rs.KEY_OPENAI_PROXY)
    row_db = db.get(RuntimeSetting, rs.KEY_DEEPSEEK_BASE_URL)
    row_dp = db.get(RuntimeSetting, rs.KEY_DEEPSEEK_PROXY)
    row_dm = db.get(RuntimeSetting, rs.KEY_DEEPSEEK_MODEL_TEXT)
    row_gb = db.get(RuntimeSetting, rs.KEY_GEMINI_BASE_URL)
    row_gp = db.get(RuntimeSetting, rs.KEY_GEMINI_PROXY)
    fernet_ok = bool((settings.field_encryption_fernet_key or "").strip())
    return templates.TemplateResponse(
        "admin/settings.html",
        {
            "request": request,
            "admin": admin,
            "app_name": settings.app_name,
            "openai_base_url_effective": ocfg.base_url,
            "openai_proxy_effective": ocfg.proxy,
            "deepseek_base_url_effective": dcfg.base_url,
            "deepseek_proxy_effective": dcfg.proxy,
            "deepseek_model_effective": dcfg.model,
            "openai_base_url_input": (row_ob.value if row_ob else "") or "",
            "openai_proxy_input": (row_op.value if row_op else "") or "",
            "deepseek_base_url_input": (row_db.value if row_db else "") or "",
            "deepseek_proxy_input": (row_dp.value if row_dp else "") or "",
            "deepseek_model_input": (row_dm.value if row_dm else "") or "",
            "gemini_base_url_effective": gcfg.base_url,
            "gemini_proxy_effective": gcfg.proxy,
            "gemini_base_url_input": (row_gb.value if row_gb else "") or "",
            "gemini_proxy_input": (row_gp.value if row_gp else "") or "",
            "openai_key_stored_in_db": rs.has_db_openai_key(db),
            "deepseek_key_stored_in_db": rs.has_db_deepseek_key(db),
            "gemini_key_stored_in_db": rs.has_db_gemini_key(db),
            "openai_key_masked": rs.mask_runtime_api_key_for_admin(db, rs.KEY_OPENAI_API_KEY),
            "deepseek_key_masked": rs.mask_runtime_api_key_for_admin(db, rs.KEY_DEEPSEEK_API_KEY),
            "gemini_key_masked": rs.mask_runtime_api_key_for_admin(db, rs.KEY_GEMINI_API_KEY),
            "fernet_ok": fernet_ok,
            "saved_ok": request.query_params.get("ok") == "1",
            "err": request.query_params.get("err") or "",
        },
    )


@router.post("/admin/settings")
def admin_settings_save(
    request: Request,
    openai_api_key: str = Form(""),
    clear_openai_api_key: str = Form(None),
    openai_base_url: str = Form(""),
    openai_proxy: str = Form(""),
    deepseek_api_key: str = Form(""),
    clear_deepseek_api_key: str = Form(None),
    deepseek_base_url: str = Form(""),
    deepseek_proxy: str = Form(""),
    deepseek_model_text: str = Form(""),
    gemini_api_key: str = Form(""),
    clear_gemini_api_key: str = Form(None),
    gemini_base_url: str = Form(""),
    gemini_proxy: str = Form(""),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)

    try:
        if clear_openai_api_key == "on":
            rs.delete_setting(db, rs.KEY_OPENAI_API_KEY)
        elif openai_api_key.strip():
            rs.upsert_encrypted_secret(db, rs.KEY_OPENAI_API_KEY, openai_api_key.strip())

        t = openai_base_url.strip()
        if t:
            rs.upsert_setting(db, rs.KEY_OPENAI_BASE_URL, t)
        else:
            rs.delete_setting(db, rs.KEY_OPENAI_BASE_URL)

        p = openai_proxy.strip()
        if p:
            rs.upsert_setting(db, rs.KEY_OPENAI_PROXY, p)
        else:
            rs.delete_setting(db, rs.KEY_OPENAI_PROXY)

        if clear_deepseek_api_key == "on":
            rs.delete_setting(db, rs.KEY_DEEPSEEK_API_KEY)
        elif deepseek_api_key.strip():
            rs.upsert_encrypted_secret(db, rs.KEY_DEEPSEEK_API_KEY, deepseek_api_key.strip())

        dt = deepseek_base_url.strip()
        if dt:
            rs.upsert_setting(db, rs.KEY_DEEPSEEK_BASE_URL, dt)
        else:
            rs.delete_setting(db, rs.KEY_DEEPSEEK_BASE_URL)

        dpx = deepseek_proxy.strip()
        if dpx:
            rs.upsert_setting(db, rs.KEY_DEEPSEEK_PROXY, dpx)
        else:
            rs.delete_setting(db, rs.KEY_DEEPSEEK_PROXY)

        dm = deepseek_model_text.strip()
        if dm:
            rs.upsert_setting(db, rs.KEY_DEEPSEEK_MODEL_TEXT, dm)
        else:
            rs.delete_setting(db, rs.KEY_DEEPSEEK_MODEL_TEXT)

        if clear_gemini_api_key == "on":
            rs.delete_setting(db, rs.KEY_GEMINI_API_KEY)
        elif gemini_api_key.strip():
            rs.upsert_encrypted_secret(db, rs.KEY_GEMINI_API_KEY, gemini_api_key.strip())

        gt = gemini_base_url.strip()
        if gt:
            rs.upsert_setting(db, rs.KEY_GEMINI_BASE_URL, gt)
        else:
            rs.delete_setting(db, rs.KEY_GEMINI_BASE_URL)

        gp = gemini_proxy.strip()
        if gp:
            rs.upsert_setting(db, rs.KEY_GEMINI_PROXY, gp)
        else:
            rs.delete_setting(db, rs.KEY_GEMINI_PROXY)

        db.commit()
    except ValueError:
        db.rollback()
        return RedirectResponse(url="/admin/settings?err=fernet", status_code=303)

    return RedirectResponse(url="/admin/settings?ok=1", status_code=303)


@router.get("/admin/users", response_class=HTMLResponse)
def admin_users_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    users = db.query(User).filter(User.role == "user").order_by(User.created_at.desc()).all()
    return templates.TemplateResponse(
        "admin/users.html",
        {
            "request": request,
            "admin": admin,
            "users": users,
            "app_name": settings.app_name,
            "sys_default_web": rs.default_new_user_can_web_search(db),
        },
    )


@router.post("/admin/users")
def admin_create_user(
    request: Request,
    username: str = Form(...),
    temp_password: str = Form(...),
    can_web_search_mode: str = Form("default"),
    can_upload: str = Form(None),
    is_active: str = Form(None),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    if db.query(User).filter(User.username == username).count() > 0:
        return RedirectResponse(url="/admin/users?error=user_exists", status_code=303)
    if can_web_search_mode == "on":
        cw = True
    elif can_web_search_mode == "off":
        cw = False
    else:
        cw = rs.default_new_user_can_web_search(db)
    u = User(
        username=username,
        password_hash=hash_password(temp_password),
        role="user",
        is_active=is_active == "on",
        must_change_password=False,
        can_web_search=cw,
        can_upload=can_upload == "on",
        default_model="chatgpt-5.2",
        last_login_at=None,
        login_count=0,
        chat_message_count=0,
        failed_login_count=0,
    )
    db.add(u)
    db.commit()
    return RedirectResponse(url="/admin/users", status_code=303)


@router.get("/admin/users/{user_id}", response_class=HTMLResponse)
def admin_user_detail(request: Request, user_id: str, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    u = db.query(User).filter(User.id == user_id, User.role == "user").one_or_none()
    if not u:
        return RedirectResponse(url="/admin/users?error=not_found", status_code=303)
    return templates.TemplateResponse(
        "admin/user_detail.html",
        {"request": request, "admin": admin, "u": u, "app_name": settings.app_name},
    )


@router.post("/admin/users/{user_id}/reset-password")
def admin_reset_password(
    request: Request,
    user_id: str,
    new_temp_password: str = Form(...),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    u = db.query(User).filter(User.id == user_id, User.role == "user").one_or_none()
    if not u:
        return RedirectResponse(url="/admin/users?error=not_found", status_code=303)
    u.password_hash = hash_password(new_temp_password)
    u.must_change_password = True
    db.add(u)
    db.add(UsageEvent(user_id=u.id, session_id=None, event_type="reset_password", meta_json=None))
    db.commit()
    return RedirectResponse(url=f"/admin/users/{user_id}?ok=reset", status_code=303)


@router.post("/admin/users/{user_id}/toggle-active")
def admin_toggle_active(request: Request, user_id: str, db: Session = Depends(_db)):
    _require_admin_web(request, db)
    u = db.query(User).filter(User.id == user_id, User.role == "user").one_or_none()
    if not u:
        return RedirectResponse(url="/admin/users?error=not_found", status_code=303)
    u.is_active = not u.is_active
    db.add(u)
    db.commit()
    return RedirectResponse(url=f"/admin/users/{user_id}", status_code=303)


@router.post("/admin/users/{user_id}/permissions")
def admin_update_permissions(
    request: Request,
    user_id: str,
    can_web_search: str = Form(None),
    can_upload: str = Form(None),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    u = db.query(User).filter(User.id == user_id, User.role == "user").one_or_none()
    if not u:
        return RedirectResponse(url="/admin/users?error=not_found", status_code=303)
    u.can_web_search = can_web_search == "on"
    u.can_upload = can_upload == "on"
    db.add(u)
    db.commit()
    return RedirectResponse(url=f"/admin/users/{user_id}?ok=permissions", status_code=303)


@router.post("/admin/users/{user_id}/delete")
def admin_delete_user(request: Request, user_id: str, db: Session = Depends(_db)):
    _require_admin_web(request, db)
    u = db.query(User).filter(User.id == user_id, User.role == "user").one_or_none()
    if not u:
        return RedirectResponse(url="/admin/users?error=not_found", status_code=303)
    db.delete(u)
    db.commit()
    return RedirectResponse(url="/admin/users?ok=deleted", status_code=303)


def _get_or_create_brave_row(db: Session) -> BraveSettings:
    row = db.get(BraveSettings, 1)
    if row is None:
        row = BraveSettings(id=1)
        db.add(row)
        db.flush()
    return row


@router.get("/admin/brave", response_class=HTMLResponse)
def admin_brave_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    row = _get_or_create_brave_row(db)
    blob_ok = has_brave_api_key(row)
    fernet_ok = bool((settings.field_encryption_fernet_key or "").strip())
    return templates.TemplateResponse(
        "admin/brave.html",
        {
            "request": request,
            "admin": admin,
            "app_name": settings.app_name,
            "b": row,
            "api_key_masked": mask_brave_key_for_admin(row),
            "fernet_ok": fernet_ok,
            "saved_ok": request.query_params.get("ok") == "1",
            "err": request.query_params.get("err") or "",
            "brave_key_missing": bool(row.brave_enabled) and not blob_ok,
        },
    )


@router.post("/admin/brave")
def admin_brave_save(
    request: Request,
    brave_enabled: str = Form(None),
    api_key: str = Form(""),
    clear_api_key: str = Form(None),
    base_url: str = Form(""),
    web_search_enabled: str = Form(None),
    news_search_enabled: str = Form(None),
    llm_context_enabled: str = Form(None),
    default_result_count: str = Form("8"),
    timeout_seconds: str = Form("15"),
    country: str = Form("cn"),
    search_lang: str = Form("zh-hans"),
    cache_enabled: str = Form(None),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    row = _get_or_create_brave_row(db)
    row.brave_enabled = brave_enabled == "on"
    row.web_search_enabled = web_search_enabled == "on"
    row.news_search_enabled = news_search_enabled == "on"
    row.llm_context_enabled = llm_context_enabled == "on"
    try:
        row.default_result_count = max(1, min(20, int(default_result_count or "8")))
    except ValueError:
        row.default_result_count = 8
    try:
        row.timeout_seconds = max(3, min(120, int(timeout_seconds or "15")))
    except ValueError:
        row.timeout_seconds = 15
    row.country = (country or "cn").strip()[:8] or "cn"
    row.search_lang = (search_lang or "zh-hans").strip()[:16] or "zh-hans"
    row.cache_enabled = cache_enabled == "on"
    bu = (base_url or "").strip()
    if bu:
        row.base_url = bu[:256]
    if clear_api_key == "on":
        row.api_key_encrypted = None
        row.api_key_plain = None
    elif api_key.strip():
        try:
            row.api_key_encrypted = encrypt_secret(api_key.strip())
            row.api_key_plain = None
        except ValueError:
            db.rollback()
            return RedirectResponse(url="/admin/brave?err=fernet", status_code=303)

    if row.brave_enabled and not has_brave_api_key(row):
        db.rollback()
        return RedirectResponse(url="/admin/brave?err=need_key", status_code=303)

    row.updated_at = datetime.now(timezone.utc)
    db.add(row)
    db.commit()
    return RedirectResponse(url="/admin/brave?ok=1", status_code=303)


@router.post("/admin/brave/test")
async def admin_brave_test(request: Request, db: Session = Depends(_db)):
    _require_admin_web(request, db)
    row = _get_or_create_brave_row(db)
    key = get_brave_api_key(row)
    row.last_test_at = datetime.now(timezone.utc)
    if not row.brave_enabled:
        row.last_test_ok = False
        row.last_test_message = "Brave 总开关未开启"
    elif not key.strip():
        row.last_test_ok = False
        row.last_test_message = "API Key 未配置"
    else:
        out = await fetch_brave(
            api_key=key,
            base_url=row.base_url or "https://api.search.brave.com",
            query="Brave Search API",
            web_on=bool(row.web_search_enabled),
            news_on=bool(row.news_search_enabled),
            llm_context_on=bool(row.llm_context_enabled),
            count=min(3, int(row.default_result_count or 8)),
            timeout_sec=float(row.timeout_seconds or 15),
            country=row.country or "cn",
            search_lang=row.search_lang or "zh-hans",
            use_cache=False,
        )
        row.last_test_ok = out.status == "ok"
        if out.status == "ok":
            row.last_test_message = f"成功，合并来源约 {len(out.sources)} 条"
        else:
            row.last_test_message = (out.message or out.status)[:4000]
    db.add(row)
    db.commit()
    return RedirectResponse(url="/admin/brave?ok=1", status_code=303)


@router.get("/admin/realtime", response_class=HTMLResponse)
def admin_realtime_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    row = db.get(BraveSettings, 1)
    return templates.TemplateResponse(
        "admin/realtime_status.html",
        {
            "request": request,
            "admin": admin,
            "app_name": settings.app_name,
            "b": row,
            "fernet_ok": bool((settings.field_encryption_fernet_key or "").strip()),
            "brave_key_usable": has_brave_api_key(row) if row else False,
            "brave_key_masked": mask_brave_key_for_admin(row),
        },
    )


@router.get("/admin/system-defaults", response_class=HTMLResponse)
def admin_system_defaults_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    return templates.TemplateResponse(
        "admin/system_defaults.html",
        {
            "request": request,
            "admin": admin,
            "app_name": settings.app_name,
            "default_web": rs.default_new_user_can_web_search(db),
            "fernet_ok": bool((settings.field_encryption_fernet_key or "").strip()),
            "saved_ok": request.query_params.get("ok") == "1",
        },
    )


@router.post("/admin/system-defaults")
def admin_system_defaults_save(
    request: Request,
    default_new_user_web_search: str = Form(None),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    rs.upsert_default_new_user_can_web_search(db, default_new_user_web_search == "on")
    db.commit()
    return RedirectResponse(url="/admin/system-defaults?ok=1", status_code=303)

