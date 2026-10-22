"""
Background task scheduler using APScheduler.
Runs the TSETMC market sync on a configurable interval.
"""

import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from app.core.config import settings
from app.services.market_sync import run_full_sync

logger = logging.getLogger("scheduler")

scheduler = AsyncIOScheduler()


def init_scheduler() -> None:
    """
    Register all background jobs.
    Called once during FastAPI lifespan startup.
    """

    scheduler.add_job(
        run_full_sync,
        trigger=IntervalTrigger(
            minutes=settings.TSETMC_SYNC_INTERVAL_MINUTES,
        ),
        id="tsetmc_market_sync",
        name="TSETMC Market Data Sync",
        replace_existing=True,
        max_instances=1,  # Prevent overlapping cycles
    )

    scheduler.start()
    logger.info(
        f"Scheduler started. TSETMC sync every "
        f"{settings.TSETMC_SYNC_INTERVAL_MINUTES} minutes."
    )


def shutdown_scheduler() -> None:
    """Graceful shutdown of background jobs."""
    scheduler.shutdown(wait=False)
    logger.info("Scheduler shut down.")
