from __future__ import annotations

from dataclasses import dataclass

from app.services.query_classifier import classify_realtime_need


@dataclass(frozen=True)
class RealtimeRouteDecision:
    """是否走 Brave 实时链路（仍需结合用户联网开关与权限）。"""

    needs_realtime: bool
    classify_reason: str


def route_user_query(text: str) -> RealtimeRouteDecision:
    need, reason = classify_realtime_need(text)
    return RealtimeRouteDecision(needs_realtime=need, classify_reason=reason)
