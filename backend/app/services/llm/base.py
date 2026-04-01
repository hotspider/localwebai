from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class LlmResponse:
    text: str


class LlmClient:
    async def chat_text(self, *, messages: list[dict], model: str) -> LlmResponse:
        raise NotImplementedError

