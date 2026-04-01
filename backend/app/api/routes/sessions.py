from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.attachment import Attachment
from app.models.chat_message import ChatMessage
from app.models.chat_session import ChatSession
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.chat import (
    AttachmentSummary,
    MessageOut,
    SessionCreateRequest,
    SessionCreateResponse,
    SessionDetailResponse,
    SessionListItem,
    SessionListResponse,
    SessionOut,
    SourceItem,
)


router = APIRouter()


def _err(code: str, message: str, http_status: int) -> HTTPException:
    return HTTPException(status_code=http_status, detail={"error": {"code": code, "message": message, "details": {}}})


@router.post("", response_model=SessionCreateResponse)
def create_session(
    req: SessionCreateRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> SessionCreateResponse:
    s = ChatSession(user_id=user.id, title=req.title or "", default_model=req.default_model)
    db.add(s)
    db.add(UsageEvent(user_id=user.id, session_id=s.id, event_type="create_session", meta_json={"default_model": s.default_model}))
    db.commit()
    db.refresh(s)
    return SessionCreateResponse(
        session=SessionOut(
            id=str(s.id),
            title=s.title,
            default_model=s.default_model,
            created_at=s.created_at.isoformat(),
            updated_at=s.updated_at.isoformat(),
        )
    )


@router.get("", response_model=SessionListResponse)
def list_sessions(
    limit: int = 50, offset: int = 0, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> SessionListResponse:
    q = db.query(ChatSession).filter(ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
    sessions = q.order_by(ChatSession.updated_at.desc()).limit(limit).offset(offset).all()

    items: list[SessionListItem] = []
    for s in sessions:
        last_msg_at = (
            db.query(func.max(ChatMessage.created_at))
            .filter(ChatMessage.session_id == s.id, ChatMessage.deleted_at.is_(None))
            .scalar()
        )
        attach_count = (
            db.query(func.count(Attachment.id))
            .filter(Attachment.session_id == s.id, Attachment.deleted_at.is_(None), Attachment.status == "active")
            .scalar()
        )
        # 过滤空会话：没有任何消息且没有附件的不进入历史列表
        if not isinstance(last_msg_at, datetime) and int(attach_count or 0) == 0:
            continue
        items.append(
            SessionListItem(
                id=str(s.id),
                title=s.title,
                default_model=s.default_model,
                last_message_at=last_msg_at.isoformat() if isinstance(last_msg_at, datetime) else None,
                attachment_count=int(attach_count or 0),
            )
        )
    return SessionListResponse(items=items, total=len(items))


@router.get("/{session_id}", response_model=SessionDetailResponse)
def get_session_detail(session_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> SessionDetailResponse:
    s = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
        .one_or_none()
    )
    if not s:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)

    attachments = (
        db.query(Attachment)
        .filter(Attachment.session_id == s.id, Attachment.deleted_at.is_(None), Attachment.status == "active")
        .order_by(Attachment.created_at.asc())
        .all()
    )
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == s.id, ChatMessage.deleted_at.is_(None))
        .order_by(ChatMessage.created_at.asc())
        .limit(200)
        .all()
    )

    att_out = [
        AttachmentSummary(
            id=str(a.id),
            filename=a.filename,
            content_type=a.content_type,
            size_bytes=int(a.size_bytes),
            created_at=a.created_at.isoformat(),
        )
        for a in attachments
    ]
    msg_out = []
    for m in messages:
        sources = []
        if isinstance(m.sources_json, list):
            for sitem in m.sources_json:
                if isinstance(sitem, dict) and sitem.get("url"):
                    sources.append(SourceItem(**sitem))
        msg_out.append(
            MessageOut(
                id=str(m.id),
                role=m.role,
                content_text=m.content_text,
                model=m.model,
                web_search_enabled=bool(m.web_search_enabled),
                sources=sources,
                created_at=m.created_at.isoformat(),
            )
        )

    return SessionDetailResponse(
        session=SessionOut(
            id=str(s.id),
            title=s.title,
            default_model=s.default_model,
            created_at=s.created_at.isoformat(),
            updated_at=s.updated_at.isoformat(),
        ),
        attachments=att_out,
        messages=msg_out,
    )


@router.get("/{session_id}/attachments")
def list_session_attachments(session_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    # 与冻结 API 对齐：GET /api/sessions/{session_id}/attachments
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
        .one_or_none()
    )
    if not session:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)

    items = (
        db.query(Attachment)
        .filter(Attachment.session_id == session.id, Attachment.user_id == user.id, Attachment.deleted_at.is_(None), Attachment.status == "active")
        .order_by(Attachment.created_at.asc())
        .all()
    )
    return {
        "items": [
            {
                "id": str(a.id),
                "session_id": str(a.session_id),
                "filename": a.filename,
                "content_type": a.content_type,
                "size_bytes": int(a.size_bytes),
                "created_at": a.created_at.isoformat(),
            }
            for a in items
        ]
    }


@router.delete("/{session_id}")
def delete_session(session_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    s = db.query(ChatSession).filter(ChatSession.id == session_id, ChatSession.user_id == user.id).one_or_none()
    if not s or s.deleted_at is not None:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)
    s.deleted_at = datetime.utcnow()
    db.add(s)
    db.add(UsageEvent(user_id=user.id, session_id=s.id, event_type="delete_session", meta_json=None))
    db.commit()
    return {"ok": True}

