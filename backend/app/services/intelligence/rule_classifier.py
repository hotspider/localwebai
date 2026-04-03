from __future__ import annotations

import re

from app.services.intelligence.task_types import TaskType


def classify_by_rules(
    *,
    text: str,
    has_image_attachment: bool,
    attachment_extracted_text: str,
) -> tuple[TaskType | None, str]:
    """
    规则层：<5ms 量级。返回 (任务类型, 规则原因)；无法判定则 (None, "")。
    """
    t = (text or "").strip()
    low = t.lower()
    att = (attachment_extracted_text or "").strip()

    if has_image_attachment:
        ocr_kw = (
            "ocr",
            "提取文字",
            "识别字",
            "把字打出来",
            "转成文字",
            "抄下来",
            "extract text",
        )
        if any(k in t or k in low for k in ocr_kw):
            return TaskType.IMAGE_OCR, "rule:image_ocr_kw"
        return TaskType.IMAGE_ANALYZE, "rule:image_default"

    combined = f"{t}\n{att}"

    if "```" in t or re.search(r"(?m)^\s*(def|class)\s+\w+", t):
        if any(x in t for x in ("调试", "报错", "异常", "traceback", "error", "bug", "失败")):
            return TaskType.CODE_DEBUG, "rule:code_debug"
        if any(x in t for x in ("解释", "讲解", "什么意思", "逐行", "注释")):
            return TaskType.CODE_EXPLAIN, "rule:code_explain"
        return TaskType.CODE_GENERATE, "rule:code_generate"

    if any(x in t for x in ("报错", "traceback", "异常栈", "崩溃", "stack trace")) and (
        "file" in low or ".py" in t or ".js" in t or ".ts" in t
    ):
        return TaskType.CODE_DEBUG, "rule:code_debug_path"

    if "翻译成" in t or "翻译为" in t or re.search(r"\btranslate\b", low):
        return TaskType.TEXT_TRANSLATE, "rule:translate"

    if any(x in t for x in ("摘要", "总结", "概括", "summarize", "tl;dr")):
        return TaskType.TEXT_SUMMARIZE, "rule:summarize"

    if any(x in t for x in ("润色", "改写", "重写", "优化表达")):
        return TaskType.TEXT_REWRITE, "rule:rewrite"

    if any(x in t for x in ("写一个故事", "小说", "诗歌", "童话", "创意文案")):
        return TaskType.CREATIVE_WRITE, "rule:creative"

    if re.search(r"[,，;\t]", att) and re.search(r"\d", att) and len(att) > 80:
        if any(x in t for x in ("分析", "统计", "趋势", "图表", "数据")):
            return TaskType.DATA_ANALYZE, "rule:data_attachment"

    if re.search(r"\b(csv|tsv)\b", low) or re.search(r"\d+\s*,\s*\d+", t):
        if any(x in t for x in ("分析", "统计", "数据")):
            return TaskType.DATA_ANALYZE, "rule:data_csv_kw"

    if att and any(x in t for x in ("根据文档", "附件里", "上文文件", "pdf", "材料里")):
        return TaskType.DOC_QA, "rule:doc_qa"

    search_kw = (
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
    )
    if any(k in t for k in search_kw) or any(k in low for k in ("latest", "breaking news", "stock price")):
        return TaskType.SEARCH_REQUIRED, "rule:search_keyword"

    if any(x in t for x in ("计划", "拆解", "步骤", "路线图", "排期")):
        return TaskType.TASK_PLANNING, "rule:planning"

    if any(x in t for x in ("证明", "推导", "计算", "逻辑题", "概率", "方程")):
        return TaskType.QA_REASONING, "rule:reasoning"

    if t in ("你好", "您好", "嗨", "在吗", "谢谢", "多谢", "早上好", "晚上好"):
        return TaskType.CONVERSATION, "rule:greeting"

    return None, ""
