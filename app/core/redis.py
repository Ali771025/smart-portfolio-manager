"""
Redis connection manager for price caching.
Provides sub-millisecond reads for dashboard portfolio valuation.

Cache Key Schema:
    price:{asset_id}  → JSON { "price": "52340.0000", "updated_at": "..." }
    
For Phase 2 MVP, if Redis is unavailable the system falls back
to direct DB reads — never blocks the user.
"""

import asyncio
import json
import logging
from decimal import Decimal
from datetime import datetime

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger("redis_cache")

# ═══════════════════════════════════════════════════════════════
# Global connection pool — initialized at app startup
# ═══════════════════════════════════════════════════════════════

_redis_pool: aioredis.Redis | None = None


async def init_redis() -> aioredis.Redis:
    """Initialize the async Redis connection pool."""
    global _redis_pool
    if _redis_pool is not None:
        return _redis_pool

    max_retries = max(1, settings.REDIS_STARTUP_MAX_RETRIES)
    retry_delay = max(0.0, settings.REDIS_STARTUP_RETRY_DELAY_SECONDS)
    last_error: Exception | None = None

    for attempt in range(1, max_retries + 1):
        candidate = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=50,
        )
        try:
            # Verify connectivity before publishing the pool globally.
            await candidate.ping()
            _redis_pool = candidate
            logger.info("Redis connection pool initialized.")
            return _redis_pool
        except Exception as exc:  # noqa: BLE001 - startup should retry then degrade gracefully
            last_error = exc
            try:
                close_method = getattr(candidate, "aclose", None)
                if callable(close_method):
                    await close_method()
                else:
                    await candidate.close()
            except Exception:  # noqa: BLE001 - best effort cleanup
                pass

            if attempt < max_retries:
                logger.warning(
                    "Redis connection attempt %s/%s failed: %s. Retrying in %.1fs.",
                    attempt,
                    max_retries,
                    exc,
                    retry_delay,
                )
                if retry_delay > 0:
                    await asyncio.sleep(retry_delay)

    assert last_error is not None
    raise last_error


def _clear_redis_pool() -> None:
    """Reset global Redis pool reference."""

    global _redis_pool
    _redis_pool = None


async def _close_client(client: aioredis.Redis) -> None:
    """Close Redis client across redis-py versions."""

    close_method = getattr(client, "aclose", None)
    if callable(close_method):
        await close_method()
    else:
        await client.close()


async def close_redis() -> None:
    """Gracefully close the Redis connection pool."""
    pool = _redis_pool
    _clear_redis_pool()
    if pool:
        await _close_client(pool)
        logger.info("Redis connection pool closed.")


def mark_redis_unavailable() -> None:
    """Drop cached Redis client so the next startup can reconnect cleanly."""

    _clear_redis_pool()


def get_redis() -> aioredis.Redis | None:
    """Return the active Redis pool (or None if unavailable)."""
    return _redis_pool


# ═══════════════════════════════════════════════════════════════
# Price Cache Operations
# ═══════════════════════════════════════════════════════════════


async def cache_asset_price(
    asset_id: str,
    price: Decimal,
    updated_at: datetime,
    ttl_seconds: int | None = None,
) -> None:
    """
    Write a single asset price to Redis with TTL.
    Non-blocking — failures are logged but never raised.
    """
    redis = get_redis()
    if not redis:
        return

    key = f"{settings.REDIS_PRICE_PREFIX}{asset_id}"
    payload = json.dumps({
        "price": str(price),
        "updated_at": updated_at.isoformat(),
    })
    try:
        await redis.setex(
            name=key,
            time=ttl_seconds or settings.REDIS_LIVE_PRICE_TTL_SECONDS,
            value=payload,
        )
    except Exception as e:
        logger.warning(f"Redis cache_asset_price failed for {asset_id}: {e}")


async def get_cached_price(asset_id: str) -> Decimal | None:
    """
    Read a single asset price from Redis.
    Returns None on miss or error — caller falls back to DB.
    """
    redis = get_redis()
    if not redis:
        return None

    key = f"{settings.REDIS_PRICE_PREFIX}{asset_id}"
    try:
        raw = await redis.get(key)
        if raw:
            data = json.loads(raw)
            return Decimal(data["price"])
    except Exception as e:
        logger.warning(f"Redis get_cached_price failed for {asset_id}: {e}")

    return None


async def bulk_cache_prices(
    prices: dict[str, tuple[Decimal, datetime]],
    ttl_seconds: int | None = None,
) -> None:
    """
    Batch-write multiple asset prices using Redis pipeline.
    Key: asset_id → Value: {price, updated_at}
    """
    redis = get_redis()
    if not redis or not prices:
        return

    try:
        async with redis.pipeline(transaction=False) as pipe:
            for asset_id, (price, updated_at) in prices.items():
                key = f"{settings.REDIS_PRICE_PREFIX}{asset_id}"
                payload = json.dumps({
                    "price": str(price),
                    "updated_at": updated_at.isoformat(),
                })
                pipe.setex(key, ttl_seconds or settings.REDIS_LIVE_PRICE_TTL_SECONDS, payload)
            await pipe.execute()
        logger.info(f"Bulk cached {len(prices)} asset prices in Redis.")
    except Exception as e:
        logger.warning(f"Redis bulk_cache_prices failed: {e}")
