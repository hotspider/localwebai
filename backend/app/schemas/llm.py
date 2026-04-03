from __future__ import annotations

from pydantic import BaseModel, Field


class RouteModelItem(BaseModel):
    route: str = Field(description="客户端/接口使用的路由 model 标识，如 chatgpt-5.2")
    label: str = Field(description="用于展示的模型名称")
    resolved_model: str = Field(
        description="各线路实际调用的提供商 model id（推荐使用本字段；与 resolved_openai_model 同值）"
    )
    resolved_openai_model: str = Field(
        description="历史字段名：与 resolved_model 相同，兼容旧客户端"
    )
    is_openai: bool = Field(
        default=True,
        description="是否为 OpenAI Chat Completions 兼容线路（ChatGPT=true；Gemini/DeepSeek=false）",
    )


class RouteModelsResponse(BaseModel):
    items: list[RouteModelItem]

