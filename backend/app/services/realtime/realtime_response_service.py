from __future__ import annotations

import logging

from sqlalchemy.orm import Session

from app.models.brave_settings import BraveSettings
from app.services.brave_api_key import get_brave_api_key
from app.services.realtime.brave_provider import BraveFetchOutcome, fetch_brave
from app.services.realtime.source_formatter import format_sources_for_response

logger = logging.getLogger(__name__)


def get_brave_row(db: Session) -> BraveSettings | None:
    return db.get(BraveSettings, 1)


async def execute_brave_realtime(
    db: Session,
    *,
    user_query: str,
) -> BraveFetchOutcome:
    from datetime import datetime, timezone

    queried_at = datetime.now(timezone.utc).isoformat()
    row = get_brave_row(db)
    if row is None or not row.brave_enabled:
        logger.warning(
            "brave_realtime skip: row_missing=%s brave_enabled=%s (check same DB as admin / migration 0003)",
            row is None,
            getattr(row, "brave_enabled", None),
        )
        return BraveFetchOutcome(
            "config_missing",
            "Brave 实时检索未启用：请在管理后台开启 Brave 并保存 API Key。",
            [],
            "",
            queried_at,
        )

    key = get_brave_api_key(row)
    if not key.strip():
        pl = bool((getattr(row, "api_key_plain", None) or "").strip())
        enc = bool((row.api_key_encrypted or "").strip())
        logger.warning(
            "brave_realtime config_missing has_plain_legacy=%s has_enc_blob=%s",
            pl,
            enc,
        )
        msg = (
            "Brave API Key 不可用：库中密文无法解密（请核对服务器 FIELD_ENCRYPTION_FERNET_KEY 是否与保存时一致），或尚未配置 Key。请在管理后台 Brave 页重新粘贴 Key 并保存。"
            if enc and not pl
            else "Brave API Key 未配置：请在管理后台 Brave 页粘贴 Key 并保存。"
        )
        return BraveFetchOutcome(
            "config_missing",
            msg,
            [],
            "",
            queried_at,
        )

    out = await fetch_brave(
        api_key=key,
        base_url=row.base_url or "https://api.search.brave.com",
        query=user_query,
        web_on=bool(row.web_search_enabled),
        news_on=bool(row.news_search_enabled),
        llm_context_on=bool(row.llm_context_enabled),
        count=int(row.default_result_count or 8),
        timeout_sec=float(row.timeout_seconds or 15),
        country=row.country or "cn",
        search_lang=row.search_lang or "zh-hans",
        use_cache=bool(row.cache_enabled),
    )
    logger.info("brave_realtime fetch_done status=%s sources=%s", out.status, len(out.sources))
    return out


def response_sources_from_outcome(out: BraveFetchOutcome) -> list[dict]:
    return format_sources_for_response(out.sources)
