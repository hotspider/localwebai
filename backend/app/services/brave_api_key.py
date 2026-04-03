"""Brave API Key：库内 Fernet 密文优先解密；兼容历史 api_key_plain 明文列。"""

from __future__ import annotations

from app.core.secret_crypto import decrypt_secret
from app.models.brave_settings import BraveSettings


def get_brave_api_key(row: BraveSettings | None) -> str:
    if row is None:
        return ""
    enc = (row.api_key_encrypted or "").strip()
    plain = (getattr(row, "api_key_plain", None) or "").strip()
    if enc:
        d = (decrypt_secret(enc) or "").strip()
        if d:
            return d
    if plain:
        return plain
    return ""


def has_brave_api_key(row: BraveSettings | None) -> bool:
    return bool(get_brave_api_key(row))


def mask_brave_key_for_admin(row: BraveSettings | None) -> str:
    if row is None:
        return "（未配置）"
    k = get_brave_api_key(row)
    if k:
        return _mask_tail(k)
    if (row.api_key_encrypted or "").strip() and not (getattr(row, "api_key_plain", None) or "").strip():
        return "（密文已保存但无法解密：请核对服务器 .env 中 FIELD_ENCRYPTION_FERNET_KEY）"
    return "（未配置）"


def _mask_tail(s: str) -> str:
    if len(s) <= 4:
        return "****"
    return f"****{s[-4:]}"
