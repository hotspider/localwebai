from __future__ import annotations

from typing import Final

# 客户端与 API 使用的 model 标识；展示名由客户端决定
LLM_MODEL_PATTERN: Final[str] = (
    r"^(chatgpt|chatgpt-5\.2|chatgpt-5\.4|deepseek|gemini-flash|gemini-pro)$"
)
DEFAULT_LLM_MODEL: Final[str] = "chatgpt-5.2"


def is_openai_route(model: str) -> bool:
    return model in frozenset({"chatgpt", "chatgpt-5.2", "chatgpt-5.4"})


def is_gemini_route(model: str) -> bool:
    return model in frozenset({"gemini-flash", "gemini-pro"})


def supports_vision_route(model: str) -> bool:
    return is_openai_route(model) or is_gemini_route(model)


def openai_completion_model_id(route_model: str) -> str:
    """将 API 路由 model 映射为 OpenAI Chat Completions 的 model 字段。"""
    from app.core.config import settings

    if route_model in ("chatgpt", "chatgpt-5.2"):
        return settings.openai_model_chatgpt_52
    if route_model == "chatgpt-5.4":
        return settings.openai_model_chatgpt_54
    raise ValueError(f"not an OpenAI route model: {route_model}")


def gemini_completion_model_id(route_model: str) -> str:
    from app.core.config import settings

    if route_model == "gemini-flash":
        return settings.gemini_model_flash
    if route_model == "gemini-pro":
        return settings.gemini_model_pro
    raise ValueError(f"not a Gemini route model: {route_model}")
