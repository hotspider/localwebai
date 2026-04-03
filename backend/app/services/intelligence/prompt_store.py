from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def _default_config_path() -> Path:
    # .../backend/app/services/intelligence/this_file -> parents[3] = backend/
    return Path(__file__).resolve().parents[3] / "config" / "prompt_templates.json"


class PromptTemplateStore:
    """加载 prompt_templates.json；可选按 mtime 热更新。"""

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or _default_config_path()
        self._mtime: float = 0.0
        self._data: dict[str, Any] = {}

    def _load(self) -> dict[str, Any]:
        if not self.path.is_file():
            logger.error("prompt_templates.json missing: %s", self.path)
            return {"version": "0", "base_app": "", "tasks": {}}
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except Exception as e:
            logger.exception("failed to load prompt templates: %s", e)
            return {"version": "0", "base_app": "", "tasks": {}}

    def data(self) -> dict[str, Any]:
        from app.core.config import settings

        if settings.prompt_templates_hot_reload or not self._data:
            try:
                mtime = self.path.stat().st_mtime
            except OSError:
                mtime = 0.0
            if settings.prompt_templates_hot_reload or mtime != self._mtime or not self._data:
                self._data = self._load()
                self._mtime = mtime
        return self._data


prompt_store = PromptTemplateStore()
