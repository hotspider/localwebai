from __future__ import annotations

from typing import TYPE_CHECKING

from app.core.config import settings
from app.services.intelligence.llm_classifier import (
    classify_task_deepseek,
    classify_task_gemini,
    classify_task_llm,
)
from app.services.intelligence.rule_classifier import classify_by_rules
from app.services.intelligence.task_types import TaskType

if TYPE_CHECKING:
    from sqlalchemy.orm import Session


async def resolve_task_type(
    *,
    text: str,
    has_image_attachment: bool,
    attachment_extracted_text: str,
    db: "Session",
) -> tuple[TaskType, str]:
    """
    规则优先；规则未命中且开启特性时尝试轻量模型（带超时）。
    OpenAI Key 不可用时依次尝试 DeepSeek、Gemini（与主对话线路一致）。
    返回 (TaskType, reason_tag)。
    """
    rt, reason = classify_by_rules(
        text=text,
        has_image_attachment=has_image_attachment,
        attachment_extracted_text=attachment_extracted_text,
    )
    if rt is not None:
        return rt, reason

    if not settings.feature_task_classification:
        return TaskType.UNKNOWN, "feature:off"

    from app.services.runtime_settings import effective_deepseek_config, effective_gemini_config, effective_openai_config

    timeout_s = max(0.05, settings.classifier_timeout_ms / 1000.0)
    user_message = text or attachment_extracted_text[:2000]

    ocfg = effective_openai_config(db)
    if (ocfg.api_key or "").strip():
        return await classify_task_llm(
            user_message=user_message,
            api_key=ocfg.api_key,
            base_url=ocfg.base_url,
            proxy=ocfg.proxy or "",
            model=settings.classifier_model,
            timeout_seconds=timeout_s,
        )

    dcfg = effective_deepseek_config(db)
    if (dcfg.api_key or "").strip():
        return await classify_task_deepseek(
            user_message=user_message,
            api_key=dcfg.api_key,
            base_url=dcfg.base_url,
            proxy=dcfg.proxy or "",
            model=settings.classifier_model_deepseek,
            timeout_seconds=timeout_s,
        )

    gcfg = effective_gemini_config(db)
    if (gcfg.api_key or "").strip():
        return await classify_task_gemini(
            user_message=user_message,
            api_key=gcfg.api_key,
            base_url=gcfg.base_url,
            proxy=gcfg.proxy or "",
            model=settings.gemini_model_flash,
            timeout_seconds=timeout_s,
        )

    return TaskType.UNKNOWN, "llm:no_key"
