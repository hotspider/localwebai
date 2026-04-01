from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.user import MeResponse, OkResponse, UpdateDefaultModelRequest


router = APIRouter()


def _err(code: str, message: str, http_status: int) -> HTTPException:
    return HTTPException(status_code=http_status, detail={"error": {"code": code, "message": message, "details": {}}})


@router.get("", response_model=MeResponse)
def me(user: User = Depends(get_current_user)) -> MeResponse:
    return MeResponse(
        id=str(user.id),
        username=user.username,
        role=user.role,
        is_active=user.is_active,
        must_change_password=user.must_change_password,
        can_web_search=user.can_web_search,
        can_upload=user.can_upload,
        default_model=user.default_model,
    )


@router.patch("/default-model", response_model=OkResponse)
def set_default_model(
    req: UpdateDefaultModelRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OkResponse:
    user.default_model = req.default_model
    db.add(user)
    db.add(UsageEvent(user_id=user.id, session_id=None, event_type="set_default_model", meta_json={"model": req.default_model}))
    db.commit()
    return OkResponse(ok=True)

