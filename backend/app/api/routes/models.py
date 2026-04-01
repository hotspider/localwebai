from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.config import settings
from app.core.deps import get_current_user
from app.schemas.llm import RouteModelItem, RouteModelsResponse


router = APIRouter()


@router.get("", response_model=RouteModelsResponse)
def list_route_models(_: object = Depends(get_current_user)) -> RouteModelsResponse:
    """
    给客户端返回“路由模型”与“实际 OpenAI model id”的映射，用于前端展示与一致性校验。
    注意：这里不返回 key 等敏感信息。
    """
    return RouteModelsResponse(
        items=[
            RouteModelItem(
                route="chatgpt-5.2",
                label="GPT-5.2",
                resolved_openai_model=settings.openai_model_chatgpt_52,
                is_openai=True,
            ),
            RouteModelItem(
                route="chatgpt-5.4",
                label="GPT-5.4",
                resolved_openai_model=settings.openai_model_chatgpt_54,
                is_openai=True,
            ),
        ]
    )

