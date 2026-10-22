"""Hardened Celery tasks for market data synchronization.

Provides production-grade background tasks for:
  - Live market snapshot sync (hot prices)
  - Daily benchmark sync (Gold, USD, TEDPIX)
  - Provider health monitoring
  - Combined market bundle sync

Resilience Features:
  - Structured logging with timing for every operation
  - Graceful degradation on partial failures
  - Idempotent operations (safe for repeated execution)
  - Market session awareness (skip sync outside trading hours)
  - Sync status tracking for observability
  - Bounded retries with exponential backoff

Task Lifecycle:
  1. Check if sync is needed (market session, last sync time)
  2. Initialize provider with configured retry/timeout settings
  3. Fetch data from provider
  4. Persist to DB and Redis
  5. Record sync status and timing
  6. Log summary for observability
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from typing import Any

from celery import Task

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.redis import get_redis
from app.core import market_cache
from app.models.enums import BenchmarkType
from app.repositories.market_data import MarketDataRepository
from app.services.market_integration import MarketIntegrationService
from app.services.market_persistence import MarketPersistenceService
from app.services.market_provider import MarketProviderConfig, MarketProviderStatus
from app.services.market_watch_crawler import MarketWatchCrawler
from app.services.codal_crawler import CodalCrawler
from app.services.codal_provider import HttpCodalProvider
from app.services.fipiran_provider import build_fipiran_provider
from app.services.fund_sync import FundSyncService
from app.tasks.celery_app import celery_app

logger = logging.getLogger("celery.market")

# ═══════════════════════════════════════════════════════════════
# Market Session Configuration (Asia/Tehran)
# ═══════════════════════════════════════════════════════════════

# Tehran Stock Exchange trading hours (UTC+3:30)
MARKET_OPEN_HOUR = 7  # 07:30 Tehran = 04:00 UTC
MARKET_OPEN_MINUTE = 30
MARKET_CLOSE_HOUR = 12  # 12:30 Tehran = 09:00 UTC
MARKET_CLOSE_MINUTE = 30

# Allow sync to continue for 30 minutes after market close
# to capture final settlement prices
MARKET_CLOSE_BUFFER_MINUTES = 30


def _is_market_session() -> bool:
    """Check if current time is within market session (with buffer).

    Tehran Stock Exchange hours: 07:30 - 12:30 (UTC+3:30)
    We allow sync until 13:00 to capture settlement prices.

    Returns:
        True if within market session or buffer period.
    """
    now = datetime.now(UTC)
    # Convert to Tehran time (UTC+3:30)
    tehran_now = now + timedelta(hours=3, minutes=30)

    market_open = tehran_now.replace(
        hour=MARKET_OPEN_HOUR,
        minute=MARKET_OPEN_MINUTE,
        second=0,
        microsecond=0,
    )
    market_close = tehran_now.replace(
        hour=MARKET_CLOSE_HOUR,
        minute=MARKET_CLOSE_MINUTE + MARKET_CLOSE_BUFFER_MINUTES,
        second=0,
        microsecond=0,
    )

    return market_open <= tehran_now <= market_close


def _is_trading_day() -> bool:
    """Check if today is a trading day (Saturday-Wednesday for TSE).

    Tehran Stock Exchange trades Saturday through Wednesday.
    Thursday and Friday are weekends.
    """
    now = datetime.now(UTC)
    tehran_now = now + timedelta(hours=3, minutes=30)
    # Saturday=5, Sunday=6, Monday=0, Tuesday=1, Wednesday=2
    # Thursday=3, Friday=4 are weekends
    return tehran_now.weekday() in {5, 6, 0, 1, 2}


# ═══════════════════════════════════════════════════════════════
# Provider Configuration Builder
# ═══════════════════════════════════════════════════════════════

def _build_provider_config() -> MarketProviderConfig:
    """Build provider configuration from settings."""
    return MarketProviderConfig(
        base_url=settings.TSETMC_BASE_URL,
        request_timeout=settings.TSETMC_REQUEST_TIMEOUT,
        connect_timeout=settings.TSETMC_CONNECT_TIMEOUT,
        max_concurrent=settings.TSETMC_MAX_CONCURRENT,
        retry_attempts=settings.TSETMC_RETRY_ATTEMPTS,
        retry_base_delay=settings.TSETMC_RETRY_BASE_DELAY,
        retry_max_delay=settings.TSETMC_RETRY_MAX_DELAY,
        retry_backoff_multiplier=settings.TSETMC_RETRY_BACKOFF_MULTIPLIER,
        circuit_breaker_failure_threshold=settings.TSETMC_CIRCUIT_BREAKER_FAILURE_THRESHOLD,
        circuit_breaker_reset_seconds=settings.TSETMC_CIRCUIT_BREAKER_RESET_SECONDS,
        health_check_interval=settings.TSETMC_HEALTH_CHECK_INTERVAL_SECONDS,
    )


# ═══════════════════════════════════════════════════════════════
# Base Task Class
# ═══════════════════════════════════════════════════════════════

class ResilientMarketTask(Task):
    """Base task with resilience features for market sync tasks.

    Features:
      - Auto-retry on transient failures
      - Exponential backoff with jitter
      - Bounded retry count
      - Structured logging
    """

    autoretry_for = (ConnectionError, TimeoutError)
    retry_backoff = True
    retry_backoff_max = 60
    retry_jitter = True
    retry_kwargs = {"max_retries": 3}

    def on_failure(self, exc: Exception, task_id: str, args: tuple, kwargs: dict, einfo: Any) -> None:
        """Log task failure with context."""
        logger.error(
            "task.failed task=%s task_id=%s error=%s",
            self.name,
            task_id,
            exc,
        )

    def on_success(self, retval: Any, task_id: str, args: tuple, kwargs: dict) -> None:
        """Log task success."""
        logger.info(
            "task.success task=%s task_id=%s",
            self.name,
            task_id,
        )

    def on_retry(self, exc: Exception, task_id: str, args: tuple, kwargs: dict, einfo: Any) -> None:
        """Log retry attempt."""
        logger.warning(
            "task.retry task=%s task_id=%s error=%s",
            self.name,
            task_id,
            exc,
        )


# ═══════════════════════════════════════════════════════════════
# Async Implementation Functions
# ═══════════════════════════════════════════════════════════════

async def _run_live_price_sync() -> dict[str, Any]:
    """Run live price sync with full observability.

    Returns:
        Dict with sync results and timing information.
    """
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info(
        "sync.live.start time=%s market_session=%s trading_day=%s",
        started_at.isoformat(),
        _is_market_session(),
        _is_trading_day(),
    )

    # Skip sync outside market session
    if not _is_trading_day():
        logger.info("sync.live.skip reason=not_trading_day")
        return {
            "status": "skipped",
            "reason": "not_trading_day",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": 0,
        }

    if not _is_market_session():
        logger.info("sync.live.skip reason=outside_market_session")
        return {
            "status": "skipped",
            "reason": "outside_market_session",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": 0,
        }

    try:
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            service = MarketIntegrationService(repository=repo)

            # Run the sync
            report = await service.sync_tsetmc_live_prices()

            # Record sync status
            duration_ms = (time.monotonic() - start_time) * 1000

            # Update sync metadata in Redis
            try:
                await market_cache.cache_sync_status(
                    last_sync_at=report.finished_at,
                    synced_assets=report.synced_assets,
                    failed_assets=report.failed_assets,
                    provider_status="healthy",
                )
            except Exception as exc:
                logger.warning("sync.live.status_cache_failed error=%s", exc)

            logger.info(
                "sync.live.complete duration=%.1fms total=%d synced=%d failed=%d",
                duration_ms,
                report.total_assets,
                report.synced_assets,
                report.failed_assets,
            )

            return {
                "status": "success",
                "started_at": report.started_at.isoformat(),
                "finished_at": report.finished_at.isoformat(),
                "duration_ms": round(duration_ms, 1),
                "total_assets": report.total_assets,
                "synced_assets": report.synced_assets,
                "failed_assets": report.failed_assets,
            }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "sync.live.failed duration=%.1fms error=%s",
            duration_ms,
            exc,
        )

        # Record failure status
        try:
            await market_cache.cache_sync_status(
                last_sync_at=datetime.now(UTC),
                synced_assets=0,
                failed_assets=0,
                provider_status="error",
            )
        except Exception:
            pass

        return {
            "status": "error",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


async def _run_daily_benchmark_sync() -> dict[str, Any]:
    """Run daily benchmark sync with full observability.

    Returns:
        Dict with sync results and timing information.
    """
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("sync.benchmark.start time=%s", started_at.isoformat())

    try:
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            service = MarketIntegrationService(repository=repo)

            # Run the sync
            payloads = await service.sync_daily_benchmarks()

            duration_ms = (time.monotonic() - start_time) * 1000

            logger.info(
                "sync.benchmark.complete duration=%.1fms benchmarks=%s count=%d",
                duration_ms,
                [item.benchmark_type.value for item in payloads],
                len(payloads),
            )

            return {
                "status": "success",
                "synced_at": started_at.isoformat(),
                "duration_ms": round(duration_ms, 1),
                "benchmarks": [item.benchmark_type.value for item in payloads],
                "count": len(payloads),
            }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "sync.benchmark.failed duration=%.1fms error=%s",
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


async def _run_health_check() -> dict[str, Any]:
    """Run provider health check with observability.

    Returns:
        Dict with health status and diagnostics.
    """
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("healthcheck.start time=%s", started_at.isoformat())

    try:
        from app.services.tsetmc_provider import TSETMCProvider

        config = _build_provider_config()
        provider = TSETMCProvider(config)

        async with provider:
            health = await provider.healthcheck()

        duration_ms = (time.monotonic() - start_time) * 1000

        logger.info(
            "healthcheck.complete status=%s latency=%.1fms",
            health.status.value,
            health.latency_ms or 0,
        )

        # Update provider status in sync metadata
        try:
            await market_cache.cache_sync_status(
                last_sync_at=datetime.now(UTC),
                synced_assets=0,
                failed_assets=0,
                provider_status=health.status.value,
            )
        except Exception:
            pass

        return {
            "status": "success",
            "checked_at": started_at.isoformat(),
            "duration_ms": round(duration_ms, 1),
            "provider_status": health.status.value,
            "latency_ms": health.latency_ms,
            "last_success_at": health.last_success_at.isoformat() if health.last_success_at else None,
            "error_message": health.error_message,
            "details": health.details,
        }

    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error(
            "healthcheck.failed duration=%.1fms error=%s",
            duration_ms,
            exc,
        )

        return {
            "status": "error",
            "checked_at": started_at.isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


async def _run_market_watch_crawl() -> dict[str, Any]:
    started_at = datetime.now(UTC)
    start_time = time.monotonic()
    logger.info("market_watch.start time=%s", started_at.isoformat())
    try:
        from app.services.tsetmc_provider import TSETMCProvider

        config = _build_provider_config()
        async with async_session_factory() as db:
            repo = MarketDataRepository(db)
            provider = TSETMCProvider(config)
            async with provider:
                crawler = MarketWatchCrawler(provider=provider, repository=repo)
                report = await crawler.run()
        duration_ms = (time.monotonic() - start_time) * 1000
        return {
            "status": report.status,
            "started_at": report.started_at.isoformat(),
            "finished_at": report.finished_at.isoformat(),
            "duration_ms": round(duration_ms, 1),
            "records_received": report.records_received,
            "records_valid": report.records_valid,
            "records_inserted": report.records_inserted,
            "records_updated": report.records_updated,
            "errors_count": report.errors_count,
            "last_success_at": report.last_success_at.isoformat() if report.last_success_at else None,
            "suspicious_reason": report.suspicious_reason,
            "indices_synced": report.indices_synced,
            "overview_synced": report.overview_synced,
            "error": report.error_message,
        }
    except Exception as exc:
        duration_ms = (time.monotonic() - start_time) * 1000
        logger.error("market_watch.failed duration=%.1fms error=%s", duration_ms, exc)
        return {
            "status": "error",
            "started_at": started_at.isoformat(),
            "finished_at": datetime.now(UTC).isoformat(),
            "duration_ms": round(duration_ms, 1),
            "error": str(exc),
        }


async def _run_codal_crawl() -> dict[str, Any]:
    provider = HttpCodalProvider()
    try:
        async with async_session_factory() as db:
            report = await CodalCrawler(
                provider=provider,
                repository=MarketDataRepository(db),
            ).run()
        return {
            "status": report.status,
            "started_at": report.started_at.isoformat(),
            "finished_at": report.finished_at.isoformat(),
            "records_received": report.records_received,
            "records_valid": report.records_valid,
            "records_upserted": report.records_upserted,
            "errors_count": report.errors_count,
            "error": report.error_message,
        }
    finally:
        await provider.close()


async def _run_fipiran_sync() -> dict[str, Any]:
    provider = build_fipiran_provider()
    try:
        async with async_session_factory() as db:
            report = await FundSyncService(
                provider=provider,
                repository=MarketDataRepository(db),
            ).run()
        return {
            "status": report.status,
            "started_at": report.started_at.isoformat(),
            "finished_at": report.finished_at.isoformat(),
            "funds_received": report.funds_received,
            "funds_upserted": report.funds_upserted,
            "navs_upserted": report.navs_upserted,
            "benchmark_ticks_upserted": report.benchmark_ticks_upserted,
            "errors_count": report.errors_count,
            "error": report.error_message,
        }
    finally:
        await provider.close()

# ═══════════════════════════════════════════════════════════════
# Celery Task Definitions
# ═══════════════════════════════════════════════════════════════

@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.sync_tsetmc_live_prices",
    max_retries=3,
    soft_time_limit=45,
    time_limit=60,
)
def sync_tsetmc_live_prices(self: ResilientMarketTask) -> dict[str, Any]:
    """Sync live TSETMC prices and cache them in Redis.

    This task:
      1. Checks if we're in market session (skips if not)
      2. Fetches live prices from TSETMC via provider abstraction
      3. Persists to DB (DailyPrice + Asset.current_price)
      4. Caches in Redis for fast reads
      5. Records sync status for observability

    Schedule: Every minute during trading hours (*/1 * * * *)
    """
    return asyncio.run(_run_live_price_sync())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.crawl_tsetmc_market_watch",
    max_retries=2,
    soft_time_limit=60,
    time_limit=90,
)
def crawl_tsetmc_market_watch(self: ResilientMarketTask) -> dict[str, Any]:
    """Fetch full TSETMC Market Watch, persist latest quotes, and refresh Redis."""
    return asyncio.run(_run_market_watch_crawl())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.crawl_codal_disclosures",
    max_retries=2,
    soft_time_limit=60,
    time_limit=90,
)
def crawl_codal_disclosures(self: ResilientMarketTask) -> dict[str, Any]:
    """Fetch, normalize, persist, and cache latest Codal disclosures."""
    return asyncio.run(_run_codal_crawl())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.sync_fipiran_funds",
    max_retries=1,
    soft_time_limit=120,
    time_limit=150,
)
def sync_fipiran_funds(self: ResilientMarketTask) -> dict[str, Any]:
    """Sync normalized fund metadata and latest NAV snapshots."""
    return asyncio.run(_run_fipiran_sync())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.sync_daily_benchmarks",
    max_retries=2,
    soft_time_limit=30,
    time_limit=45,
)
def sync_daily_benchmarks(self: ResilientMarketTask) -> dict[str, Any]:
    """Sync daily benchmark candles for Gold/FX/TEDPIX.

    This task:
      1. Fetches Gold 18k and USD/IRR from external APIs
      2. Fetches TEDPIX from TSETMC
      3. Persists to benchmark_history table

    Schedule: 16:30 on trading days (30 16 * * 1-5)
    """
    return asyncio.run(_run_daily_benchmark_sync())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.check_provider_health",
    max_retries=1,
    soft_time_limit=15,
    time_limit=30,
)
def check_provider_health(self: ResilientMarketTask) -> dict[str, Any]:
    """Check TSETMC provider health and connectivity.

    This task:
      1. Performs a lightweight health check
      2. Records provider status and latency
      3. Updates sync metadata for monitoring

    Schedule: Every 5 minutes (*/5 * * * *)
    """
    return asyncio.run(_run_health_check())


@celery_app.task(
    base=ResilientMarketTask,
    bind=True,
    name="app.tasks.market_tasks.sync_market_bundle",
    max_retries=2,
    soft_time_limit=90,
    time_limit=120,
)
def sync_market_bundle(self: ResilientMarketTask) -> dict[str, Any]:
    """Run live price and benchmark sync in a single Celery task.

    This is a convenience task that runs both syncs sequentially.
    Useful for manual triggers or catch-up syncs.

    Schedule: Not scheduled by default (manual trigger only)
    """
    started_at = datetime.now(UTC)
    start_time = time.monotonic()

    logger.info("sync.bundle.start time=%s", started_at.isoformat())

    live_result = asyncio.run(_run_live_price_sync())
    benchmark_result = asyncio.run(_run_daily_benchmark_sync())

    duration_ms = (time.monotonic() - start_time) * 1000

    logger.info(
        "sync.bundle.complete duration=%.1fms live_status=%s benchmark_status=%s",
        duration_ms,
        live_result.get("status"),
        benchmark_result.get("status"),
    )

    return {
        "status": "success",
        "started_at": started_at.isoformat(),
        "finished_at": datetime.now(UTC).isoformat(),
        "duration_ms": round(duration_ms, 1),
        "live": live_result,
        "benchmark": benchmark_result,
    }


# ═══════════════════════════════════════════════════════════════
# Utility Functions for Task Management
# ═══════════════════════════════════════════════════════════════

def get_sync_status_sync() -> dict[str, Any] | None:
    """Synchronously get sync status from Redis.

    Used by monitoring endpoints that can't await.
    """
    redis = get_redis()
    if not redis:
        return None

    try:
        raw = redis.get(market_cache._sync_status_key())
        if raw:
            import json
            return json.loads(raw)
    except Exception:
        pass

    return None


def get_task_info(task_name: str) -> dict[str, Any]:
    """Get information about a Celery task.

    Returns:
        Dict with task metadata including last run time and status.
    """
    result = {
        "task_name": task_name,
        "schedule": None,
        "last_status": None,
    }

    # Get schedule from beat config
    beat_schedule = celery_app.conf.beat_schedule or {}
    if task_name in beat_schedule:
        schedule_info = beat_schedule[task_name]
        result["schedule"] = str(schedule_info.get("schedule", "unknown"))

    return result
