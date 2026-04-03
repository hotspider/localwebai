from __future__ import annotations

from urllib.parse import urlparse


def _first_sentences(text: str, max_sentences: int) -> str:
    t = (text or "").strip().replace("\n", " ")
    if not t:
        return ""
    parts: list[str] = []
    buf = ""
    for ch in t:
        buf += ch
        if ch in "。！？.!?" and len(buf.strip()) > 8:
            parts.append(buf.strip())
            buf = ""
            if len(parts) >= max_sentences:
                break
    if len(parts) < max_sentences and buf.strip():
        parts.append(buf.strip())
    return " ".join(parts[:max_sentences])[:800]


def format_structured_search_block(*, queried_at: str, sources: list[dict], context_block: str) -> str:
    """
    将 Brave 结果整理为需求文档 §6.3 风格的结构化块（在原有 context_block 基础上增强可读性）。
    """
    lines: list[str] = [f"【实时搜索结果】（搜索时间：{queried_at}）", ""]
    seen_domains: set[str] = set()
    idx = 0
    for r in sources or []:
        if not isinstance(r, dict):
            continue
        url = (r.get("url") or "").strip()
        if not url:
            continue
        dom = urlparse(url).netloc or "unknown"
        if dom in seen_domains:
            continue
        seen_domains.add(dom)
        idx += 1
        title = str(r.get("title") or "")[:200]
        snip = _first_sentences(str(r.get("snippet") or ""), 3)
        lines.append(f"来源{idx}：{title}（{dom}）")
        lines.append(f"摘要：{snip}")
        lines.append("")
        if idx >= 8:
            break
    if (context_block or "").strip():
        lines.extend(["【检索上下文汇编】", context_block.strip(), ""])
    lines.append("请基于以上搜索结果回答用户问题，回答中必须注明信息来源。")
    return "\n".join(lines).strip()
