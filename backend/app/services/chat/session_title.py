from __future__ import annotations

import re


def derive_conversation_title(user_text: str, max_len: int = 48) -> str:
    """
    与常见对话产品一致：用首条用户消息截取为标题（去换行、空白，超长省略号）。
    """
    raw = (user_text or "").strip()
    if not raw:
        return "新对话"
    # 首行优先，多行合并为单空格
    one_line = re.sub(r"\s+", " ", raw.replace("\r\n", "\n").split("\n", 1)[0].strip())
    if not one_line:
        one_line = re.sub(r"\s+", " ", raw)[:max_len]
    if len(one_line) <= max_len:
        return one_line
    return one_line[: max_len - 1].rstrip() + "…"
