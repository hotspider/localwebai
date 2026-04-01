from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    username: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)

    role: Mapped[str] = mapped_column(String(16), nullable=False)  # admin | user
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    must_change_password: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")

    can_web_search: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    can_upload: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")

    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    login_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    chat_message_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    failed_login_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    default_model: Mapped[str] = mapped_column(String(32), nullable=False, server_default="chatgpt")

