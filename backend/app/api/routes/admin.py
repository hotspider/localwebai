from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.db.session import SessionLocal
from app.models.usage_event import UsageEvent
from app.models.user import User


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


@router.get("/admin/users", response_class=HTMLResponse)
def admin_users_page(request: Request, db: Session = Depends(_db)):
    admin = _require_admin_web(request, db)
    users = db.query(User).filter(User.role == "user").order_by(User.created_at.desc()).all()
    return templates.TemplateResponse(
        "admin/users.html",
        {"request": request, "admin": admin, "users": users, "app_name": settings.app_name},
    )


@router.post("/admin/users")
def admin_create_user(
    request: Request,
    username: str = Form(...),
    temp_password: str = Form(...),
    can_web_search: str = Form(None),
    can_upload: str = Form(None),
    is_active: str = Form(None),
    db: Session = Depends(_db),
):
    _require_admin_web(request, db)
    if db.query(User).filter(User.username == username).count() > 0:
        return RedirectResponse(url="/admin/users?error=user_exists", status_code=303)
    u = User(
        username=username,
        password_hash=hash_password(temp_password),
        role="user",
        is_active=is_active == "on",
        must_change_password=False,
        can_web_search=can_web_search == "on",
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

