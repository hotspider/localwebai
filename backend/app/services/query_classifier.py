from __future__ import annotations

import re

# 命中即倾向走 Brave 实时检索。避免过短词（如「现在」「今天」「价格」）造成大量误触，导致未开联网时被接口拦截。
REALTIME_KEYWORDS_ZH = (
    "最新",
    "实时",
    "刚刚发布",
    "刚发布",
    "头条",
    "新闻网",
    "新闻联播",
    "天气预报",
    "气温多少",
    "降雨",
    "台风",
    "地震",
    "疫情",
    "发布会",
    "官宣",
    "政策更新",
    "新规",
    "正式实施",
    "生效了吗",
    "发布了吗",
    "上线了吗",
    "版本更新",
    "更新日志",
    "股价",
    "大盘",
    "沪指",
    "深证",
    "恒生",
    "纳指",
    "涨跌",
    "汇率",
    "美元兑",
    "人民币兑",
    "欧央行",
    "美联储利率决议",
)

REALTIME_KEYWORDS_EN = (
    "breaking news",
    "latest news",
    "news today",
    "weather forecast",
    "stock price",
    "share price",
    "exchange rate",
    "interest rate decision",
    "fed rate",
    "ecb ",
    "just released",
    "went live",
)

# 口语里「今天天气」「现在股价」等仍应触发；单独「现在怎么办」不应触发
_REALTIME_PHRASES_ZH = (
    "今天天气",
    "明天天气",
    "这周天气",
    "现在股价",
    "今天股价",
    "实时行情",
    "最新新闻",
    "最新消息",
    "今日新闻",
    "热点新闻",
    "搜新闻",
    "查新闻",
    "最新政策",
    "最新规定",
    "最新版本",
)


def classify_realtime_need(text: str) -> tuple[bool, str]:
    """
    返回 (是否需要实时检索, 原因简述)。
    """
    t = (text or "").strip()
    if not t:
        return False, ""
    low = t.lower()
    for kw in _REALTIME_PHRASES_ZH:
        if kw in t:
            return True, f"phrase:{kw}"
    for kw in REALTIME_KEYWORDS_ZH:
        if kw in t:
            return True, f"keyword:{kw}"
    for kw in REALTIME_KEYWORDS_EN:
        if kw in low:
            return True, f"keyword_en:{kw}"
    # 英文单词级「news / weather」误触多，仅在明显资讯语境下触发
    if re.search(r"\b(news|weather)\b", low) and re.search(
        r"\b(latest|breaking|today|forecast|update|current)\b", low
    ):
        return True, "regex:news_or_weather_context"
    return False, ""
