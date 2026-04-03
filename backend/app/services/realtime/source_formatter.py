from __future__ import annotations


def format_brave_sources_for_llm(sources: list[dict]) -> str:
    """将 Brave 结果整理为给模型的 system 上下文（中文指令）。"""
    if not sources:
        return ""
    lines: list[str] = [
        "以下为 Brave 实时检索结果，仅供整理回答使用；不得编造未出现的事实。",
        "回答要求：先给结论，再列关键事实，最后列出来源标题与链接；不确定须明确说明。",
        "---",
    ]
    for i, s in enumerate(sources, 1):
        title = (s.get("title") or "").strip()
        url = (s.get("url") or "").strip()
        snippet = (s.get("snippet") or "").strip()
        typ = (s.get("type") or "web").strip()
        lines.append(f"[{i}] ({typ}) {title}\nURL: {url}\n摘要: {snippet}\n")
    return "\n".join(lines)


def format_sources_for_response(sources: list[dict]) -> list[dict]:
    """API 返回给前端的来源列表（统一字段）。"""
    out: list[dict] = []
    for s in sources:
        url = (s.get("url") or "").strip()
        if not url:
            continue
        out.append(
            {
                "title": (s.get("title") or "")[:500],
                "url": url,
                "snippet": (s.get("snippet") or "")[:2000],
                "provider": "brave",
                "type": (s.get("type") or "web"),
            }
        )
    return out
