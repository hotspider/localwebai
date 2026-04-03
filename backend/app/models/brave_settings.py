from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BraveSettings(Base):
    """单行配置：id 固定为 1。"""

    __tablename__ = "brave_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)

    brave_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    # 历史迁移：曾明文存 Key；新保存一律写入 api_key_encrypted（Fernet），并清空本列
    api_key_plain: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    api_key_encrypted: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    base_url: Mapped[str] = mapped_column(String(256), nullable=False, server_default="https://api.search.brave.com")

    web_search_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    news_search_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    llm_context_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")

    default_result_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="8")
    timeout_seconds: Mapped[int] = mapped_column(Integer, nullable=False, server_default="15")
    country: Mapped[str] = mapped_column(String(8), nullable=False, server_default="cn")
    search_lang: Mapped[str] = mapped_column(String(16), nullable=False, server_default="zh-hans")
    cache_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    last_test_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_test_ok: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    last_test_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
