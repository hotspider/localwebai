from __future__ import annotations

from enum import Enum


class TaskType(str, Enum):
    QA_FACTUAL = "QA_FACTUAL"
    QA_REASONING = "QA_REASONING"
    CODE_GENERATE = "CODE_GENERATE"
    CODE_DEBUG = "CODE_DEBUG"
    CODE_EXPLAIN = "CODE_EXPLAIN"
    TEXT_SUMMARIZE = "TEXT_SUMMARIZE"
    TEXT_TRANSLATE = "TEXT_TRANSLATE"
    TEXT_REWRITE = "TEXT_REWRITE"
    CREATIVE_WRITE = "CREATIVE_WRITE"
    IMAGE_ANALYZE = "IMAGE_ANALYZE"
    IMAGE_OCR = "IMAGE_OCR"
    DATA_ANALYZE = "DATA_ANALYZE"
    DOC_QA = "DOC_QA"
    SEARCH_REQUIRED = "SEARCH_REQUIRED"
    CONVERSATION = "CONVERSATION"
    TASK_PLANNING = "TASK_PLANNING"
    UNKNOWN = "UNKNOWN"

    @classmethod
    def from_raw(cls, raw: str) -> TaskType:
        t = (raw or "").strip().upper()
        for m in cls:
            if m.value == t:
                return m
        return cls.UNKNOWN
