from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_current_user, get_db
from app.schemas.llm import RouteModelItem, RouteModelsResponse
from app.services import runtime_settings as rs


router = APIRouter()


def _route_item(*, route: str, label: str, resolved: str, is_openai: bool) -> RouteModelItem:
    return RouteModelItem(
        route=route,
        label=label,
        resolved_model=resolved,
        resolved_openai_model=resolved,
        is_openai=is_openai,
    )


@router.get("", response_model=RouteModelsResponse)
def list_route_models(_: object = Depends(get_current_user), db: Session = Depends(get_db)) -> RouteModelsResponse:
    """
    给客户端返回「路由模型」与「实际 provider model id」的映射。
    resolved_model 与 resolved_openai_model 同值（后者兼容旧客户端）。
    """
    dcfg = rs.effective_deepseek_config(db)
    return RouteModelsResponse(
        items=[
            _route_item(
                route="chatgpt-5.2",
                label="GPT-5.2",
                resolved=settings.openai_model_chatgpt_52,
                is_openai=True,
            ),
            _route_item(
                route="chatgpt-5.4",
                label="GPT-5.4",
                resolved=settings.openai_model_chatgpt_54,
                is_openai=True,
            ),
            _route_item(
                route="gemini-flash",
                label="Gemini Flash",
                resolved=settings.gemini_model_flash,
                is_openai=False,
            ),
            _route_item(
                route="gemini-pro",
                label="Gemini Pro",
                resolved=settings.gemini_model_pro,
                is_openai=False,
            ),
            _route_item(
                route="deepseek",
                label="DeepSeek",
                resolved=dcfg.model,
                is_openai=False,
            ),
        ]
    )
