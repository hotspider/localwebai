from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import attachments, auth, chat, me, models, sessions


api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(me.router, prefix="/me", tags=["me"])
api_router.include_router(models.router, prefix="/models", tags=["models"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(attachments.router, prefix="/attachments", tags=["attachments"])

