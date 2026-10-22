"""Celery tasks for watchlist alert evaluation.

Provides background processing for:
  - Periodic alert rule evaluation
  - User-specific alert evaluation
  - Alert cleanup (expired rules)

Design:
  - Runs every 5 minutes during market hours
  - Evaluates all active alert rules
  - Creates alert events for triggered rules
  - Respects frequency constraints (once, daily, always)
  - Structured logging for observability
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from celery import Task

from app.core.database import async_session_factory
from app.services.alert_service import AlertEvaluationService
from app.tasks.celery_app import celery_app

logger = logging.getLogger("celery.alerts")


class ResilientAlertTask(Task):
    """Base task for alert evaluation with resilience features."""

    autoretry_for = (ConnectionError, TimeoutError, Exception)
    retry_backoff = True
    retry_backoff_max = 30
    retry_jitter = True
    retry_kwargs = {"max_retries": 3}

    def on_failure(self, exc: Exception, task_id: str, args: tuple, kwargs: dict, einfo: Any) -> None:
        logger.error("alert_task.failed task=%s task_id=%s error=%s", self.name, task_id, exc)

    def on_success(self, retval: Any, task_id: str, args: tuple, kwargs: dict) -> None:
        logger.info("alert_task.success task=%s task_id=%s", self.name, task_id)


# ═══════════════════════════════════════════════════════════════
# Alert Evaluation Task
# ═══════════════════════════════════════════════════════════════

async def _run_alert_evaluation() -> dict[str, Any]:
    """Run alert evaluation for all active rules."""
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("alert.evaluation.start time=%s", started_at.isoformat())

    try:
        async with async_session_factory() as db:
            service = AlertEvaluationService(db)
            triggered_events = await service.evaluate_all_active_alerts()
            await db.commit()

        duration_ms = (time.monotonic() - start_time) * 1000

        logger.info(
            "alert.evaluation.complete duration=%.1fms triggered=%d",
            duration_ms,
            len(triggered_events),
        )

        return {
            "status": "success",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "triggered_count": len(triggered_events),
            "events": triggered_events[:10],  # Return first 10 for logging
        }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "alert.evaluation.failed duration=%.1fms error=%s",
            duration_ms,
            exc,
        )
        return {
            "status": "error",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


@celery_app.task(
    base=ResilientAlertTask,
    bind=True,
    name="app.tasks.alert_tasks.evaluate_alerts",
    max_retries=3,
    soft_time_limit=30,
    time_limit=45,
)
def evaluate_alerts(self: ResilientAlertTask) -> dict[str, Any]:
    """Evaluate all active alert rules.

    This task:
      1. Fetches all active alert rules
      2. Evaluates each rule against current market data
      3. Creates alert events for triggered rules
      4. Respects frequency constraints

    Schedule: Every 5 minutes (*/5 * * * *)
    """
    return asyncio.run(_run_alert_evaluation())


# ═══════════════════════════════════════════════════════════════
# User-Specific Alert Evaluation
# ═══════════════════════════════════════════════════════════════

async def _run_user_alert_evaluation(user_id: str) -> dict[str, Any]:
    """Run alert evaluation for a specific user."""
    from uuid import UUID

    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("alert.user_evaluation.start user=%s", user_id)

    try:
        async with async_session_factory() as db:
            service = AlertEvaluationService(db)
            triggered_events = await service.evaluate_user_alerts(user_id=UUID(user_id))
            await db.commit()

        duration_ms = (time.monotonic() - start_time) * 1000

        logger.info(
            "alert.user_evaluation.complete user=%s duration=%.1fms triggered=%d",
            user_id,
            duration_ms,
            len(triggered_events),
        )

        return {
            "status": "success",
            "user_id": user_id,
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "triggered_count": len(triggered_events),
        }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "alert.user_evaluation.failed user=%s duration=%.1fms error=%s",
            user_id,
            duration_ms,
            exc,
        )
        return {
            "status": "error",
            "user_id": user_id,
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


@celery_app.task(
    base=ResilientAlertTask,
    bind=True,
    name="app.tasks.alert_tasks.evaluate_user_alerts",
    max_retries=2,
    soft_time_limit=30,
    time_limit=45,
)
def evaluate_user_alerts(self: ResilientAlertTask, user_id: str) -> dict[str, Any]:
    """Evaluate alerts for a specific user.

    This task is triggered manually or by API endpoint.
    """
    return asyncio.run(_run_user_alert_evaluation(user_id))


# ═══════════════════════════════════════════════════════════════
# Alert Cleanup Task
# ═══════════════════════════════════════════════════════════════

async def _run_alert_cleanup() -> dict[str, Any]:
    """Clean up expired alert rules."""
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("alert.cleanup.start time=%s", started_at.isoformat())

    try:
        from sqlalchemy import update
        from app.models.watchlist import AlertRule

        async with async_session_factory() as db:
            # Mark expired rules
            result = await db.execute(
                update(AlertRule)
                .where(
                    AlertRule.status == "ACTIVE",
                    AlertRule.expires_at.isnot(None),
                    AlertRule.expires_at < datetime.now(UTC),
                )
                .values(status="EXPIRED")
            )
            await db.commit()

        duration_ms = (time.monotonic() - start_time) * 1000
        expired_count = result.rowcount

        logger.info(
            "alert.cleanup.complete duration=%.1fms expired=%d",
            duration_ms,
            expired_count,
        )

        return {
            "status": "success",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "expired_count": expired_count,
        }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "alert.cleanup.failed duration=%.1fms error=%s",
            duration_ms,
            exc,
        )
        return {
            "status": "error",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


@celery_app.task(
    base=ResilientAlertTask,
    bind=True,
    name="app.tasks.alert_tasks.cleanup_expired_alerts",
    max_retries=2,
    soft_time_limit=15,
    time_limit=30,
)
def cleanup_expired_alerts(self: ResilientAlertTask) -> dict[str, Any]:
    """Clean up expired alert rules.

    Runs daily at midnight to mark expired rules.
    """
    return asyncio.run(_run_alert_cleanup())
