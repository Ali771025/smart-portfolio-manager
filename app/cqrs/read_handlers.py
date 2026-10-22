"""CQRS read handlers with Redis exact-match cache and local LRU metadata cache."""

from __future__ import annotations

import asyncio
import hashlib
import json
import uuid
from collections import OrderedDict
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from enum import Enum
from typing import Any

from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.repositories.analytics_read import AnalyticsReadRepository, AssetMetadataRow
from app.models.enums import InventoryAccountingMethod
from app.schemas.analytics_engine import (
    AnalyticsPoint,
    AnalyticsResponse,
    OHLCVPoint,
    OHLCVResponse,
)

REPORT_CACHE_TTL_SECONDS = 30
OHLCV_CACHE_TTL_SECONDS = 10


@dataclass(slots=True, frozen=True)
class AnalyticsReportQuery:
    portfolio_id: uuid.UUID
    user_id: uuid.UUID
    window_start: datetime
    window_end: datetime
    inventory_method: InventoryAccountingMethod
    limit: int


@dataclass(slots=True, frozen=True)
class OhlcvQuery:
    asset_id: uuid.UUID
    window_start: datetime
    window_end: datetime
    limit: int


@dataclass(slots=True, frozen=True)
class ProblemDetails:
    type: str
    title: str
    status: int
    detail: str
    instance: str


class ReadModelProblem(Exception):
    """Exception carrying RFC 7807 details for query-side failures."""

    def __init__(self, *, status_code: int, title: str, detail: str, instance: str, type_slug: str) -> None:
        self.status_code = status_code
        self.problem = ProblemDetails(
            type=f"https://smartportfolio.local/problems/{type_slug}",
            title=title,
            status=status_code,
            detail=detail,
            instance=instance,
        )
        super().__init__(detail)


class LocalMetadataLRU:
    """Small in-process LRU cache for static metadata (asset and currency fields)."""

    def __init__(self, maxsize: int = 2048) -> None:
        self.maxsize = maxsize
        self._store: OrderedDict[str, Any] = OrderedDict()

    def get(self, key: str) -> Any | None:
        if key not in self._store:
            return None
        self._store.move_to_end(key)
        return self._store[key]

    def set(self, key: str, value: Any) -> None:
        if key in self._store:
            self._store.move_to_end(key)
        self._store[key] = value
        if len(self._store) > self.maxsize:
            self._store.popitem(last=False)


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, Enum):
        return value.value
    raise TypeError(f"Object of type {type(value)!r} is not JSON serializable")


def _exact_cache_key(namespace: str, payload: dict[str, Any]) -> str:
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, default=_json_default).encode("utf-8")
    ).hexdigest()
    return f"analytics-read:{namespace}:{digest}"


async def _redis_get(redis_client: Redis | None, key: str) -> str | None:
    if redis_client is None:
        return None
    try:
        raw = await redis_client.get(key)
    except Exception:
        return None

    if raw is None:
        return None
    return raw.decode("utf-8") if isinstance(raw, bytes) else str(raw)


async def _redis_set(redis_client: Redis | None, key: str, value: str, ttl_seconds: int) -> None:
    if redis_client is None:
        return
    try:
        await redis_client.setex(key, ttl_seconds, value)
    except Exception:
        return


class GetAnalyticsReportHandler:
    """CQRS query handler for portfolio analytics reports."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        redis_client: Redis | None,
        metadata_cache: LocalMetadataLRU,
    ) -> None:
        self.session_factory = session_factory
        self.redis_client = redis_client
        self.metadata_cache = metadata_cache

    async def handle(self, query: AnalyticsReportQuery) -> AnalyticsResponse:
        cache_key = _exact_cache_key(
            "portfolio-report",
            {
                "portfolio_id": str(query.portfolio_id),
                "user_id": str(query.user_id),
                "window_start": query.window_start,
                "window_end": query.window_end,
                "inventory_method": query.inventory_method,
                "limit": query.limit,
            },
        )

        cached = await _redis_get(self.redis_client, cache_key)
        if cached:
            return AnalyticsResponse.model_validate_json(cached)

        currency = await self._get_portfolio_currency(
            portfolio_id=query.portfolio_id,
            user_id=query.user_id,
        )
        if currency is None:
            raise ReadModelProblem(
                status_code=404,
                title="Portfolio Not Found",
                detail="Portfolio does not exist or is not accessible for this user.",
                instance=f"/analytics-engine/portfolios/{query.portfolio_id}/report",
                type_slug="portfolio-not-found",
            )

        points_task = self._fetch_rollup_points(query)
        risk_task = self._fetch_latest_risk(query)
        points, risk = await asyncio.gather(points_task, risk_task)

        total_realized = points[-1].realized_pnl_cumulative if points else Decimal("0")
        total_unrealized = points[-1].unrealized_pnl if points else Decimal("0")

        response = AnalyticsResponse(
            portfolio_id=query.portfolio_id,
            inventory_method=query.inventory_method,
            generated_at=datetime.now(UTC),
            window_start=query.window_start,
            window_end=query.window_end,
            currency=currency,
            total_realized_pnl=total_realized,
            total_unrealized_pnl=total_unrealized,
            max_drawdown=risk.max_drawdown if risk else None,
            sharpe_ratio=risk.sharpe_ratio if risk else None,
            points=points,
        )

        await _redis_set(
            self.redis_client,
            cache_key,
            response.model_dump_json(),
            REPORT_CACHE_TTL_SECONDS,
        )
        return response

    async def _get_portfolio_currency(self, *, portfolio_id: uuid.UUID, user_id: uuid.UUID) -> str | None:
        cache_key = f"portfolio-currency:{portfolio_id}:{user_id}"
        cached = self.metadata_cache.get(cache_key)
        if cached:
            return cached

        async with self.session_factory() as db:
            repo = AnalyticsReadRepository(db)
            currency = await repo.get_portfolio_currency_for_user(
                portfolio_id=portfolio_id,
                user_id=user_id,
            )

        if currency is not None:
            self.metadata_cache.set(cache_key, currency)
        return currency

    async def _fetch_rollup_points(self, query: AnalyticsReportQuery) -> list[AnalyticsPoint]:
        async with self.session_factory() as db:
            repo = AnalyticsReadRepository(db)
            rows = await repo.fetch_portfolio_rollup_rows(
                portfolio_id=query.portfolio_id,
                start_at=query.window_start,
                end_at=query.window_end,
                limit=query.limit,
            )

        return [
            AnalyticsPoint(
                bucket_start=row.bucket_start,
                total_market_value=row.close_market_value,
                total_cost_basis=row.close_cost_basis,
                realized_pnl_cumulative=row.realized_pnl_cumulative,
                unrealized_pnl=row.close_unrealized_pnl,
            )
            for row in rows
        ]

    async def _fetch_latest_risk(self, query: AnalyticsReportQuery) -> Any:
        async with self.session_factory() as db:
            repo = AnalyticsReadRepository(db)
            return await repo.fetch_latest_risk_snapshot(
                portfolio_id=query.portfolio_id,
                end_at=query.window_end,
            )


class GetAssetOhlcvHandler:
    """CQRS query handler for market OHLCV aggregates."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        redis_client: Redis | None,
        metadata_cache: LocalMetadataLRU,
    ) -> None:
        self.session_factory = session_factory
        self.redis_client = redis_client
        self.metadata_cache = metadata_cache

    async def handle(self, query: OhlcvQuery) -> OHLCVResponse:
        cache_key = _exact_cache_key(
            "asset-ohlcv",
            {
                "asset_id": str(query.asset_id),
                "window_start": query.window_start,
                "window_end": query.window_end,
                "limit": query.limit,
            },
        )

        cached = await _redis_get(self.redis_client, cache_key)
        if cached:
            return OHLCVResponse.model_validate_json(cached)

        metadata = await self.get_asset_metadata(query.asset_id)
        if metadata is None:
            raise ReadModelProblem(
                status_code=404,
                title="Asset Not Found",
                detail="Asset does not exist or is inactive.",
                instance=f"/analytics-engine/assets/{query.asset_id}/ohlcv",
                type_slug="asset-not-found",
            )

        async with self.session_factory() as db:
            repo = AnalyticsReadRepository(db)
            rows = await repo.fetch_asset_ohlcv_rows(
                asset_id=query.asset_id,
                start_at=query.window_start,
                end_at=query.window_end,
                limit=query.limit,
            )

        points = [
            OHLCVPoint(
                bucket_start=row.bucket_start,
                open_price=row.open_price,
                high_price=row.high_price,
                low_price=row.low_price,
                close_price=row.close_price,
                volume=row.total_volume,
                notional=row.total_notional,
            )
            for row in rows
        ]

        response = OHLCVResponse(
            asset_id=query.asset_id,
            ticker_symbol=metadata.ticker_symbol,
            generated_at=datetime.now(UTC),
            window_start=query.window_start,
            window_end=query.window_end,
            points=points,
        )

        await _redis_set(
            self.redis_client,
            cache_key,
            response.model_dump_json(),
            OHLCV_CACHE_TTL_SECONDS,
        )
        return response

    async def get_asset_metadata(self, asset_id: uuid.UUID) -> AssetMetadataRow | None:
        cache_key = f"asset-meta:{asset_id}"
        cached = self.metadata_cache.get(cache_key)
        if cached:
            return cached

        async with self.session_factory() as db:
            repo = AnalyticsReadRepository(db)
            metadata = await repo.fetch_asset_metadata(asset_id=asset_id)

        if metadata is not None:
            self.metadata_cache.set(cache_key, metadata)
        return metadata


@dataclass(slots=True)
class ReadHandlerBundle:
    analytics_report: GetAnalyticsReportHandler
    asset_ohlcv: GetAssetOhlcvHandler
    redis_client: Redis | None
