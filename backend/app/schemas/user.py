from __future__ import annotations

from pydantic import BaseModel, Field

from app.core.llm_models import LLM_MODEL_PATTERN


class MeResponse(BaseModel):
    id: str
    username: str
    role: str
    is_active: bool
    must_change_password: bool
    can_web_search: bool
    can_upload: bool
    default_model: str


class UpdateDefaultModelRequest(BaseModel):
    default_model: str = Field(pattern=LLM_MODEL_PATTERN)


class OkResponse(BaseModel):
    ok: bool = True

