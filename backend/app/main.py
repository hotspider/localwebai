from __future__ import annotations

import html
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware
from starlette.responses import HTMLResponse, JSONResponse

from app.api.router import api_router
from app.api.routes.admin import router as admin_router
from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import engine
from app.models import user as _user  # noqa: F401  (ensure model import)
from app.models.user import User
from app.core.security import hash_password
from sqlalchemy.orm import Session


def create_app() -> FastAPI:
    configure_logging()
    app = FastAPI(title=settings.app_name)

    allow_origins = [o.strip() for o in settings.cors_allow_origins.split(",") if o.strip()]
    if allow_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=allow_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.jwt_secret,
        same_site=settings.session_cookie_samesite,
        https_only=settings.session_cookie_secure,
    )
    app.mount("/static", StaticFiles(directory="app/static"), name="static")

    _log = logging.getLogger("app.unhandled")

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):  # type: ignore[override]
        _log.exception("%s %s", request.method, request.url.path)
        # 管理后台是 HTML：不要返回 JSON，否则用户会看到 {"error":"INTERNAL_ERROR"...} 且无从排查
        if request.url.path.startswith("/admin"):
            dev_hint = ""
            if (settings.environment or "").lower() == "dev":
                safe = f"{type(exc).__name__}: {exc!s}"
                if len(safe) > 800:
                    safe = safe[:800] + "…"
                dev_hint = (
                    "<pre style='background:#f6f6f6;padding:12px;overflow:auto'>"
                    f"{html.escape(safe)}</pre>"
                )
            return HTMLResponse(
                status_code=500,
                content=(
                    "<!doctype html><html lang=zh-CN><head><meta charset=utf-8><title>管理后台错误</title></head><body>"
                    "<h1>管理后台页面加载失败</h1>"
                    "<p>常见于<strong>数据库未执行最新迁移</strong>（例如缺少 <code>brave_settings</code> 表）。"
                    "请在服务器进入后端目录或容器内执行：</p>"
                    "<pre style='background:#eee;padding:10px'>alembic upgrade head</pre>"
                    "<p>Docker 部署一般会在容器启动时自动执行；若仍报错，请查看 <code>docker compose logs backend</code>。</p>"
                    f"{dev_hint}"
                    "<p><a href=\"/admin/users\">返回用户管理</a> · <a href=\"/admin/settings\">LLM 配置</a></p>"
                    "</body></html>"
                ),
            )
        details: dict = {}
        if (settings.environment or "").lower() == "dev":
            safe = f"{type(exc).__name__}: {exc!s}"
            if len(safe) > 800:
                safe = safe[:800] + "…"
            details["dev_message"] = safe
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "Internal server error",
                    "details": details,
                }
            },
        )

    app.include_router(api_router, prefix="/api")
    app.include_router(admin_router)

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    @app.on_event("startup")
    def ensure_admin_user() -> None:
        # minimal bootstrap: create admin if none exists
        from app.db.session import SessionLocal

        db: Session = SessionLocal()
        try:
            admin = db.query(User).filter(User.role == "admin").first()
            if admin:
                return
            u = User(
                username=settings.admin_username,
                password_hash=hash_password(settings.admin_password),
                role="admin",
                is_active=True,
                must_change_password=False,
                can_web_search=True,
                can_upload=True,
                default_model="chatgpt-5.2",
            )
            db.add(u)
            db.commit()
        finally:
            db.close()

    return app


app = create_app()

