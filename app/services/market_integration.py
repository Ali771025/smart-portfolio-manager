"""Market integration services for live prices and benchmark ingestion.

This module provides the application-level orchestration for market data sync.
It uses the MarketDataProvider protocol for fetching data, making the actual
data source swappable without changing business logic.

Architecture:
  MarketIntegrationService
    ├── MarketDataProvider (Protocol) ← TSETMCProvider or any future provider
    ├── MarketDataRepository (DB persistence)
    └── Redis cache layer (price caching)
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import TYPE_CHECKING

import httpx
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core import market_cache
from app.core.config import settings
from app.core.redis import bulk_cache_prices
from app.models.asset import Asset
from app.models.enums import BenchmarkType
from app.repositories.market_data import MarketDataRepository
from app.services.market_provider import (
    IndexSnapshot,
    InstrumentState,
    LiveMarketSnapshot,
    MarketProviderConfig,
    MarketDataProvider,
    MarketIndex,
    MarketOverview,
    PriceBar,
    ProviderHealth,
)
from app.services.market_normalizers import TSETMCNormalizer

if TYPE_CHECKING:
    pass

logger = logging.getLogger("market_integration")
FOUR_PLACES = Decimal("0.0001")
ZERO = Decimal("0.0000")


def q4(value: Decimal) -> Decimal:
    """Normalize Decimal values to NUMERIC(18,4) compatible precision."""
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


# ═══════════════════════════════════════════════════════════════
# Value Objects (Internal to this module)
# ═══════════════════════════════════════════════════════════════

@dataclass(slots=True)
class LivePricePayload:
    """Internal payload for live price data, bridges provider snapshot to DB."""
    close_price: Decimal
    last_trade_price: Decimal
    adjusted_close: Decimal
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    volume: int
    ticker_status: str
    has_corporate_action: bool

    @classmethod
    def from_snapshot(cls, snapshot: LiveMarketSnapshot) -> LivePricePayload:
        """Create from provider's LiveMarketSnapshot."""
        return cls(
            close_price=snapshot.close_price,
            last_trade_price=snapshot.last_trade_price,
            adjusted_close=snapshot.close_price,
            open_price=snapshot.open_price,
            high_price=snapshot.high_price,
            low_price=snapshot.low_price,
            volume=snapshot.volume,
            ticker_status=snapshot.state.value,
            has_corporate_action=snapshot.has_corporate_action,
        )


@dataclass(slots=True)
class BenchmarkPayload:
    benchmark_type: BenchmarkType
    price_date: date
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    close_price: Decimal
    adjusted_close: Decimal
    adjustment_factor: Decimal
    source: str
    volume: int | None = None


@dataclass(slots=True)
class MarketSyncReport:
    started_at: datetime
    finished_at: datetime
    total_assets: int
    synced_assets: int
    failed_assets: int
    provider_health: ProviderHealth | None = None


@dataclass(slots=True)
class AssetSyncPayload:
    asset_id: uuid.UUID
    closing_price: Decimal
    last_price: Decimal
    tradeable: bool
    updated_at: datetime
    history_record: dict
    quote: object | None = None


# ═══════════════════════════════════════════════════════════════
# Circuit Breaker (kept for service-level protection)
# ═══════════════════════════════════════════════════════════════

class CircuitBreaker:
    """Simple per-worker circuit breaker to protect upstream dependencies."""

    def __init__(self, failure_threshold: int, reset_seconds: int) -> None:
        self.failure_threshold = failure_threshold
        self.reset_seconds = reset_seconds
        self.failure_count = 0
        self.opened_until: datetime | None = None

    def allow(self) -> bool:
        if self.opened_until is None:
            return True
        if datetime.now(UTC) >= self.opened_until:
            self.failure_count = 0
            self.opened_until = None
            return True
        return False

    def success(self) -> None:
        self.failure_count = 0
        self.opened_until = None

    def failure(self) -> None:
        self.failure_count += 1
        if self.failure_count >= self.failure_threshold:
            self.opened_until = datetime.now(UTC) + timedelta(seconds=self.reset_seconds)


# ═══════════════════════════════════════════════════════════════
# External Benchmark Client (non-TSETMC sources)
# ═══════════════════════════════════════════════════════════════

class BenchmarkClient:
    """External benchmark feed adapter for Gold 18k and USD/IRR daily prices."""

    def __init__(self) -> None:
        self._client: httpx.AsyncClient | None = None

    async def __aenter__(self) -> BenchmarkClient:
        self._client = httpx.AsyncClient(timeout=httpx.Timeout(settings.TSETMC_REQUEST_TIMEOUT))
        return self

    async def __aexit__(self, *_: object) -> None:
        if self._client is not None:
            await self._client.aclose()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=20),
        retry=retry_if_exception_type((httpx.TimeoutException, httpx.HTTPStatusError)),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def _fetch_json(self, url: str) -> dict:
        if self._client is None:
            raise RuntimeError("BenchmarkClient is not initialized")
        response = await self._client.get(url)
        response.raise_for_status()
        return response.json()

    @staticmethod
    def _extract_price(payload: dict) -> Decimal:
        for key in ("price", "value", "close", "last", "rate"):
            if key in payload:
                return q4(Decimal(str(payload[key])))
        raise ValueError("Unable to find benchmark price in payload")

    async def fetch_daily_benchmarks(self, price_date: date) -> list[BenchmarkPayload]:
        gold_payload = await self._fetch_json(settings.BENCHMARK_GOLD18_API_URL)
        usd_payload = await self._fetch_json(settings.BENCHMARK_USD_IRR_API_URL)

        gold_price = self._extract_price(gold_payload)
        usd_price = self._extract_price(usd_payload)

        return [
            BenchmarkPayload(
                benchmark_type=BenchmarkType.GOLD_18K,
                price_date=price_date,
                open_price=gold_price,
                high_price=gold_price,
                low_price=gold_price,
                close_price=gold_price,
                adjusted_close=gold_price,
                adjustment_factor=Decimal("1.0000"),
                source="EXTERNAL_GOLD18",
            ),
            BenchmarkPayload(
                benchmark_type=BenchmarkType.USD_IRR,
                price_date=price_date,
                open_price=usd_price,
                high_price=usd_price,
                low_price=usd_price,
                close_price=usd_price,
                adjusted_close=usd_price,
                adjustment_factor=Decimal("1.0000"),
                source="EXTERNAL_USD_IRR",
            ),
        ]


# ═══════════════════════════════════════════════════════════════
# Market Integration Service
# ═══════════════════════════════════════════════════════════════

class MarketIntegrationService:
    """Application service orchestrating live market and benchmark updates.

    This service uses the MarketDataProvider protocol for fetching market data.
    The provider is injected at construction, making it easy to swap implementations.

    Usage:
        provider = TSETMCProvider(config)
        service = MarketIntegrationService(repository=repo, provider=provider)
        report = await service.sync_tsetmc_live_prices()
    """

    def __init__(
        self,
        repository: MarketDataRepository,
        provider: MarketDataProvider | None = None,
    ) -> None:
        self.repository = repository
        self._provider = provider
        self.breaker = CircuitBreaker(
            failure_threshold=settings.MARKET_CIRCUIT_BREAKER_FAILURE_THRESHOLD,
            reset_seconds=settings.MARKET_CIRCUIT_BREAKER_RESET_SECONDS,
        )

    def _get_provider(self) -> MarketDataProvider:
        """Lazy-load provider if not injected."""
        if self._provider is None:
            from app.services.tsetmc_provider import TSETMCProvider
            config = MarketProviderConfig(
                base_url=settings.TSETMC_BASE_URL,
                request_timeout=settings.TSETMC_REQUEST_TIMEOUT,
                max_concurrent=settings.TSETMC_MAX_CONCURRENT,
                retry_attempts=settings.TSETMC_RETRY_ATTEMPTS,
                retry_base_delay=settings.TSETMC_RETRY_BASE_DELAY,
            )
            self._provider = TSETMCProvider(config)
        return self._provider

    async def sync_tsetmc_live_prices(self) -> MarketSyncReport:
        """Fetch live market prices and persist both real-time and historical rows.

        Workflow:
        - Pull active assets from DB
        - Fetch prices concurrently via MarketDataProvider
        - Upsert Asset.current_price and DailyPrice
        - Cache each live price in Redis for 60 seconds
        """
        started_at = datetime.now(UTC)
        now = datetime.now(UTC)
        trade_date = now.date()
        provider = self._get_provider()

        assets = await self.repository.list_active_tsetmc_assets()
        if not assets:
            return MarketSyncReport(
                started_at=started_at,
                finished_at=datetime.now(UTC),
                total_assets=0,
                synced_assets=0,
                failed_assets=0,
            )

        failed_assets = 0
        cache_batch: dict[str, tuple[Decimal, datetime]] = {}

        async with provider:
            tasks = [
                self._sync_one_asset(
                    provider=provider,
                    asset=asset,
                    trade_date=trade_date,
                    now=now,
                )
                for asset in assets
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)

        synced_payloads: list[AssetSyncPayload] = []
        for item in results:
            if isinstance(item, Exception):
                failed_assets += 1
                logger.warning("Market sync asset failed: %s", item)
                continue
            if item is None:
                failed_assets += 1
                continue
            synced_payloads.append(item)
            cache_batch[str(item.asset_id)] = (item.closing_price, item.updated_at)

        if synced_payloads:
            await self.repository.bulk_update_asset_prices([
                {
                    "asset_id": item.asset_id,
                    "closing_price": item.closing_price,
                    "last_price": item.last_price,
                    "tradeable": item.tradeable,
                    "updated_at": item.updated_at,
                }
                for item in synced_payloads
            ])
            await self.repository.bulk_upsert_price_history([
                item.history_record for item in synced_payloads
            ])

        await self.repository.commit()
        await bulk_cache_prices(cache_batch, ttl_seconds=settings.REDIS_LIVE_PRICE_TTL_SECONDS)
        await market_cache.bulk_cache_market_quotes(
            [item.quote for item in synced_payloads if item.quote is not None],
            publish_stream=True,
        )

        return MarketSyncReport(
            started_at=started_at,
            finished_at=datetime.now(UTC),
            total_assets=len(assets),
            synced_assets=len(synced_payloads),
            failed_assets=failed_assets,
        )

    async def _sync_one_asset(
        self,
        *,
        provider: MarketDataProvider,
        asset: Asset,
        trade_date: date,
        now: datetime,
    ) -> AssetSyncPayload | None:
        """Fetch and normalize a single asset's price data via the provider."""
        if not self.breaker.allow():
            logger.warning("Circuit breaker open. Skipping asset %s", asset.ticker_symbol)
            return None

        try:
            snapshot = await provider.fetch_live_market_snapshot(asset.tsetmc_id or "")
        except Exception:
            self.breaker.failure()
            raise

        if snapshot is None or snapshot.close_price <= ZERO:
            self.breaker.failure()
            return None

        self.breaker.success()

        # Convert provider snapshot to internal payload
        payload = LivePricePayload.from_snapshot(snapshot)

        is_tradeable = snapshot.state not in {
            InstrumentState.HALT,
            InstrumentState.SUSPENDED,
            InstrumentState.CLOSED,
            InstrumentState.STOPPED,
        }

        adjustment_factor = Decimal("1.0000")
        if payload.close_price > ZERO:
            adjustment_factor = q4(payload.adjusted_close / payload.close_price)

        return AssetSyncPayload(
            asset_id=asset.id,
            closing_price=payload.close_price,
            last_price=payload.last_trade_price,
            tradeable=is_tradeable,
            updated_at=now,
            history_record={
                "asset_id": asset.id,
                "price_date": trade_date,
                "open_price": payload.open_price,
                "high_price": payload.high_price,
                "low_price": payload.low_price,
                "close_price": payload.close_price,
                "last_trade_price": payload.last_trade_price,
                "adjusted_close": payload.adjusted_close,
                "adjustment_factor": adjustment_factor,
                "volume": payload.volume,
            },
            quote=TSETMCNormalizer.quote_from_snapshot(snapshot),
        )

    async def fetch_live_price(
        self,
        ins_code: str,
    ) -> LivePricePayload | None:
        """Fetch a single asset's live price via the provider.

        This is a convenience method for on-demand price fetching.
        """
        provider = self._get_provider()
        async with provider:
            snapshot = await provider.fetch_live_market_snapshot(ins_code)
            if snapshot is None:
                return None
            return LivePricePayload.from_snapshot(snapshot)

    async def fetch_symbol_history(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[tuple[date, Decimal]]:
        """Fetch historical price data via the provider."""
        provider = self._get_provider()
        async with provider:
            bars = await provider.fetch_symbol_history(ins_code, start_date, end_date)
            return [(bar.date, bar.close_price) for bar in bars]

    async def fetch_symbol_price_bars(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        """Fetch normalized historical price bars via the provider."""
        provider = self._get_provider()
        async with provider:
            return await provider.fetch_symbol_history(ins_code, start_date, end_date)

    async def fetch_index_snapshot(self, index_code: str) -> IndexSnapshot | None:
        """Fetch a normalized index snapshot via the provider."""
        provider = self._get_provider()
        async with provider:
            return await provider.fetch_index_snapshot(index_code)

    async def fetch_indices(self) -> list[MarketIndex]:
        provider = self._get_provider()
        async with provider:
            return await provider.get_indices()

    async def fetch_market_overview(self) -> MarketOverview | None:
        provider = self._get_provider()
        async with provider:
            return await provider.get_market_overview()

    async def sync_market_summary(self) -> MarketOverview | None:
        """Fetch and persist indices plus the dashboard market overview."""
        provider = self._get_provider()
        async with provider:
            indices = await provider.get_indices()
            overview = await provider.get_market_overview()

        if indices:
            await self.repository.upsert_indices(indices)
        if overview is not None:
            await self.repository.upsert_market_overview(overview)
        await self.repository.commit()

        if indices:
            await market_cache.cache_market_indices(indices)
        if overview is not None:
            await market_cache.cache_normalized_market_overview(overview)
        return overview

    async def sync_daily_benchmarks(self, price_date: date | None = None) -> list[BenchmarkPayload]:
        """Fetch and persist Gold18k, USD/IRR and TEDPIX daily candles."""
        target_date = price_date or datetime.now(UTC).date()
        payloads: list[BenchmarkPayload] = []

        # External benchmarks (Gold, USD)
        async with BenchmarkClient() as benchmark_client:
            payloads.extend(await benchmark_client.fetch_daily_benchmarks(target_date))

        # TEDPIX via provider
        provider = self._get_provider()
        async with provider:
            index_snapshot = await provider.fetch_index_snapshot(settings.TEDPIX_INS_CODE)
            if index_snapshot is not None:
                payloads.append(
                    BenchmarkPayload(
                        benchmark_type=BenchmarkType.TEDPIX,
                        price_date=target_date,
                        open_price=index_snapshot.open_value,
                        high_price=index_snapshot.high_value,
                        low_price=index_snapshot.low_value,
                        close_price=index_snapshot.last_value,
                        adjusted_close=index_snapshot.last_value,
                        adjustment_factor=Decimal("1.0000"),
                        source="TSETMC",
                        volume=index_snapshot.volume,
                    )
                )

        for payload in payloads:
            await self.repository.upsert_benchmark_history(
                benchmark_type=payload.benchmark_type,
                price_date=payload.price_date,
                open_price=payload.open_price,
                high_price=payload.high_price,
                low_price=payload.low_price,
                close_price=payload.close_price,
                adjusted_close=payload.adjusted_close,
                adjustment_factor=payload.adjustment_factor,
                volume=payload.volume,
                source=payload.source,
            )

        await self.repository.commit()
        return payloads

    async def upsert_benchmark(self, payload: BenchmarkPayload) -> None:
        await self.repository.upsert_benchmark_history(
            benchmark_type=payload.benchmark_type,
            price_date=payload.price_date,
            open_price=payload.open_price,
            high_price=payload.high_price,
            low_price=payload.low_price,
            close_price=payload.close_price,
            adjusted_close=payload.adjusted_close,
            adjustment_factor=payload.adjustment_factor,
            volume=payload.volume,
            source=payload.source,
        )
        await self.repository.commit()

    async def get_benchmark_series(
        self,
        *,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
        adjusted: bool,
    ) -> list[tuple[date, Decimal]]:
        rows = await self.repository.fetch_benchmark_rows(
            benchmark_types=[benchmark_type],
            start_date=start_date,
            end_date=end_date,
        )
        return [(row.date, row.get_price(adjusted)) for row in rows]

    async def check_provider_health(self) -> ProviderHealth:
        """Check the health status of the underlying market data provider."""
        provider = self._get_provider()
        async with provider:
            return await provider.healthcheck()
