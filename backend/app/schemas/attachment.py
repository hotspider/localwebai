from __future__ import annotations

from pydantic import BaseModel, Field


class PresignRequest(BaseModel):
    session_id: str
    filename: str = Field(min_length=1, max_length=512)
    content_type: str = Field(min_length=1, max_length=128)
    size_bytes: int = Field(gt=0)


class PresignResponse(BaseModel):
    attachment_id: str
    bucket: str
    object_path: str
    upload: dict


class CommitRequest(BaseModel):
    attachment_id: str


class AttachmentOut(BaseModel):
    id: str
    session_id: str
    filename: str
    content_type: str
    size_bytes: int
    created_at: str


class CommitResponse(BaseModel):
    attachment: AttachmentOut


class AttachmentListResponse(BaseModel):
    items: list[AttachmentOut]

