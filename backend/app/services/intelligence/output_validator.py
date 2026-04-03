from __future__ import annotations

import re


_BOILERPLATE_PATTERNS = (
    r"作为一个\s*AI\s*语言模型[^。]*。?",
    r"作为一个人工智能[^。]*。?",
    r"I am an AI language model[^.]*\.?",
)


def redact_secrets(text: str) -> tuple[str, bool]:
    t = text
    changed = False
    patterns = (
        (r"sk-[a-zA-Z0-9]{20,}", "[已屏蔽的敏感信息]"),
        (r"Bearer\s+[a-zA-Z0-9\-_]{20,}", "Bearer [已屏蔽的敏感信息]"),
        (r"api[_-]?key[\"']?\s*[:=]\s*[\"'][^\"']{8,}[\"']", "api_key=[已屏蔽的敏感信息]"),
    )
    for pat, rep in patterns:
        n = t
        t = re.sub(pat, rep, t, flags=re.I)
        if t != n:
            changed = True
    return t, changed


def strip_boilerplate(text: str) -> tuple[str, bool]:
    t = text
    changed = False
    for pat in _BOILERPLATE_PATTERNS:
        n = re.sub(pat, "", t, flags=re.I)
        if n != t:
            changed = True
            t = n
    return t.strip(), changed


def fix_unclosed_code_fence(text: str) -> tuple[str, bool]:
    if "```" not in text:
        return text, False
    count = text.count("```")
    if count % 2 == 0:
        return text, False
    return text.rstrip() + "\n```\n", True


def validate_assistant_output(text: str) -> tuple[str, list[str]]:
    """格式与安全轻量校验。返回 (修正后文本, 标记列表)。"""
    flags: list[str] = []
    t = text or ""
    t, c = redact_secrets(t)
    if c:
        flags.append("redacted_secrets")
    t, c = strip_boilerplate(t)
    if c:
        flags.append("stripped_boilerplate")
    t, c = fix_unclosed_code_fence(t)
    if c:
        flags.append("fixed_code_fence")
    if not (t or "").strip():
        flags.append("empty_after_validation")
    return t, flags


def append_source_footer(*, content: str, sources: list[dict]) -> str:
    """若使用搜索，在末尾追加参考来源列表（需求 §7.5）。"""
    if not sources:
        return content
    lines = ["", "", "参考来源："]
    for i, s in enumerate(sources[:12], 1):
        if not isinstance(s, dict):
            continue
        title = str(s.get("title") or "")[:120]
        url = str(s.get("url") or "")
        if url:
            lines.append(f"[{i}] {title} - {url}")
    if len(lines) <= 3:
        return content
    return content.rstrip() + "\n" + "\n".join(lines)
