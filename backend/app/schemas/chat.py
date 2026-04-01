from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field

from app.core.llm_models import DEFAULT_LLM_MODEL, LLM_MODEL_PATTERN


class SourceItem(BaseModel):
    title: str = ""
    url: str
    snippet: str = ""
    provider: str = "duckduckgo"


class MessageOut(BaseModel):
    id: str
    role: str
    content_text: str
    model: str
    web_search_enabled: bool
    sources: list[SourceItem] = Field(default_factory=list)
    created_at: str


class ChatSendRequest(BaseModel):
    session_id: str
    model: str = Field(pattern=LLM_MODEL_PATTERN)
    web_search_enabled: bool = False
    # 允许“仅图片/附件不填文字”的提交；具体校验在路由中做
    text: str = Field(default="", max_length=8000)


class ChatSendResponse(BaseModel):
    user_message: MessageOut
    assistant_message: MessageOut
    # 首条用户发送后由后端生成；客户端可据此更新顶栏/侧栏标题
    session_title: str = ""


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

