from __future__ import annotations

from app.core.config import settings


def web_search(query: str) -> list[dict]:
    if not settings.web_search_enabled:
        return []
    # 第一版：用 duckduckgo_search，避免需要 API key
    try:
        from duckduckgo_search import DDGS

        results: list[dict] = []
        with DDGS(timeout=settings.web_search_timeout_seconds) as ddgs:
            for r in ddgs.text(query, max_results=settings.web_search_max_results):
                if not r:
                    continue
                url = r.get("href") or r.get("url")
                if not url:
                    continue
                results.append(
                    {
                        "title": r.get("title") or "",
                        "url": url,
                        "snippet": r.get("body") or r.get("snippet") or "",
                        "provider": "duckduckgo",
                    }
                )
        return results
    except Exception:
        return []

