from __future__ import annotations

from itsdangerous import BadSignature, BadTimeSignature, URLSafeTimedSerializer

from app.core.config import settings


_SALT = "attachment-public-link-v1"


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(settings.jwt_secret, salt=_SALT)


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

