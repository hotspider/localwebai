from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def _capabilities_path() -> Path:
    return Path(__file__).resolve().parents[3] / "config" / "model_capabilities.json"


def load_model_capabilities() -> dict[str, Any]:
    p = _capabilities_path()
    if not p.is_file():
        return {"models": {}}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        logger.exception("model_capabilities.json load failed")
        return {"models": {}}


def vision_warnings(*, model: str, has_image: bool) -> list[str]:
    if not has_image:
        return []
    caps = load_model_capabilities().get("models") or {}
    m = caps.get(model) or caps.get(model.replace(" ", ""))
    if not m:
        return []
    if not m.get("supports_vision", False):
        return [
            "当前所选模型不支持图片分析；若要数图、识图或读图内文字，请在客户端切换到 ChatGPT 或 Gemini。"
        ]
    return []
