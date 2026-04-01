from __future__ import annotations

from typing import Annotated, Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.session import SessionLocal
from app.models.user import User


def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


bearer = HTTPBearer(auto_error=False)


def _forbidden(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail={"error": {"code": "FORBIDDEN", "message": message, "details": {}}},
    )


def _unauthorized(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"error": {"code": "UNAUTHORIZED", "message": message, "details": {}}},
    )


def get_current_user(
    db: Annotated[Session, Depends(get_db)],
    creds: Annotated[Optional[HTTPAuthorizationCredentials], Depends(bearer)],
) -> User:
    if not creds or not creds.credentials:
        raise _unauthorized("Missing access token")
    try:
        payload = decode_token(creds.credentials)
    except Exception:
        raise _unauthorized("Invalid access token")

    sub = payload.get("sub")
    if not sub:
        raise _unauthorized("Invalid access token")

    user = db.query(User).filter(User.id == sub).one_or_none()
    if not user:
        raise _unauthorized("Invalid access token")
    if not user.is_active:
        raise _forbidden("Account disabled")
    return user


def require_admin(user: Annotated[User, Depends(get_current_user)]) -> User:
    if user.role != "admin":
        raise _forbidden("Admin only")
    return user


def get_admin_session_user(request: Request) -> Optional[str]:
    # admin web uses signed cookie session
    return request.session.get("admin_user_id") if hasattr(request, "session") else None

