from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.runtime_setting import RuntimeSetting

# 与后台表单、DB 行键一致
KEY_OPENAI_API_KEY = "openai_api_key"
KEY_OPENAI_BASE_URL = "openai_base_url"
KEY_OPENAI_PROXY = "openai_proxy"
KEY_DEEPSEEK_API_KEY = "deepseek_api_key"
KEY_DEEPSEEK_BASE_URL = "deepseek_base_url"


def _db_str(db: Session, key: str) -> str | None:
    row = db.get(RuntimeSetting, key)
    if row is None or row.value is None:
        return None
    s = row.value.strip()
    return s if s else None


def _effective(db: Session, key: str, env_fallback: str) -> str:
    v = _db_str(db, key)
    return v if v is not None else env_fallback


@dataclass(frozen=True)
class OpenAiRuntimeConfig:
    api_key: str
    base_url: str
    proxy: str


@dataclass(frozen=True)
class DeepseekRuntimeConfig:
    api_key: str
    base_url: str


def effective_openai_config(db: Session) -> OpenAiRuntimeConfig:
    return OpenAiRuntimeConfig(
        api_key=_effective(db, KEY_OPENAI_API_KEY, settings.openai_api_key),
        base_url=_effective(db, KEY_OPENAI_BASE_URL, settings.openai_base_url),
        proxy=_effective(db, KEY_OPENAI_PROXY, settings.openai_proxy),
    )


def effective_deepseek_config(db: Session) -> DeepseekRuntimeConfig:
    return DeepseekRuntimeConfig(
        api_key=_effective(db, KEY_DEEPSEEK_API_KEY, settings.deepseek_api_key),
        base_url=_effective(db, KEY_DEEPSEEK_BASE_URL, settings.deepseek_base_url),
    )


def has_db_openai_key(db: Session) -> bool:
    return _db_str(db, KEY_OPENAI_API_KEY) is not None


def has_db_deepseek_key(db: Session) -> bool:
    return _db_str(db, KEY_DEEPSEEK_API_KEY) is not None


def upsert_setting(db: Session, key: str, value: str) -> None:
    row = db.get(RuntimeSetting, key)
    if row is None:
        db.add(RuntimeSetting(key=key, value=value))
    else:
        row.value = value


def delete_setting(db: Session, key: str) -> None:
    row = db.get(RuntimeSetting, key)
    if row is not None:
        db.delete(row)
