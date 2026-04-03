from __future__ import annotations

import asyncio
import logging
import re

from app.services.intelligence.task_types import TaskType
from app.services.llm.deepseek_client import DeepSeekClient
from app.services.llm.gemini_client import GeminiClient
from app.services.llm.openai_client import OpenAIClient

logger = logging.getLogger(__name__)

_CLASSIFIER_PROMPT = """你是一个任务分类器。用户消息如下：
---
{user_message}
---
从以下类型中选择最匹配的一个，只返回类型名称，不要解释：
QA_FACTUAL / QA_REASONING / CODE_GENERATE / CODE_DEBUG / CODE_EXPLAIN /
TEXT_SUMMARIZE / TEXT_TRANSLATE / TEXT_REWRITE / CREATIVE_WRITE /
IMAGE_ANALYZE / IMAGE_OCR / DATA_ANALYZE / DOC_QA / SEARCH_REQUIRED /
CONVERSATION / TASK_PLANNING / UNKNOWN"""

_ENUM_RE = re.compile(
    r"\b(QA_FACTUAL|QA_REASONING|CODE_GENERATE|CODE_DEBUG|CODE_EXPLAIN|TEXT_SUMMARIZE|TEXT_TRANSLATE|"
    r"TEXT_REWRITE|CREATIVE_WRITE|IMAGE_ANALYZE|IMAGE_OCR|DATA_ANALYZE|DOC_QA|SEARCH_REQUIRED|"
    r"CONVERSATION|TASK_PLANNING|UNKNOWN)\b",
    re.I,
)


def _parse_classifier_output(raw: str) -> tuple[TaskType, str]:
    m = _ENUM_RE.search((raw or "").strip())
    if not m:
        return TaskType.UNKNOWN, "llm:unparseable"
    return TaskType.from_raw(m.group(1)), "llm:ok"


def _classifier_messages(user_message: str) -> list[dict]:
    return [
        {"role": "system", "content": "只输出一个英文大写枚举名，不要标点或解释。"},
        {"role": "user", "content": _CLASSIFIER_PROMPT.format(user_message=user_message[:6000])},
    ]


async def classify_task_llm(
    *,
    user_message: str,
    api_key: str,
    base_url: str,
    proxy: str,
    model: str,
    timeout_seconds: float,
) -> tuple[TaskType, str]:
    client = OpenAIClient(api_key=api_key, base_url=base_url, proxy=proxy)
    try:
        resp = await asyncio.wait_for(
            client.chat_text(messages=_classifier_messages(user_message), model=model),
            timeout=timeout_seconds,
        )
    except TimeoutError:
        logger.warning("task classifier LLM timeout (%.0fms)", timeout_seconds * 1000)
        return TaskType.UNKNOWN, "llm:timeout"
    except Exception as e:
        logger.warning("task classifier LLM error: %s", e)
        return TaskType.UNKNOWN, f"llm:error:{type(e).__name__}"
    tt, inner = _parse_classifier_output(resp.text or "")
    if inner == "llm:unparseable":
        return tt, inner
    return tt, "llm:ok_openai"


async def classify_task_deepseek(
    *,
    user_message: str,
    api_key: str,
    base_url: str,
    proxy: str,
    model: str,
    timeout_seconds: float,
) -> tuple[TaskType, str]:
    client = DeepSeekClient(api_key=api_key, base_url=base_url, proxy=proxy)
    try:
        resp = await asyncio.wait_for(
            client.chat_text(messages=_classifier_messages(user_message), model=model),
            timeout=timeout_seconds,
        )
    except TimeoutError:
        logger.warning("task classifier DeepSeek timeout (%.0fms)", timeout_seconds * 1000)
        return TaskType.UNKNOWN, "llm:timeout"
    except Exception as e:
        logger.warning("task classifier DeepSeek error: %s", e)
        return TaskType.UNKNOWN, f"llm:error:{type(e).__name__}"
    tt, inner = _parse_classifier_output(resp.text or "")
    if inner == "llm:unparseable":
        return tt, inner
    return tt, "llm:ok_deepseek"


async def classify_task_gemini(
    *,
    user_message: str,
    api_key: str,
    base_url: str,
    proxy: str,
    model: str,
    timeout_seconds: float,
) -> tuple[TaskType, str]:
    client = GeminiClient(api_key=api_key, base_url=base_url, proxy=proxy)
    try:
        resp = await asyncio.wait_for(
            client.chat(messages=_classifier_messages(user_message), model=model),
            timeout=timeout_seconds,
        )
    except TimeoutError:
        logger.warning("task classifier Gemini timeout (%.0fms)", timeout_seconds * 1000)
        return TaskType.UNKNOWN, "llm:timeout"
    except Exception as e:
        logger.warning("task classifier Gemini error: %s", e)
        return TaskType.UNKNOWN, f"llm:error:{type(e).__name__}"
    tt, inner = _parse_classifier_output(resp.text or "")
    if inner == "llm:unparseable":
        return tt, inner
    return tt, "llm:ok_gemini"
