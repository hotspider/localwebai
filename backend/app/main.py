from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware
from starlette.responses import JSONResponse

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

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):  # type: ignore[override]
        return JSONResponse(
            status_code=500,
            content={"error": {"code": "INTERNAL_ERROR", "message": "Internal server error", "details": {}}},
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

