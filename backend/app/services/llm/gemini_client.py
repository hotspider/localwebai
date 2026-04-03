from __future__ import annotations

import asyncio
import base64
import logging
from typing import Any

import httpx

from app.services.llm.base import LlmResponse

logger = logging.getLogger(__name__)

_GEMINI_TRANSPORT_RETRY = (
    httpx.RemoteProtocolError,
    httpx.ReadError,
    httpx.ConnectError,
    httpx.WriteError,
    httpx.ConnectTimeout,
    httpx.ReadTimeout,
    httpx.PoolTimeout,
)
_GEMINI_MAX_ATTEMPTS = 4


def _sniff_image_mime(raw: bytes) -> str | None:
    if len(raw) >= 3 and raw[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if len(raw) >= 8 and raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(raw) >= 6 and raw[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    return None


def _split_system_and_rest(messages: list[dict]) -> tuple[str, list[dict]]:
    systems: list[str] = []
    rest: list[dict] = []
    for m in messages:
        role = m.get("role")
        c = m.get("content")
        if role == "system":
            if isinstance(c, str):
                systems.append(c)
            else:
                systems.append(str(c))
        else:
            rest.append(m)
    return "\n\n".join(s for s in systems if s.strip()), rest


def _map_role(role: str) -> str:
    return "model" if role == "assistant" else "user"


async def _fetch_image_as_inline(
    client: httpx.AsyncClient, url: str
) -> dict[str, Any]:
    r = await client.get(url, follow_redirects=True, timeout=60.0)
    r.raise_for_status()
    raw = r.content
    ct = (r.headers.get("content-type") or "").split(";")[0].strip().lower()
    sniffed = _sniff_image_mime(raw)
    allowed = frozenset({"image/jpeg", "image/png", "image/webp", "image/gif"})
    if sniffed:
        mime = sniffed
    elif ct in allowed:
        mime = ct
    else:
        mime = "image/jpeg"
    b64 = base64.standard_b64encode(raw).decode("ascii")
    return {"inlineData": {"mimeType": mime, "data": b64}}


async def _openai_content_to_gemini_parts(content: Any, client: httpx.AsyncClient) -> list[dict[str, Any]]:
    if isinstance(content, str):
        return [{"text": content}] if content else [{"text": ""}]
    if isinstance(content, list):
        parts: list[dict[str, Any]] = []
        for block in content:
            if not isinstance(block, dict):
                continue
            t = block.get("type")
            if t == "text":
                parts.append({"text": str(block.get("text") or "")})
            elif t == "image_url":
                u = (block.get("image_url") or {}).get("url") or ""
                if u:
                    parts.append(await _fetch_image_as_inline(client, u))
        return parts if parts else [{"text": ""}]
    return [{"text": ""}]


async def _build_gemini_body(messages: list[dict], client: httpx.AsyncClient) -> dict[str, Any]:
    sys_text, rest = _split_system_and_rest(messages)
    body: dict[str, Any] = {"contents": []}
    if sys_text.strip():
        body["systemInstruction"] = {"parts": [{"text": sys_text}]}

    contents: list[dict[str, Any]] = []
    for m in rest:
        role = _map_role(str(m.get("role") or "user"))
        parts = await _openai_content_to_gemini_parts(m.get("content"), client)
        contents.append({"role": role, "parts": parts})

    if contents and contents[0]["role"] != "user":
        contents.insert(0, {"role": "user", "parts": [{"text": "（继续上文）"}]})

    body["contents"] = contents
    return body


def _response_text(data: dict[str, Any]) -> str:
    cands = data.get("candidates") or []
    if not cands:
        err = data.get("error") or {}
        msg = err.get("message") if isinstance(err, dict) else None
        if msg:
            raise RuntimeError(f"Gemini 接口错误：{msg}")
        raise RuntimeError(f"Gemini 无候选回复：{data!r}")
    c0 = cands[0]
    fr = c0.get("finishReason")
    if fr in ("SAFETY", "RECITATION", "OTHER"):
        raise RuntimeError(f"Gemini 结束原因：{fr}（可能被安全策略拦截）")
    parts = (c0.get("content") or {}).get("parts") or []
    texts: list[str] = []
    for p in parts:
        if isinstance(p, dict) and "text" in p:
            texts.append(str(p.get("text") or ""))
    return "".join(texts)


class GeminiClient:
    def __init__(self, *, api_key: str, base_url: str, proxy: str = "") -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.proxy = (proxy or "").strip()

    async def chat(self, *, messages: list[dict], model: str) -> LlmResponse:
        if not self.api_key:
            raise RuntimeError(
                "GEMINI_API_KEY 未配置：请在管理后台「LLM 配置」填写，或在 .env 设置 GEMINI_API_KEY"
            )

        # 官方 REST：models/{id}:generateContent；model 参数勿含 models/ 前缀
        mid = model.strip().removeprefix("models/")

        params = {"key": self.api_key}
        url = f"{self.base_url}/models/{mid}:generateContent"
        client_kw: dict[str, Any] = {"timeout": 120.0}
        if self.proxy:
            client_kw["proxy"] = self.proxy

        last_transport: httpx.RequestError | None = None
        data: dict[str, Any] | None = None

        async def _attempt() -> dict[str, Any]:
            async with httpx.AsyncClient(**client_kw) as client:
                body = await _build_gemini_body(messages, client)
                r = await client.post(url, params=params, json=body)
                r.raise_for_status()
                return r.json()

        for attempt in range(_GEMINI_MAX_ATTEMPTS):
            try:
                data = await _attempt()
                break
            except httpx.HTTPStatusError as e:
                body = (e.response.text or "")[:800]
                raise RuntimeError(f"Gemini 接口返回 {e.response.status_code}: {body}") from e
            except httpx.RequestError as e:
                last_transport = e
                is_retryable = isinstance(e, _GEMINI_TRANSPORT_RETRY)
                if is_retryable and attempt < _GEMINI_MAX_ATTEMPTS - 1:
                    wait_s = min(0.8 * (2**attempt), 6.0)
                    logger.warning(
                        "Gemini 传输异常 (%s/%s)，%.1fs 后重试: %s",
                        attempt + 1,
                        _GEMINI_MAX_ATTEMPTS,
                        wait_s,
                        e,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                raise RuntimeError(f"无法连接 Gemini：{e}") from e

        if data is None:
            assert last_transport is not None
            raise RuntimeError(f"无法连接 Gemini：{last_transport}") from last_transport

        return LlmResponse(text=_response_text(data))
