from __future__ import annotations

from app.services.intelligence.prompt_store import prompt_store
from app.services.intelligence.task_types import TaskType


def build_system_prompt(
    task_type: TaskType,
    *,
    session_summary: str | None = None,
    search_injection: str | None = None,
    attachment_summaries: list[str] | None = None,
    user_preferences_note: str | None = None,
) -> str:
    """按任务类型组装系统提示（模板来自 JSON，不含用户原文防注入）。"""
    data = prompt_store.data()
    base = (data.get("base_app") or "").strip()
    tasks: dict[str, str] = data.get("tasks") or {}
    task_body = (tasks.get(task_type.value) or tasks.get(TaskType.UNKNOWN.value) or "").strip()
    parts: list[str] = []
    if base:
        parts.append(base)
    if task_body:
        if parts:
            parts.extend(["", "---", "", task_body])
        else:
            parts.append(task_body)

    if session_summary and session_summary.strip():
        parts.extend(["", f"当前会话背景：{session_summary.strip()}"])
    if search_injection and search_injection.strip():
        parts.extend(["", "以下是最新检索材料，请参考（须注明来源）：", search_injection.strip()])
    if attachment_summaries:
        lines = ["用户上传了以下文件摘要，请结合回答："]
        for s in attachment_summaries:
            if s.strip():
                lines.append(s.strip())
        parts.extend(["", "\n".join(lines)])
    if user_preferences_note and user_preferences_note.strip():
        parts.extend(["", f"用户偏好：{user_preferences_note.strip()}"])

    return "\n".join(parts).strip() or "你是一名有帮助的助手。"
