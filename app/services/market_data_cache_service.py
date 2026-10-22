"""Write-through service for durable market data plus Redis latest snapshots."""

from __future__ import annotations

import logging

from app.core import market_cache
from app.repositories.market_data import MarketDataRepository
from app.services.market_provider import MarketIndex, MarketOverview, MarketQuote

logger = logging.getLogger("market_data_cache_service")


class MarketDataCacheService:
    """Persist normalized market data, then refresh Redis latest snapshots.

    PostgreSQL remains the durable source of truth. Redis writes are best-effort
    and intentionally do not fail the core ingestion/API path.
    """

    def __init__(self, repository: MarketDataRepository) -> None:
        self._repository = repository

    async def upsert_market_quotes(self, items: list[MarketQuote]) -> int:
        count = await self._repository.upsert_market_quotes(items)
        if count:
            cached = await market_cache.bulk_cache_market_quotes(items, publish_stream=True)
            if cached == 0:
                logger.debug("Redis quote cache unavailable after %d DB upserts", count)
        return count

    async def upsert_indices(self, items: list[MarketIndex]) -> int:
        count = await self._repository.upsert_indices(items)
        if count:
            await market_cache.cache_market_indices(items)
        return count

    async def upsert_market_overview(self, item: MarketOverview) -> int:
        count = await self._repository.upsert_market_overview(item)
        if count:
            await market_cache.cache_normalized_market_overview(item)
        return count

    async def refresh_watch_snapshot(self) -> bool:
        quotes = await self._repository.get_market_watch_snapshot()
        return await market_cache.cache_market_watch_snapshot(quotes)
