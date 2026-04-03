from __future__ import annotations

from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_current_user, get_db
from app.models.attachment import Attachment
from app.models.chat_session import ChatSession
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.attachment import (
    AttachmentListResponse,
    AttachmentOut,
    CommitRequest,
    CommitResponse,
    PresignRequest,
    PresignResponse,
)
from app.services.attachments.extract_text import extract_text_from_docx, extract_text_from_pdf, extract_text_from_txt
from app.services.attachments.storage import SupabaseStorage, get_storage_driver
from app.services.attachments.public_links import verify_attachment_token
from app.services.attachments.validators import POLICY, validate_attachment_request


router = APIRouter()


def _err(code: str, message: str, http_status: int, details: dict | None = None) -> HTTPException:
    return HTTPException(
        status_code=http_status,
        detail={"error": {"code": code, "message": message, "details": details or {}}},
    )


@router.post("/presign", response_model=PresignResponse)
def presign(
    req: PresignRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> PresignResponse:
    if not user.can_upload:
        raise _err("FORBIDDEN", "当前账号不允许上传附件", status.HTTP_403_FORBIDDEN)

    try:
        validate_attachment_request(content_type=req.content_type, size_bytes=req.size_bytes)
    except ValueError as e:
        raise _err("VALIDATION_ERROR", str(e), status.HTTP_422_UNPROCESSABLE_ENTITY)

    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == req.session_id, ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
        .one_or_none()
    )
    if not session:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)

    active_count = (
        db.query(func.count(Attachment.id))
        .filter(
            Attachment.session_id == session.id,
            Attachment.user_id == user.id,
            Attachment.deleted_at.is_(None),
            Attachment.status == "active",
        )
        .scalar()
        or 0
    )
    if int(active_count) >= POLICY.max_attachments_per_session:
        raise _err("VALIDATION_ERROR", "单个会话最多 5 个附件", status.HTTP_422_UNPROCESSABLE_ENTITY)

    storage = get_storage_driver()
    if settings.storage_driver == "local":
        bucket = "local"
    elif settings.storage_driver == "supabase":
        bucket = settings.supabase_bucket
    elif settings.storage_driver == "cos":
        bucket = settings.cos_bucket
    else:
        bucket = "local"
    attachment = Attachment(
        session_id=session.id,
        user_id=user.id,
        filename=req.filename,
        content_type=req.content_type,
        size_bytes=req.size_bytes,
        storage_bucket=bucket,
        storage_path="",  # set after id is known
        status="active",
        deleted_at=None,
    )
    db.add(attachment)
    db.flush()

    object_path = storage.make_object_path(
        user_id=str(user.id), session_id=str(session.id), attachment_id=str(attachment.id), filename=req.filename
    )
    attachment.storage_path = object_path
    db.add(attachment)
    db.commit()

    upload_spec = storage.presign_put(bucket=attachment.storage_bucket, object_path=object_path, content_type=req.content_type)

    return PresignResponse(
        attachment_id=str(attachment.id),
        bucket=attachment.storage_bucket,
        object_path=object_path,
        upload={"method": upload_spec.method, "url": upload_spec.url, "headers": upload_spec.headers},
    )


@router.put("/upload/{bucket}/{object_path:path}")
async def local_upload(bucket: str, object_path: str, request: Request) -> Response:
    storage = get_storage_driver()
    body = await request.body()
    if len(body) > POLICY.max_file_bytes:
        raise _err("VALIDATION_ERROR", "File too large", status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)

    if settings.storage_driver == "local":
        p: Path = storage.resolve_local_path(bucket=bucket, object_path=object_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(body)
        return Response(status_code=200, content=b"")

    if settings.storage_driver == "supabase":
        assert isinstance(storage, SupabaseStorage)
        storage.upload_bytes(bucket=bucket, object_path=object_path, content_type=request.headers.get("content-type") or "application/octet-stream", data=body)
        return Response(status_code=200, content=b"")

    raise _err("FORBIDDEN", "Unsupported storage driver", status.HTTP_403_FORBIDDEN)


@router.post("/commit", response_model=CommitResponse)
def commit(
    req: CommitRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommitResponse:
    attachment = (
        db.query(Attachment)
        .filter(Attachment.id == req.attachment_id, Attachment.user_id == user.id, Attachment.deleted_at.is_(None))
        .one_or_none()
    )
    if not attachment or attachment.status != "active":
        raise _err("NOT_FOUND", "Attachment not found", status.HTTP_404_NOT_FOUND)

    # Extract text for text-like attachments
    extracted: str | None = None
    storage = get_storage_driver()
    raw: bytes | None = None
    try:
        raw = storage.read_bytes(bucket=attachment.storage_bucket, object_path=attachment.storage_path)
    except Exception:
        raw = None

    if raw is None:
        raise _err("NOT_FOUND", "Uploaded file not found", status.HTTP_404_NOT_FOUND)

    if attachment.content_type in ("text/plain", "application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"):
        # write temp to disk for parsers
        import tempfile

        suffix = ".bin"
        if attachment.content_type == "text/plain":
            suffix = ".txt"
        elif attachment.content_type == "application/pdf":
            suffix = ".pdf"
        elif attachment.content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            suffix = ".docx"
        with tempfile.NamedTemporaryFile(delete=True, suffix=suffix) as f:
            f.write(raw)
            f.flush()
            p = Path(f.name)
            if attachment.content_type == "text/plain":
                extracted = extract_text_from_txt(p)
            elif attachment.content_type == "application/pdf":
                extracted = extract_text_from_pdf(p)
            else:
                extracted = extract_text_from_docx(p)

    attachment.extracted_text = extracted
    db.add(attachment)
    db.add(UsageEvent(user_id=user.id, session_id=attachment.session_id, event_type="upload", meta_json={"content_type": attachment.content_type, "size_bytes": int(attachment.size_bytes)}))
    db.commit()
    db.refresh(attachment)

    return CommitResponse(
        attachment=AttachmentOut(
            id=str(attachment.id),
            session_id=str(attachment.session_id),
            filename=attachment.filename,
            content_type=attachment.content_type,
            size_bytes=int(attachment.size_bytes),
            created_at=attachment.created_at.isoformat(),
        )
    )


## 注意：会话附件列表的冻结接口为：
## GET /api/sessions/{session_id}/attachments
## （已在 sessions 路由中实现）


@router.get("/{attachment_id}/file")
def download_attachment_file(
    attachment_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Response:
    """登录用户下载/预览本人会话附件（供 App 内图片、PDF 等预览）。"""
    attachment = (
        db.query(Attachment)
        .filter(
            Attachment.id == attachment_id,
            Attachment.user_id == user.id,
            Attachment.deleted_at.is_(None),
            Attachment.status == "active",
        )
        .one_or_none()
    )
    if not attachment:
        raise _err("NOT_FOUND", "Attachment not found", status.HTTP_404_NOT_FOUND)

    storage = get_storage_driver()
    try:
        raw = storage.read_bytes(bucket=attachment.storage_bucket, object_path=attachment.storage_path)
    except Exception:
        raise _err("NOT_FOUND", "File not found", status.HTTP_404_NOT_FOUND)

    media = attachment.content_type or "application/octet-stream"
    fn = (attachment.filename or "file").replace('"', "_")
    return Response(
        content=raw,
        media_type=media,
        headers={"Content-Disposition": f'inline; filename="{fn}"'},
    )


@router.delete("/{attachment_id}")
def delete_attachment(
    attachment_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    attachment = (
        db.query(Attachment)
        .filter(Attachment.id == attachment_id, Attachment.user_id == user.id, Attachment.deleted_at.is_(None))
        .one_or_none()
    )
    if not attachment or attachment.status != "active":
        raise _err("NOT_FOUND", "Attachment not found", status.HTTP_404_NOT_FOUND)

    attachment.status = "deleted"
    attachment.deleted_at = datetime.utcnow()
    db.add(attachment)

    # delete object
    storage = get_storage_driver()
    try:
        storage.delete_object(bucket=attachment.storage_bucket, object_path=attachment.storage_path)
    except Exception:
        pass

    db.add(UsageEvent(user_id=user.id, session_id=attachment.session_id, event_type="delete_attachment", meta_json=None))
    db.commit()
    return {"ok": True}


@router.get("/public/{attachment_id}")
def public_attachment(
    attachment_id: str,
    token: str,
    db: Session = Depends(get_db),
) -> Response:
    """
    供模型侧拉取的“临时公开附件链接”。
    - 不要求登录（OpenAI 拉取时不会带 Bearer token）
    - 使用 itsdangerous 签名 + 过期时间保护
    """
    try:
        verified_id = verify_attachment_token(token, max_age_seconds=10 * 60)
    except ValueError:
        raise _err("FORBIDDEN", "Invalid token", status.HTTP_403_FORBIDDEN)
    if verified_id != attachment_id:
        raise _err("FORBIDDEN", "Invalid token", status.HTTP_403_FORBIDDEN)

    attachment = db.query(Attachment).filter(Attachment.id == attachment_id, Attachment.deleted_at.is_(None), Attachment.status == "active").one_or_none()
    if not attachment:
        raise _err("NOT_FOUND", "Attachment not found", status.HTTP_404_NOT_FOUND)

    storage = get_storage_driver()
    try:
        raw = storage.read_bytes(bucket=attachment.storage_bucket, object_path=attachment.storage_path)
    except Exception:
        raise _err("NOT_FOUND", "File not found", status.HTTP_404_NOT_FOUND)

    return Response(content=raw, media_type=attachment.content_type)

