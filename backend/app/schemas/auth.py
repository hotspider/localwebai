from __future__ import annotations

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=256)


class UserOut(BaseModel):
    id: str
    username: str
    role: str
    is_active: bool
    must_change_password: bool
    can_web_search: bool
    can_upload: bool
    default_model: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class LogoutResponse(BaseModel):
    ok: bool = True


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(min_length=1, max_length=256)
    new_password: str = Field(min_length=8, max_length=256)


class OkResponse(BaseModel):
    ok: bool = True

