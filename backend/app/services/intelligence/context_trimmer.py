from __future__ import annotations


def estimate_tokens(text: str) -> int:
    """粗估 token（中英混合：偏保守）。"""
    if not text:
        return 0
    return max(1, len(text) // 3)


def message_text_len(msg: dict) -> int:
    c = msg.get("content")
    if isinstance(c, str):
        return len(c)
    if isinstance(c, list):
        n = 0
        for b in c:
            if isinstance(b, dict) and b.get("type") == "text":
                n += len(str(b.get("text") or ""))
            else:
                n += 500
        return n
    return len(str(c))


def trim_chat_history_messages(
    messages: list[dict],
    *,
    max_history_tokens: int,
) -> tuple[list[dict], bool]:
    """
    保留开头连续 system，对其余消息从旧到新删，直至估算 token 低于预算。
    返回 (裁剪后列表, 是否发生过裁剪)。
    """
    if not messages or max_history_tokens <= 0:
        return messages, False
    i = 0
    while i < len(messages) and messages[i].get("role") == "system":
        i += 1
    head = messages[:i]
    body = messages[i:]
    if not body:
        return messages, False
    trimmed = False
    while body:
        total = sum(estimate_tokens(message_text_len(m)) for m in body)
        if total <= max_history_tokens:
            break
        body = body[2:] if len(body) >= 2 else body[1:]
        trimmed = True
    return head + body, trimmed
