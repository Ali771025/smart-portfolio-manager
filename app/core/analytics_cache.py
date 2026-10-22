"""Redis cache layer for analytics computations.

Provides caching for expensive analytics computations:
  - Returns summary (cached 15 minutes)
  - Benchmark comparison (cached 15 minutes)
  - Factor summary (cached 30 minutes)

Cache Key Schema:
    analytics:returns:{asset_id}:{period}  → JSON ReturnsSummaryResponseDTO
    analytics:benchmark:{asset_id}:{benchmark}:{period} → JSON BenchmarkComparisonResultDTO
    analytics:factors:{asset_id}:{period}  → JSON FactorSummaryResponseDTO

Design:
  - Cache TTL based on computation cost and data freshness
  - Automatic cache invalidation on price updates
  - Graceful fallback to computation on cache miss
"""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from typing import Any

from app.core.config import settings
from app.core.redis import get_redis

logger = logging.getLogger("analytics_cache")

# Cache TTL settings (in seconds)
RETURNS_CACHE_TTL = 15 * 60  # 15 minutes
BENCHMARK_CACHE_TTL = 15 * 60  # 15 minutes
FACTORS_CACHE_TTL = 30 * 60  # 30 minutes


# ═══════════════════════════════════════════════════════════════
# Key Builders
# ═══════════════════════════════════════════════════════════════

def _returns_key(asset_id: str, period: str) -> str:
    """Build Redis key for returns cache."""
    return f"analytics:returns:{asset_id}:{period}"


def _benchmark_key(asset_id: str, benchmark_id: str, period: str) -> str:
    """Build Redis key for benchmark comparison cache."""
    return f"analytics:benchmark:{asset_id}:{benchmark_id}:{period}"


def _factors_key(asset_id: str, period: str) -> str:
    """Build Redis key for factors cache."""
    return f"analytics:factors:{asset_id}:{period}"


# ═══════════════════════════════════════════════════════════════
# Returns Cache
# ═══════════════════════════════════════════════════════════════

async def cache_returns_summary(
    asset_id: str,
    period: str,
    data: dict[str, Any],
    ttl_seconds: int = RETURNS_CACHE_TTL,
) -> bool:
    """Cache returns summary."""
    redis = get_redis()
    if not redis:
        return False

    key = _returns_key(asset_id, period)
    payload = json.dumps(data, default=str)

    try:
        await redis.setex(key, ttl_seconds, payload)
        return True
    except Exception as exc:
        logger.warning("cache_returns_summary failed for %s: %s", asset_id, exc)
        return False


async def get_cached_returns_summary(
    asset_id: str,
    period: str,
) -> dict[str, Any] | None:
    """Get cached returns summary."""
    redis = get_redis()
    if not redis:
        return None

    key = _returns_key(asset_id, period)
    try:
        raw = await redis.get(key)
        if raw:
            return json.loads(raw)
    except Exception as exc:
        logger.warning("get_cached_returns_summary failed for %s: %s", asset_id, exc)

    return None


# ═══════════════════════════════════════════════════════════════
# Benchmark Comparison Cache
# ═══════════════════════════════════════════════════════════════

async def cache_benchmark_comparison(
    asset_id: str,
    benchmark_id: str,
    period: str,
    data: dict[str, Any],
    ttl_seconds: int = BENCHMARK_CACHE_TTL,
) -> bool:
    """Cache benchmark comparison."""
    redis = get_redis()
    if not redis:
        return False

    key = _benchmark_key(asset_id, benchmark_id, period)
    payload = json.dumps(data, default=str)

    try:
        await redis.setex(key, ttl_seconds, payload)
        return True
    except Exception as exc:
        logger.warning("cache_benchmark_comparison failed for %s: %s", asset_id, exc)
        return False


async def get_cached_benchmark_comparison(
    asset_id: str,
    benchmark_id: str,
    period: str,
) -> dict[str, Any] | None:
    """Get cached benchmark comparison."""
    redis = get_redis()
    if not redis:
        return None

    key = _benchmark_key(asset_id, benchmark_id, period)
    try:
        raw = await redis.get(key)
        if raw:
            return json.loads(raw)
    except Exception as exc:
        logger.warning("get_cached_benchmark_comparison failed for %s: %s", asset_id, exc)

    return None


# ═══════════════════════════════════════════════════════════════
# Factor Summary Cache
# ═══════════════════════════════════════════════════════════════

async def cache_factor_summary(
    asset_id: str,
    period: str,
    data: dict[str, Any],
    ttl_seconds: int = FACTORS_CACHE_TTL,
) -> bool:
    """Cache factor summary."""
    redis = get_redis()
    if not redis:
        return False

    key = _factors_key(asset_id, period)
    payload = json.dumps(data, default=str)

    try:
        await redis.setex(key, ttl_seconds, payload)
        return True
    except Exception as exc:
        logger.warning("cache_factor_summary failed for %s: %s", asset_id, exc)
        return False


async def get_cached_factor_summary(
    asset_id: str,
    period: str,
) -> dict[str, Any] | None:
    """Get cached factor summary."""
    redis = get_redis()
    if not redis:
        return None

    key = _factors_key(asset_id, period)
    try:
        raw = await redis.get(key)
        if raw:
            return json.loads(raw)
    except Exception as exc:
        logger.warning("get_cached_factor_summary failed for %s: %s", asset_id, exc)

    return None


# ═══════════════════════════════════════════════════════════════
# Cache Invalidation
# ═══════════════════════════════════════════════════════════════

async def invalidate_analytics_cache(
    asset_id: str,
) -> int:
    """Invalidate all analytics cache for an asset.

    Called when asset prices are updated.
    Returns number of keys deleted.
    """
    redis = get_redis()
    if not redis:
        return 0

    patterns = [
        f"analytics:returns:{asset_id}:*",
        f"analytics:benchmark:{asset_id}:*",
        f"analytics:factors:{asset_id}:*",
    ]

    deleted = 0
    for pattern in patterns:
        try:
            keys = await redis.keys(pattern)
            if keys:
                await redis.delete(*keys)
                deleted += len(keys)
        except Exception as exc:
            logger.warning("invalidate_analytics_cache failed for pattern %s: %s", pattern, exc)

    if deleted > 0:
        logger.info("invalidate_analytics_cache asset=%s deleted=%d", asset_id, deleted)

    return deleted
