from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.secret_crypto import decrypt_secret, encrypt_secret, is_likely_fernet_ciphertext
from app.models.runtime_setting import RuntimeSetting

# 与后台表单、DB 行键一致
KEY_OPENAI_API_KEY = "openai_api_key"
KEY_OPENAI_BASE_URL = "openai_base_url"
KEY_OPENAI_PROXY = "openai_proxy"
KEY_DEEPSEEK_API_KEY = "deepseek_api_key"
KEY_DEEPSEEK_BASE_URL = "deepseek_base_url"
KEY_DEEPSEEK_PROXY = "deepseek_proxy"
KEY_DEEPSEEK_MODEL_TEXT = "deepseek_model_text"
KEY_GEMINI_API_KEY = "gemini_api_key"
KEY_GEMINI_BASE_URL = "gemini_base_url"
KEY_GEMINI_PROXY = "gemini_proxy"
KEY_DEFAULT_NEW_USER_CAN_WEB_SEARCH = "default_new_user_can_web_search"  # "1" | "0"


def _db_str(db: Session, key: str) -> str | None:
    row = db.get(RuntimeSetting, key)
    if row is None or row.value is None:
        return None
    s = row.value.strip()
    return s if s else None


def _effective(db: Session, key: str, env_fallback: str) -> str:
    v = _db_str(db, key)
    return v if v is not None else env_fallback


def _effective_api_key(db: Session, key: str, env_fallback: str) -> str:
    """后台保存的 API Key：优先 Fernet 解密；兼容迁移前明文。"""
    raw = _db_str(db, key)
    if raw is None:
        return env_fallback
    dec = (decrypt_secret(raw) or "").strip()
    if dec:
        return dec
    if is_likely_fernet_ciphertext(raw):
        return ""
    return raw.strip()


def mask_runtime_api_key_for_admin(db: Session, key: str) -> str:
    row = db.get(RuntimeSetting, key)
    if row is None or not (row.value or "").strip():
        return "（未在后台保存）"
    raw = row.value.strip()
    dec = (decrypt_secret(raw) or "").strip()
    if dec:
        return _mask_key_tail(dec)
    if is_likely_fernet_ciphertext(raw):
        return "（密文已保存但无法解密：请核对服务器 .env 中 FIELD_ENCRYPTION_FERNET_KEY）"
    return _mask_key_tail(raw)


def _mask_key_tail(s: str) -> str:
    if len(s) <= 4:
        return "****"
    return f"****{s[-4:]}"


@dataclass(frozen=True)
class OpenAiRuntimeConfig:
    api_key: str
    base_url: str
    proxy: str


@dataclass(frozen=True)
class DeepseekRuntimeConfig:
    api_key: str
    base_url: str
    proxy: str
    model: str


@dataclass(frozen=True)
class GeminiRuntimeConfig:
    api_key: str
    base_url: str
    proxy: str


def effective_openai_config(db: Session) -> OpenAiRuntimeConfig:
    return OpenAiRuntimeConfig(
        api_key=_effective_api_key(db, KEY_OPENAI_API_KEY, settings.openai_api_key),
        base_url=_effective(db, KEY_OPENAI_BASE_URL, settings.openai_base_url),
        proxy=_effective(db, KEY_OPENAI_PROXY, settings.openai_proxy),
    )


def effective_deepseek_config(db: Session) -> DeepseekRuntimeConfig:
    return DeepseekRuntimeConfig(
        api_key=_effective_api_key(db, KEY_DEEPSEEK_API_KEY, settings.deepseek_api_key),
        base_url=_effective(db, KEY_DEEPSEEK_BASE_URL, settings.deepseek_base_url),
        proxy=_effective(db, KEY_DEEPSEEK_PROXY, settings.deepseek_proxy),
        model=_effective(db, KEY_DEEPSEEK_MODEL_TEXT, settings.deepseek_model_text),
    )


def effective_gemini_config(db: Session) -> GeminiRuntimeConfig:
    return GeminiRuntimeConfig(
        api_key=_effective_api_key(db, KEY_GEMINI_API_KEY, settings.gemini_api_key),
        base_url=_effective(db, KEY_GEMINI_BASE_URL, settings.gemini_base_url),
        proxy=_effective(db, KEY_GEMINI_PROXY, settings.gemini_proxy),
    )


def has_db_openai_key(db: Session) -> bool:
    return _db_str(db, KEY_OPENAI_API_KEY) is not None


def has_db_deepseek_key(db: Session) -> bool:
    return _db_str(db, KEY_DEEPSEEK_API_KEY) is not None


def has_db_gemini_key(db: Session) -> bool:
    return _db_str(db, KEY_GEMINI_API_KEY) is not None


def upsert_encrypted_secret(db: Session, key: str, plain: str) -> None:
    """将明文加密后写入 runtime_settings（需已配置 FIELD_ENCRYPTION_FERNET_KEY）。"""
    upsert_setting(db, key, encrypt_secret(plain))


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


def default_new_user_can_web_search(db: Session) -> bool:
    row = db.get(RuntimeSetting, KEY_DEFAULT_NEW_USER_CAN_WEB_SEARCH)
    return row is not None and (row.value or "").strip() == "1"


def upsert_default_new_user_can_web_search(db: Session, enabled: bool) -> None:
    upsert_setting(db, KEY_DEFAULT_NEW_USER_CAN_WEB_SEARCH, "1" if enabled else "0")
