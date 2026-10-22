"""Lightweight in-process monitoring counters for fallback/degraded paths."""

from __future__ import annotations

from collections import Counter
from datetime import UTC, datetime
from threading import Lock
from typing import Any

_lock = Lock()
_sse_degraded_total = 0
_msgpack_json_fallback_total = 0
_sse_degraded_by_channel: Counter[str] = Counter()
_msgpack_fallback_by_route: Counter[str] = Counter()
_last_sse_degraded_at: datetime | None = None
_last_msgpack_fallback_at: datetime | None = None


def record_degraded_sse(*, channel: str) -> None:
    global _sse_degraded_total, _last_sse_degraded_at
    with _lock:
        _sse_degraded_total += 1
        _sse_degraded_by_channel[channel] += 1
        _last_sse_degraded_at = datetime.now(UTC)


def record_msgpack_json_fallback(*, route_key: str) -> None:
    global _msgpack_json_fallback_total, _last_msgpack_fallback_at
    with _lock:
        _msgpack_json_fallback_total += 1
        _msgpack_fallback_by_route[route_key] += 1
        _last_msgpack_fallback_at = datetime.now(UTC)


def fallback_monitoring_snapshot() -> dict[str, Any]:
    with _lock:
        return {
            "generated_at": datetime.now(UTC).isoformat(),
            "sse_degraded_total": _sse_degraded_total,
            "msgpack_json_fallback_total": _msgpack_json_fallback_total,
            "sse_degraded_by_channel": dict(_sse_degraded_by_channel),
            "msgpack_fallback_by_route": dict(_msgpack_fallback_by_route),
            "last_sse_degraded_at": (
                _last_sse_degraded_at.isoformat()
                if _last_sse_degraded_at is not None
                else None
            ),
            "last_msgpack_fallback_at": (
                _last_msgpack_fallback_at.isoformat()
                if _last_msgpack_fallback_at is not None
                else None
            ),
        }
