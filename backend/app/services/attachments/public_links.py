from __future__ import annotations

from itsdangerous import BadSignature, BadTimeSignature, URLSafeTimedSerializer

from app.core.config import settings


_SALT = "attachment-public-link-v1"


def _serializer() -> URLSafeTimedSerializer:
    # 公开附件链接用于“模型侧拉取图片/附件”，不依赖登录态。
    # 这里不要绑死 jwt_secret：生产环境可能会轮转 jwt_secret，但我们希望历史链接在短时间内依然可用。
    # 优先使用 FIELD_ENCRYPTION_FERNET_KEY（服务端稳定配置），未配置时再回退到 jwt_secret。
    secret = (settings.field_encryption_fernet_key or "").strip() or settings.jwt_secret
    return URLSafeTimedSerializer(secret, salt=_SALT)


def sign_attachment_id(attachment_id: str) -> str:
    return _serializer().dumps({"attachment_id": attachment_id})


def verify_attachment_token(token: str, *, max_age_seconds: int) -> str:
    try:
        data = _serializer().loads(token, max_age=max_age_seconds)
    except (BadSignature, BadTimeSignature) as e:
        raise ValueError("invalid token") from e
    aid = (data or {}).get("attachment_id")
    if not isinstance(aid, str) or not aid:
        raise ValueError("invalid token payload")
    return aid

