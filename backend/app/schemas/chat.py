from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field

from app.core.llm_models import DEFAULT_LLM_MODEL, LLM_MODEL_PATTERN


def attachment_ids_from_column(raw: object | None) -> list[str]:
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(x) for x in raw]
    return []


class SourceItem(BaseModel):
    title: str = ""
    url: str
    snippet: str = ""
    provider: str = "brave"
    type: str = "web"


class MessageOut(BaseModel):
    id: str
    role: str
    content_text: str
    model: str
    web_search_enabled: bool
    sources: list[SourceItem] = Field(default_factory=list)
    created_at: str
    realtime_meta: Optional[dict[str, Any]] = None
    attachment_ids: list[str] = Field(default_factory=list)


class ChatSendRequest(BaseModel):
    session_id: str
    model: str = Field(pattern=LLM_MODEL_PATTERN)
    web_search_enabled: bool = False
    # 允许“仅图片/附件不填文字”的提交；具体校验在路由中做
    text: str = Field(default="", max_length=8000)
    # 本次发送关联的会话附件 id（须为当前会话内 active 附件）；用于历史气泡展示与预览
    attachment_ids: list[str] = Field(default_factory=list)


class ChatSendResponse(BaseModel):
    user_message: MessageOut
    assistant_message: MessageOut
    # 首条用户发送后由后端生成；客户端可据此更新顶栏/侧栏标题
    session_title: str = ""
    # 智能化流水线：旧客户端可忽略以下字段
    task_type: str = "UNKNOWN"
    warnings: list[str] = Field(default_factory=list)
    intelligence: dict[str, Any] = Field(default_factory=dict)


class SessionCreateRequest(BaseModel):
    title: str = ""
    default_model: str = Field(default=DEFAULT_LLM_MODEL, pattern=LLM_MODEL_PATTERN)


class SessionOut(BaseModel):
    id: str
    title: str
    default_model: str
    created_at: str
    updated_at: str


class SessionCreateResponse(BaseModel):
    session: SessionOut


class SessionListItem(BaseModel):
    id: str
    title: str
    default_model: str
    last_message_at: Optional[str] = None
    attachment_count: int = 0


class SessionListResponse(BaseModel):
    items: list[SessionListItem]
    total: int


class AttachmentSummary(BaseModel):
    id: str
    filename: str
    content_type: str
    size_bytes: int
    created_at: str


class SessionDetailResponse(BaseModel):
    session: SessionOut
    attachments: list[AttachmentSummary]
    messages: list[MessageOut]

