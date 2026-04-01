from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx

from app.core.config import settings
from app.services.llm.base import LlmClient, LlmResponse

logger = logging.getLogger(__name__)

# 含「Server disconnected without sending a response」等，多为链路/代理间歇断开，可重试
_OPENAI_TRANSPORT_RETRY = (
    httpx.RemoteProtocolError,
    httpx.ReadError,
    httpx.ConnectError,
    httpx.WriteError,
    httpx.ConnectTimeout,
    httpx.ReadTimeout,
    httpx.PoolTimeout,
)
_OPENAI_MAX_ATTEMPTS = 4


def _openai_connection_hint() -> str:
    return (
        " 排查：1) 运行后端的环境能否访问 OPENAI_BASE_URL（curl 测连通）；"
        "2) 若浏览器可用但后端不通，通常是后端进程未走系统代理：请在后端环境配置 OPENAI_PROXY / HTTPS_PROXY；"
        "3) 确认 OPENAI_API_KEY 有效、模型名与网关一致。"
    )


def _message_content_to_text(content: Any) -> str:
    """Normalize OpenAI Chat Completions message.content (str | list | null)."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    parts.append(str(block.get("text") or ""))
                elif "text" in block:
                    parts.append(str(block["text"]))
            elif isinstance(block, str):
                parts.append(block)
        return "".join(parts)
    return str(content)


class OpenAIClient(LlmClient):
    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        proxy: str | None = None,
    ) -> None:
        self.api_key = settings.openai_api_key if api_key is None else api_key
        base = settings.openai_base_url if base_url is None else base_url
        self.base_url = base.rstrip("/")
        self._proxy = (settings.openai_proxy if proxy is None else proxy).strip() or None

    async def chat_text(self, *, messages: list[dict], model: str) -> LlmResponse:
        if not self.api_key:
            raise RuntimeError(
                "OPENAI_API_KEY 未配置：请在管理后台「LLM 配置」填写，或在后端 .env 中设置 OPENAI_API_KEY"
            )

        url = f"{self.base_url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {"model": model, "messages": messages}
        timeout = httpx.Timeout(180.0, connect=60.0, pool=30.0)
        limits = httpx.Limits(max_keepalive_connections=2, max_connections=10)
        proxy = self._proxy
        data: dict[str, Any] | None = None
        last_transport: httpx.RequestError | None = None

        async def _attempt(*, http2: bool) -> dict[str, Any]:
            # 一些本地代理在大请求 + HTTP/2 下更容易被重置；失败时会自动降级到 HTTP/1.1 再试
            h = dict(headers)
            if not http2:
                h["Connection"] = "close"
            async with httpx.AsyncClient(
                timeout=timeout,
                http2=http2,
                trust_env=True,
                limits=limits,
                proxy=proxy,
            ) as client:
                r = await client.post(url, headers=h, json=payload)
                r.raise_for_status()
                return r.json()

        for attempt in range(_OPENAI_MAX_ATTEMPTS):
            try:
                try:
                    data = await _attempt(http2=True)
                except httpx.RemoteProtocolError:
                    data = await _attempt(http2=False)
                break
            except httpx.HTTPStatusError as e:
                body = (e.response.text or "")[:800]
                raise RuntimeError(f"OpenAI 接口返回 {e.response.status_code}: {body}") from e
            except httpx.RequestError as e:
                last_transport = e
                is_retryable = isinstance(e, _OPENAI_TRANSPORT_RETRY)
                if is_retryable and attempt < _OPENAI_MAX_ATTEMPTS - 1:
                    wait_s = min(0.8 * (2**attempt), 6.0)
                    logger.warning(
                        "OpenAI 传输异常 (%s/%s)，%.1fs 后重试: %s",
                        attempt + 1,
                        _OPENAI_MAX_ATTEMPTS,
                        wait_s,
                        e,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                raise RuntimeError(f"无法连接 OpenAI：{e}\n{_openai_connection_hint()}") from e

        if data is None:
            assert last_transport is not None
            raise RuntimeError(
                f"无法连接 OpenAI：{last_transport}\n{_openai_connection_hint()}"
            ) from last_transport

        try:
            choice = data["choices"][0]
            msg = choice["message"]
        except (KeyError, IndexError, TypeError) as e:
            raise RuntimeError(f"OpenAI 响应格式异常：{data!r}") from e

        text = _message_content_to_text(msg.get("content"))
        if not text and msg.get("refusal"):
            text = str(msg.get("refusal"))
        return LlmResponse(text=text or "")

    async def chat(self, *, messages: list[dict], model: str) -> LlmResponse:
        """
        OpenAI Chat Completions wrapper.
        Supports text-only and multimodal message content (e.g. image_url blocks).
        """
        return await self.chat_text(messages=messages, model=model)
