"""Operational monitoring endpoints for fallback/degraded-path counters."""

from __future__ import annotations

from fastapi import APIRouter

from app.core.deps import CurrentSuperuser
from app.core.monitoring import fallback_monitoring_snapshot

router = APIRouter(prefix="/monitoring", tags=["Monitoring"])


@router.get("/fallbacks")
async def get_fallback_counters(
    _: CurrentSuperuser,
) -> dict[str, object]:
    return fallback_monitoring_snapshot()
