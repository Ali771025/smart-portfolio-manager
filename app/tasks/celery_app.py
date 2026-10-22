"""Celery application factory for market and background workers.

Configuration:
  - Beat schedule defines periodic task execution
  - Timezone set to Asia/Tehran for market-aligned scheduling
  - Task acknowledgment set to late for at-least-once delivery
  - Worker prefetch limited to 1 for fair task distribution
"""

from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings


def _parse_cron(expr: str) -> crontab:
    """Parse cron expression string into crontab object."""
    minute, hour, day_of_month, month_of_year, day_of_week = expr.split()
    return crontab(
        minute=minute,
        hour=hour,
        day_of_month=day_of_month,
        month_of_year=month_of_year,
        day_of_week=day_of_week,
    )


celery_app = Celery(
    "smart_portfolio",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    timezone=settings.CELERY_TIMEZONE,
    enable_utc=False,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_track_started=True,
    task_soft_time_limit=settings.CELERY_TASK_SOFT_TIME_LIMIT_SECONDS,
    beat_schedule={
        # Market sync tasks
        "sync-live-market-prices": {
            "task": "app.tasks.market_tasks.sync_tsetmc_live_prices",
            "schedule": _parse_cron(settings.CELERY_MARKET_SYNC_CRON),
        },
        "crawl-tsetmc-market-watch": {
            "task": "app.tasks.market_tasks.crawl_tsetmc_market_watch",
            "schedule": _parse_cron(settings.CELERY_MARKET_SYNC_CRON),
        },
        "crawl-codal-disclosures": {
            "task": "app.tasks.market_tasks.crawl_codal_disclosures",
            "schedule": _parse_cron(settings.CELERY_CODAL_SYNC_CRON),
        },
        "sync-fipiran-funds": {
            "task": "app.tasks.market_tasks.sync_fipiran_funds",
            "schedule": _parse_cron(settings.FIPIRAN_SYNC_CRON),
        },
        "sync-daily-benchmarks": {
            "task": "app.tasks.market_tasks.sync_daily_benchmarks",
            "schedule": _parse_cron(settings.CELERY_BENCHMARK_SYNC_CRON),
        },
        "check-provider-health": {
            "task": "app.tasks.market_tasks.check_provider_health",
            "schedule": crontab(minute="*/5"),
        },
        # Alert evaluation tasks
        "evaluate-alerts": {
            "task": "app.tasks.alert_tasks.evaluate_alerts",
            "schedule": crontab(minute="*/5"),  # Every 5 minutes
        },
        "cleanup-expired-alerts": {
            "task": "app.tasks.alert_tasks.cleanup_expired_alerts",
            "schedule": crontab(minute=0, hour=0),  # Daily at midnight
        },
    },
)

celery_app.autodiscover_tasks(["app.tasks"])
