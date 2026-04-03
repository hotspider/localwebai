from __future__ import annotations

from app.services.intelligence.task_types import TaskType


def should_trigger_search(
    task_type: TaskType,
    user_message: str,
    user_search_enabled: bool,
) -> bool:
    """
    与需求文档 §6.2 对齐：SEARCH_REQUIRED 强制；用户开搜索时排除创意/部分代码；
    关键词在未手动开启时也可触发。
    """
    if task_type == TaskType.SEARCH_REQUIRED:
        return True
    t = user_message or ""
    low = t.lower()
    if user_search_enabled:
        if task_type in (TaskType.CREATIVE_WRITE, TaskType.CODE_GENERATE, TaskType.CODE_DEBUG):
            return False
        return True
    trigger_keywords = [
        "最新",
        "今天",
        "现在",
        "今年",
        "最近",
        "当前",
        "latest",
        "current",
        "today",
        "now",
        "recent",
        "价格",
        "股价",
        "汇率",
        "天气",
        "新闻",
    ]
    return any(kw in t for kw in trigger_keywords) or any(kw in low for kw in ("latest", "current", "today", "news"))
