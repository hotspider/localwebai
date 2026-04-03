from __future__ import annotations

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings


def _fernet() -> Fernet | None:
    k = (settings.field_encryption_fernet_key or "").strip()
    if not k:
        return None
    return Fernet(k.encode("utf-8"))


def encrypt_secret(plain: str) -> str:
    f = _fernet()
    if not f:
        raise ValueError("未配置 FIELD_ENCRYPTION_FERNET_KEY，无法加密敏感配置（请在 .env 设置 Fernet 密钥）")
    return f.encrypt(plain.encode("utf-8")).decode("ascii")


def is_likely_fernet_ciphertext(s: str | None) -> bool:
    """Fernet 密文经 urlsafe base64 编码后通常以 gAAAAA 开头，用于区分「库内密文」与历史明文。"""
    t = (s or "").strip()
    return len(t) > 24 and t.startswith("gAAAAA")


def decrypt_secret(token: str | None) -> str:
    if not token:
        return ""
    f = _fernet()
    if not f:
        return ""
    try:
        return f.decrypt(token.encode("ascii")).decode("utf-8")
    except InvalidToken:
        return ""


def mask_secret(plain_or_empty: str, *, stored: bool) -> str:
    if not stored:
        return "（未配置）"
    if not plain_or_empty:
        return "（已保存，无法解密：请检查 FIELD_ENCRYPTION_FERNET_KEY 是否与加密时一致）"
    if len(plain_or_empty) <= 4:
        return "****"
    return f"****{plain_or_empty[-4:]}"
