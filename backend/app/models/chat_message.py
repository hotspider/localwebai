from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("chat_sessions.id"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)

    role: Mapped[str] = mapped_column(String(16), nullable=False)  # user | assistant | system
    content_text: Mapped[str] = mapped_column(Text, nullable=False)
    model: Mapped[str] = mapped_column(String(32), nullable=False)
    web_search_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    sources_json: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)
    realtime_meta: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)
    # 本条用户消息发送时勾选的附件（uuid 字符串列表）；assistant 为空
    attachment_ids: Mapped[Optional[Any]] = mapped_column(JSONB, nullable=True)

    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

