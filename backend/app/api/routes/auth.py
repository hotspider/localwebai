from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    LoginResponse,
    LogoutResponse,
    OkResponse,
    UserOut,
)


router = APIRouter()


def _err(code: str, message: str, http_status: int) -> HTTPException:
    return HTTPException(status_code=http_status, detail={"error": {"code": code, "message": message, "details": {}}})


@router.post("/login", response_model=LoginResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)) -> LoginResponse:
    user = db.query(User).filter(User.username == req.username).one_or_none()
    if not user or not verify_password(req.password, user.password_hash):
        if user:
            user.failed_login_count += 1
            db.add(user)
            db.commit()
        raise _err("UNAUTHORIZED", "账号或密码错误", status.HTTP_401_UNAUTHORIZED)

    if not user.is_active:
        raise _err("FORBIDDEN", "账号已被禁用", status.HTTP_403_FORBIDDEN)

    user.last_login_at = datetime.now(timezone.utc)
    user.login_count += 1
    user.failed_login_count = 0
    db.add(user)
    db.add(UsageEvent(user_id=user.id, session_id=None, event_type="login", meta_json=None))
    db.commit()

    token = create_access_token(subject=str(user.id))
    return LoginResponse(
        access_token=token,
        user=UserOut(
            id=str(user.id),
            username=user.username,
            role=user.role,
            is_active=user.is_active,
            must_change_password=user.must_change_password,
            can_web_search=user.can_web_search,
            can_upload=user.can_upload,
            default_model=user.default_model,
        ),
    )


@router.post("/logout", response_model=LogoutResponse)
def logout(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> LogoutResponse:
    db.add(UsageEvent(user_id=user.id, session_id=None, event_type="logout", meta_json=None))
    db.commit()
    return LogoutResponse(ok=True)


@router.post("/change-password", response_model=OkResponse)
def change_password(
    req: ChangePasswordRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> OkResponse:
    if not verify_password(req.old_password, user.password_hash):
        raise _err("UNAUTHORIZED", "旧密码错误", status.HTTP_401_UNAUTHORIZED)

    user.password_hash = hash_password(req.new_password)
    user.must_change_password = False
    db.add(user)
    db.add(UsageEvent(user_id=user.id, session_id=None, event_type="change_password", meta_json=None))
    db.commit()
    return OkResponse(ok=True)

