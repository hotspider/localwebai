from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Any, Literal

import httpx

from app.services.realtime.source_formatter import format_brave_sources_for_llm

logger = logging.getLogger(__name__)

BraveStatus = Literal["ok", "config_missing", "provider_error", "no_reliable_result"]


@dataclass
class BraveFetchOutcome:
    status: BraveStatus
    message: str
    sources: list[dict]
    context_block: str
    queried_at_iso: str


def _parse_web_results(data: dict[str, Any]) -> list[dict]:
    out: list[dict] = []
    web = data.get("web") or {}
    results = web.get("results") if isinstance(web, dict) else None
    if not isinstance(results, list):
        return out
    for r in results:
        if not isinstance(r, dict):
            continue
        url = (r.get("url") or "").strip()
        if not url:
            continue
        out.append(
            {
                "title": str(r.get("title") or "")[:500],
                "url": url,
                "snippet": str(r.get("description") or r.get("snippet") or "")[:2000],
                "type": "web",
                "provider": "brave",
            }
        )
    return out


def _parse_news_results(data: dict[str, Any]) -> list[dict]:
    out: list[dict] = []
    results = data.get("results")
    if not isinstance(results, list):
        news = data.get("news")
        if isinstance(news, dict):
            results = news.get("results")
    if not isinstance(results, list):
        return out
    for r in results:
        if not isinstance(r, dict):
            continue
        url = (r.get("url") or "").strip()
        if not url:
            continue
        out.append(
            {
                "title": str(r.get("title") or "")[:500],
                "url": url,
                "snippet": str(r.get("description") or r.get("snippet") or "")[:2000],
                "type": "news",
                "provider": "brave",
            }
        )
    return out


def _parse_llm_context(data: dict[str, Any]) -> tuple[list[dict], str]:
    """返回 (来源条目, 给模型的上下文字符串)。"""
    sources: list[dict] = []
    parts: list[str] = []
    grounding = data.get("grounding") or {}
    if not isinstance(grounding, dict):
        return sources, ""
    generic = grounding.get("generic")
    if not isinstance(generic, list):
        generic = []
    for item in generic:
        if not isinstance(item, dict):
            continue
        url = (item.get("url") or "").strip()
        title = str(item.get("title") or "")[:500]
        snippets = item.get("snippets")
        if not isinstance(snippets, list):
            snippets = []
        text = "\n".join(str(s) for s in snippets if s)[:12000]
        if url:
            sources.append(
                {
                    "title": title,
                    "url": url,
                    "snippet": text[:2000],
                    "type": "llm_context",
                    "provider": "brave",
                }
            )
        if text:
            parts.append(f"## {title}\n{url}\n{text}")
    poi = grounding.get("poi")
    if isinstance(poi, dict):
        url = (poi.get("url") or "").strip()
        title = str(poi.get("name") or poi.get("title") or "POI")[:500]
        sn = poi.get("snippets")
        if isinstance(sn, list):
            t = "\n".join(str(s) for s in sn if s)[:4000]
            if t:
                parts.append(f"## {title}\n{url}\n{t}")
            if url:
                sources.append(
                    {
                        "title": title,
                        "url": url,
                        "snippet": t[:2000],
                        "type": "llm_context",
                        "provider": "brave",
                    }
                )
    for m in grounding.get("map") or []:
        if not isinstance(m, dict):
            continue
        url = (m.get("url") or "").strip()
        title = str(m.get("name") or m.get("title") or "")[:500]
        sn = m.get("snippets")
        if isinstance(sn, list):
            t = "\n".join(str(s) for s in sn if s)[:4000]
            if t:
                parts.append(f"## {title}\n{url}\n{t}")
            if url:
                sources.append(
                    {
                        "title": title,
                        "url": url,
                        "snippet": t[:2000],
                        "type": "llm_context",
                        "provider": "brave",
                    }
                )
    return sources, "\n\n".join(parts)


def _dedupe_sources(items: list[dict]) -> list[dict]:
    seen: set[str] = set()
    out: list[dict] = []
    for s in items:
        u = (s.get("url") or "").strip()
        if not u:
            continue
        if u in seen:
            continue
        seen.add(u)
        out.append(s)
    return out


_brave_cache: dict[str, tuple[float, BraveFetchOutcome]] = {}
_CACHE_TTL = 120.0


def brave_cache_key(
    query: str,
    web_on: bool,
    news_on: bool,
    llm_on: bool,
    country: str,
    lang: str,
    count: int,
) -> str:
    return f"{query}|{web_on}|{news_on}|{llm_on}|{country}|{lang}|{count}"


def brave_cache_get(key: str) -> BraveFetchOutcome | None:
    now = time.time()
    hit = _brave_cache.get(key)
    if not hit:
        return None
    ts, val = hit
    if now - ts > _CACHE_TTL:
        del _brave_cache[key]
        return None
    return val


def brave_cache_set(key: str, val: BraveFetchOutcome) -> None:
    _brave_cache[key] = (time.time(), val)


async def fetch_brave(
    *,
    api_key: str,
    base_url: str,
    query: str,
    web_on: bool,
    news_on: bool,
    llm_context_on: bool,
    count: int,
    timeout_sec: float,
    country: str,
    search_lang: str,
    use_cache: bool,
) -> BraveFetchOutcome:
    from datetime import datetime, timezone

    queried_at = datetime.now(timezone.utc).isoformat()
    ck = brave_cache_key(query, web_on, news_on, llm_context_on, country, search_lang, count)
    if use_cache:
        cached = brave_cache_get(ck)
        if cached:
            return cached

    if not api_key.strip():
        return BraveFetchOutcome("config_missing", "Brave API Key 未在后台配置或为空。", [], "", queried_at)

    root = base_url.rstrip("/")
    headers = {
        "X-Subscription-Token": api_key.strip(),
        "Accept": "application/json",
    }
    timeout = httpx.Timeout(timeout_sec, connect=min(10.0, timeout_sec))
    merged: list[dict] = []
    llm_text_block = ""

    try:
        async with httpx.AsyncClient(timeout=timeout, headers=headers) as client:
            n = max(1, min(count, 20))
            ccode = (country or "cn").strip().lower()
            if len(ccode) < 2:
                ccode = "cn"
            else:
                ccode = ccode[:2]
            params_base = {
                "q": query,
                "count": n,
                "country": ccode,
                "search_lang": search_lang or "zh-hans",
            }

            if web_on:
                r = await client.get(f"{root}/res/v1/web/search", params=params_base)
                r.raise_for_status()
                merged.extend(_parse_web_results(r.json()))

            if news_on:
                r2 = await client.get(f"{root}/res/v1/news/search", params=params_base)
                r2.raise_for_status()
                merged.extend(_parse_news_results(r2.json()))

            if llm_context_on:
                llm_params = {
                    "q": query,
                    "country": params_base["country"],
                    "search_lang": params_base["search_lang"],
                    "count": n,
                    "maximum_number_of_tokens": min(8192, 2048 + n * 256),
                    "context_threshold_mode": "balanced",
                }
                r3 = await client.get(f"{root}/res/v1/llm/context", params=llm_params)
                r3.raise_for_status()
                llm_sources, llm_text_block = _parse_llm_context(r3.json())
                merged.extend(llm_sources)

    except httpx.HTTPStatusError as e:
        body = (e.response.text or "")[:600]
        logger.warning("Brave HTTP error: %s %s", e.response.status_code, body)
        out = BraveFetchOutcome(
            "provider_error",
            f"Brave 接口错误 HTTP {e.response.status_code}：{body or e.response.reason_phrase}",
            [],
            "",
            queried_at,
        )
        return out
    except Exception as e:
        logger.exception("Brave request failed")
        return BraveFetchOutcome("provider_error", f"Brave 请求失败：{e}", [], "", queried_at)

    merged = _dedupe_sources(merged)

    if llm_text_block:
        context = (
            "以下为 Brave LLM Context 抽取的正文（优先参考），并辅以网页/新闻摘要条目。\n"
            "你必须只依据这些内容推断事实；不得编造；结构：先结论，再关键事实，再列出来源。\n"
            "---\n"
            + llm_text_block
        )
        if merged:
            context += "\n---\n" + format_brave_sources_for_llm(merged)
    else:
        context = format_brave_sources_for_llm(merged)

    if not merged and not llm_text_block.strip():
        out = BraveFetchOutcome(
            "no_reliable_result",
            "Brave 未返回可用的网页、新闻或上下文内容，请尝试缩短/改写问题后重试。",
            [],
            "",
            queried_at,
        )
        return out

    out = BraveFetchOutcome("ok", "", merged, context, queried_at)
    if use_cache:
        brave_cache_set(ck, out)
    return out
