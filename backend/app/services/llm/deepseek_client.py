from __future__ import annotations

import httpx

from app.core.config import settings
from app.services.llm.base import LlmClient, LlmResponse


class DeepSeekClient(LlmClient):
    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
    ) -> None:
        self.api_key = settings.deepseek_api_key if api_key is None else api_key
        b = settings.deepseek_base_url if base_url is None else base_url
        self.base_url = b.rstrip("/")

    async def chat_text(self, *, messages: list[dict], model: str) -> LlmResponse:
        if not self.api_key:
            raise RuntimeError(
                "DEEPSEEK_API_KEY 未配置：请在管理后台「LLM 配置」填写，或在 .env 设置 DEEPSEEK_API_KEY"
            )

        url = f"{self.base_url}/chat/completions"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        payload = {"model": model, "messages": messages}
        async with httpx.AsyncClient(timeout=60) as client:
            r = await client.post(url, headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
        content = data["choices"][0]["message"]["content"]
        return LlmResponse(text=content or "")

