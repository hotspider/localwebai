from __future__ import annotations

from pydantic import BaseModel, Field


class AdminCreateUserRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    temp_password: str = Field(min_length=8, max_length=256)
    can_web_search: bool = False
    can_upload: bool = True
    is_active: bool = True


class AdminResetPasswordRequest(BaseModel):
    new_temp_password: str = Field(min_length=8, max_length=256)

