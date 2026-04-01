from __future__ import annotations

from pydantic import BaseModel, Field


class RouteModelItem(BaseModel):
    route: str = Field(description="客户端/接口使用的路由 model 标识，如 chatgpt-5.2")
    label: str = Field(description="用于展示的模型名称")
    resolved_openai_model: str = Field(description="后端配置映射后的 OpenAI model id")
    is_openai: bool = True


class RouteModelsResponse(BaseModel):
    items: list[RouteModelItem]

