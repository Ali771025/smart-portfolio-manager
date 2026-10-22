"""Analytics & performance service layer with async I/O and threadpool quant math.

This module keeps database access asynchronous via SQLAlchemy 2.0 `AsyncSession`
while delegating Pandas / NumPy-heavy calculations to Starlette's
`run_in_threadpool` so the FastAPI event loop stays responsive.
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import os
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Literal, Protocol

import numpy as np
import pandas as pd

try:  # Cache is optional; analytics falls back to uncached reads.
    from fastapi_cache import FastAPICache
except ModuleNotFoundError:  # pragma: no cover - depends on local environment
    FastAPICache = None  # type: ignore[assignment]

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.models.enums import BenchmarkType
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.market_data import BenchmarkHistory, PortfolioSnapshot
from app.models.portfolio import Portfolio
from app.services.quant_engine import calculate_advanced_risk_metrics

logger = logging.getLogger(__name__)

Timeframe = Literal["1M", "3M", "6M", "1Y", "ALL"]

TRADING_DAYS_PER_YEAR = 252
PERCENT_MULTIPLIER = 100.0
ANALYTICS_CACHE_TTL_SECONDS = 15 * 60
ANALYTICS_CACHE_VERSION_TTL_SECONDS = 7 * 24 * 60 * 60
ANALYTICS_CACHE_PREFIX = "analytics"
PROBLEM_BASE_URL = "https://smartportfolio.local/problems"
RISK_SCORE_MAX_VOLATILITY_PERCENT = 40.0
RISK_SCORE_MAX_DRAWDOWN = 0.35
RISK_SCORE_MAX_VAR = 0.08
RISK_SCORE_MAX_BETA_DISTANCE = 1.2


@dataclass(slots=True, frozen=True)
class ProblemDetails:
    """Minimal RFC 7807 payload used by the analytics domain layer."""

    type: str
    title: str
    status: int
    detail: str
    instance: str


class AnalyticsProblem(Exception):
    """Domain/service exception carrying RFC 7807 problem details."""

    def __init__(
        self,
        *,
        status_code: int,
        title: str,
        detail: str,
        instance: str,
        type_slug: str,
    ) -> None:
        self.status_code = status_code
        self.problem = ProblemDetails(
            type=f"{PROBLEM_BASE_URL}/{type_slug}",
            title=title,
            status=status_code,
            detail=detail,
            instance=instance,
        )
        super().__init__(detail)


@dataclass(slots=True, frozen=True)
class PortfolioSnapshotRow:
    """Typed, DB-agnostic snapshot row for vectorized analytics."""

    snapshot_date: date
    market_value: float | None
    cost_basis: float | None
    gain_loss: float | None
    gain_loss_pct: float | None


@dataclass(slots=True, frozen=True)
class BenchmarkHistoryRow:
    """Typed benchmark row used for vectorized beta/alpha alignment."""

    snapshot_date: date
    benchmark_value: float | None


@dataclass(slots=True, frozen=True)
class PortfolioMarketFields:
    """Latest market-driven valuation fields for analytics responses."""

    current_price: float | None
    closing_price: float | None
    daily_pnl: float | None
    total_unrealized_pnl: float | None
    last_market_update: datetime | None


class AnalyticsRepository(Protocol):
    """Persistence boundary for the analytics service."""

    async def get_default_portfolio_for_user(
        self,
        *,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        ...

    async def get_portfolio_for_user(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        ...

    async def fetch_latest_snapshot_date(self, *, portfolio_id: uuid.UUID) -> date | None:
        ...

    async def fetch_snapshot_rows(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date | None,
        end_date: date,
    ) -> list[PortfolioSnapshotRow]:
        ...

    async def fetch_position_based_snapshot_row(
        self,
        *,
        portfolio_id: uuid.UUID,
    ) -> PortfolioSnapshotRow | None:
        ...

    async def fetch_benchmark_rows(
        self,
        *,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkHistoryRow]:
        ...

    async def fetch_latest_market_fields(
        self,
        *,
        portfolio_id: uuid.UUID,
    ) -> PortfolioMarketFields:
        ...


class SQLAlchemyAnalyticsRepository:
    """Async SQLAlchemy implementation for daily portfolio snapshots."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_default_portfolio_for_user(
        self,
        *,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        result = await self.db.execute(
            select(Portfolio)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
            .order_by(Portfolio.created_at.asc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_portfolio_for_user(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Portfolio | None:
        result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        return result.scalar_one_or_none()

    async def fetch_latest_snapshot_date(self, *, portfolio_id: uuid.UUID) -> date | None:
        result = await self.db.execute(
            select(PortfolioSnapshot.snapshot_date)
            .where(PortfolioSnapshot.portfolio_id == portfolio_id)
            .order_by(PortfolioSnapshot.snapshot_date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def fetch_snapshot_rows(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date | None,
        end_date: date,
    ) -> list[PortfolioSnapshotRow]:
        stmt = (
            select(
                PortfolioSnapshot.snapshot_date,
                PortfolioSnapshot.total_market_value,
                PortfolioSnapshot.total_cost_basis,
                PortfolioSnapshot.total_gain_loss,
                PortfolioSnapshot.total_gain_loss_pct,
            )
            .where(
                PortfolioSnapshot.portfolio_id == portfolio_id,
                PortfolioSnapshot.snapshot_date <= end_date,
            )
            .order_by(PortfolioSnapshot.snapshot_date.asc())
        )
        if start_date is not None:
            stmt = stmt.where(PortfolioSnapshot.snapshot_date >= start_date)

        result = await self.db.execute(stmt)
        return [
            PortfolioSnapshotRow(
                snapshot_date=row.snapshot_date,
                market_value=float(row.total_market_value)
                if row.total_market_value is not None
                else None,
                cost_basis=float(row.total_cost_basis)
                if row.total_cost_basis is not None
                else None,
                gain_loss=float(row.total_gain_loss)
                if row.total_gain_loss is not None
                else None,
                gain_loss_pct=float(row.total_gain_loss_pct)
                if row.total_gain_loss_pct is not None
                else None,
            )
            for row in result.all()
        ]

    async def fetch_position_based_snapshot_row(
        self,
        *,
        portfolio_id: uuid.UUID,
    ) -> PortfolioSnapshotRow | None:
        result = await self.db.execute(
            select(
                func.coalesce(
                    func.sum(
                        AssetPosition.total_quantity
                        * func.coalesce(
                            func.nullif(Asset.last_trade_price, 0),
                            func.nullif(Asset.closing_price, 0),
                        )
                    ),
                    0,
                ).label("market_value"),
                func.coalesce(func.sum(AssetPosition.total_cost_basis), 0).label("cost_basis"),
            )
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.total_quantity > 0,
            )
        )
        row = result.one()
        market_value = float(row.market_value or 0.0)
        cost_basis = float(row.cost_basis or 0.0)
        if market_value <= 0 and cost_basis <= 0:
            return None

        gain_loss = market_value - cost_basis
        gain_loss_pct = (gain_loss / cost_basis) * PERCENT_MULTIPLIER if cost_basis > 0 else 0.0
        return PortfolioSnapshotRow(
            snapshot_date=date.today(),
            market_value=market_value,
            cost_basis=cost_basis,
            gain_loss=gain_loss,
            gain_loss_pct=gain_loss_pct,
        )

    async def fetch_latest_market_fields(
        self,
        *,
        portfolio_id: uuid.UUID,
    ) -> PortfolioMarketFields:
        result = await self.db.execute(
            select(
                func.sum(
                    AssetPosition.total_quantity
                    * func.coalesce(
                        func.nullif(Asset.last_trade_price, 0),
                        func.nullif(Asset.closing_price, 0),
                        0,
                    )
                ).label("current_price"),
                func.sum(AssetPosition.total_quantity * Asset.closing_price).label("closing_price"),
                func.sum(
                    AssetPosition.total_quantity
                    * (
                        func.coalesce(
                            func.nullif(Asset.last_trade_price, 0),
                            func.nullif(Asset.closing_price, 0),
                            0,
                        )
                        - Asset.previous_close_price
                    )
                ).label("daily_pnl"),
                func.sum(
                    AssetPosition.total_quantity
                    * (
                        func.coalesce(
                            func.nullif(Asset.last_trade_price, 0),
                            func.nullif(Asset.closing_price, 0),
                            0,
                        )
                        - AssetPosition.weighted_avg_cost
                    )
                ).label("total_unrealized_pnl"),
                func.max(Asset.price_updated_at).label("last_market_update"),
            )
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.total_quantity > 0,
            )
        )
        row = result.one()
        return PortfolioMarketFields(
            current_price=float(row.current_price) if row.current_price is not None else None,
            closing_price=float(row.closing_price) if row.closing_price is not None else None,
            daily_pnl=float(row.daily_pnl) if row.daily_pnl is not None else None,
            total_unrealized_pnl=(
                float(row.total_unrealized_pnl)
                if row.total_unrealized_pnl is not None
                else None
            ),
            last_market_update=row.last_market_update,
        )

    async def fetch_benchmark_rows(
        self,
        *,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkHistoryRow]:
        result = await self.db.execute(
            select(
                BenchmarkHistory.date,
                BenchmarkHistory.adjusted_close,
            )
            .where(
                BenchmarkHistory.benchmark_type == benchmark_type,
                BenchmarkHistory.date >= start_date,
                BenchmarkHistory.date <= end_date,
            )
            .order_by(BenchmarkHistory.date.asc())
        )
        return [
            BenchmarkHistoryRow(
                snapshot_date=row.date,
                benchmark_value=float(row.adjusted_close)
                if row.adjusted_close is not None
                else None,
            )
            for row in result.all()
        ]


def raise_problem(
    *,
    status_code: int,
    title: str,
    detail: str,
    instance: str,
    type_slug: str,
) -> None:
    raise AnalyticsProblem(
        status_code=status_code,
        title=title,
        detail=detail,
        instance=instance,
        type_slug=type_slug,
    )


def _risk_free_rate_from_env(default: float = 0.0) -> float:
    raw_value = os.getenv("ANALYTICS_RISK_FREE_RATE", os.getenv("RISK_FREE_RATE"))
    if raw_value is None:
        return default
    try:
        return float(raw_value)
    except ValueError:
        logger.warning("Invalid risk-free rate '%s'; defaulting to %.4f", raw_value, default)
        return default


def _sanitize_value(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: _sanitize_value(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_sanitize_value(item) for item in value]
    if isinstance(value, float):
        return value if math.isfinite(value) else None
    return value


def _json_default(value: Any) -> Any:
    if isinstance(value, (date, pd.Timestamp)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    raise TypeError(f"Object of type {type(value)!r} is not JSON serializable")


def _benchmark_type_from_env(default: BenchmarkType = BenchmarkType.TEDPIX) -> BenchmarkType:
    raw_value = os.getenv("ANALYTICS_BENCHMARK_TYPE")
    if raw_value is None:
        return default

    normalized = raw_value.strip().upper()
    try:
        return BenchmarkType(normalized)
    except ValueError:
        logger.warning(
            "Invalid benchmark type '%s'; defaulting to %s",
            raw_value,
            default.value,
        )
        return default


def _build_cache_key(
    *,
    namespace: str,
    portfolio_id: uuid.UUID,
    user_id: uuid.UUID,
    timeframe: str,
    version: str,
) -> str:
    digest = hashlib.sha256(
        f"{portfolio_id}:{user_id}:{timeframe}:{version}".encode("utf-8")
    ).hexdigest()
    return f"{ANALYTICS_CACHE_PREFIX}:{namespace}:{digest}"


def _portfolio_cache_version_key(portfolio_id: uuid.UUID) -> str:
    return f"{ANALYTICS_CACHE_PREFIX}:version:{portfolio_id}"


def _decode_cache_payload(raw_value: Any) -> str | None:
    if raw_value is None:
        return None
    if isinstance(raw_value, bytes):
        return raw_value.decode("utf-8")
    if isinstance(raw_value, str):
        return raw_value
    return None


def _get_cache_backend() -> Any | None:
    if FastAPICache is None:
        return None
    try:
        return FastAPICache.get_backend()
    except Exception:  # noqa: BLE001
        return None


async def _get_portfolio_cache_version(portfolio_id: uuid.UUID) -> str:
    backend = _get_cache_backend()
    if backend is None:
        return "0"

    try:
        raw_value = await backend.get(_portfolio_cache_version_key(portfolio_id))
        cached_version = _decode_cache_payload(raw_value)
        return cached_version or "0"
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Analytics cache version read failed for portfolio %s: %s",
            portfolio_id,
            exc,
        )
        return "0"


async def _cache_get_json(cache_key: str) -> dict[str, Any] | None:
    backend = _get_cache_backend()
    if backend is None:
        return None

    try:
        raw_value = await backend.get(cache_key)
        cached_payload = _decode_cache_payload(raw_value)
        if cached_payload:
            return json.loads(cached_payload)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Analytics cache read failed for key %s: %s", cache_key, exc)
    return None


async def _cache_set_json(
    cache_key: str,
    payload: dict[str, Any],
    ttl_seconds: int = ANALYTICS_CACHE_TTL_SECONDS,
) -> None:
    backend = _get_cache_backend()
    if backend is None:
        return

    serialized_payload = json.dumps(
        _sanitize_value(payload),
        default=_json_default,
        separators=(",", ":"),
    )

    try:
        await backend.set(cache_key, serialized_payload, expire=ttl_seconds)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Analytics cache write failed for key %s: %s", cache_key, exc)


async def invalidate_portfolio_analytics_cache(*, portfolio_id: uuid.UUID) -> None:
    """Invalidate analytics caches by bumping a per-portfolio cache version."""

    backend = _get_cache_backend()
    if backend is None:
        return

    version_key = _portfolio_cache_version_key(portfolio_id)
    try:
        current_raw = await backend.get(version_key)
        current_version = int(_decode_cache_payload(current_raw) or "0")
    except (TypeError, ValueError):
        current_version = 0
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Analytics cache version fetch failed for portfolio %s: %s",
            portfolio_id,
            exc,
        )
        current_version = 0

    try:
        await backend.set(
            version_key,
            str(current_version + 1),
            expire=ANALYTICS_CACHE_VERSION_TTL_SECONDS,
        )
        logger.info(
            "analytics_cache_invalidated",
            extra={
                "portfolio_id": str(portfolio_id),
                "cache_key": version_key,
                "old_version": current_version,
                "new_version": current_version + 1,
            },
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Analytics cache invalidation failed for portfolio %s: %s",
            portfolio_id,
            exc,
        )


class AnalyticsService:
    """Domain-oriented application service for portfolio performance analytics."""

    def __init__(
        self,
        *,
        repository: AnalyticsRepository,
        risk_free_rate: float | None = None,
        benchmark_type: BenchmarkType | None = None,
    ) -> None:
        self.repository = repository
        self.risk_free_rate = (
            float(risk_free_rate)
            if risk_free_rate is not None
            else _risk_free_rate_from_env()
        )
        self.benchmark_type = benchmark_type or _benchmark_type_from_env()

    async def get_performance_timeseries(
        self,
        *,
        portfolio_id: uuid.UUID | None,
        user_id: uuid.UUID,
        timeframe: Timeframe,
    ) -> dict[str, Any]:
        resolved_portfolio_id = await self._resolve_portfolio_id(
            portfolio_id=portfolio_id,
            user_id=user_id,
            instance="/api/v1/analytics/performance",
        )
        market_fields = await self.repository.fetch_latest_market_fields(
            portfolio_id=resolved_portfolio_id,
        )
        cache_version = await _get_portfolio_cache_version(resolved_portfolio_id)
        cache_key = _build_cache_key(
            namespace="performance",
            portfolio_id=resolved_portfolio_id,
            user_id=user_id,
            timeframe=timeframe,
            version=cache_version,
        )
        cached_payload = await _cache_get_json(cache_key)
        if cached_payload is not None:
            cached_payload.update(self._market_fields_payload(market_fields))
            return cached_payload

        portfolio, snapshot_rows = await self._load_snapshot_context(
            portfolio_id=resolved_portfolio_id,
            user_id=user_id,
            timeframe=timeframe,
            instance="/api/v1/analytics/performance",
        )
        if not snapshot_rows:
            payload = {
                "portfolio_id": str(resolved_portfolio_id),
                "timeframe": timeframe,
                "base_currency": str(portfolio.base_currency.value),
                **self._market_fields_payload(market_fields),
                "points": [],
            }
            await _cache_set_json(cache_key, payload)
            return payload
        try:
            payload = await run_in_threadpool(
                self._build_performance_payload,
                resolved_portfolio_id,
                timeframe,
                str(portfolio.base_currency.value),
                snapshot_rows,
                market_fields,
            )
        except ValueError:
            payload = {
                "portfolio_id": str(resolved_portfolio_id),
                "timeframe": timeframe,
                "base_currency": str(portfolio.base_currency.value),
                **self._market_fields_payload(market_fields),
                "points": [],
            }
        await _cache_set_json(cache_key, payload)
        return payload

    async def get_performance_metrics(
        self,
        *,
        portfolio_id: uuid.UUID | None,
        user_id: uuid.UUID,
        timeframe: Timeframe = "ALL",
    ) -> dict[str, Any]:
        resolved_portfolio_id = await self._resolve_portfolio_id(
            portfolio_id=portfolio_id,
            user_id=user_id,
            instance="/api/v1/analytics/metrics",
        )
        market_fields = await self.repository.fetch_latest_market_fields(
            portfolio_id=resolved_portfolio_id,
        )
        cache_version = await _get_portfolio_cache_version(resolved_portfolio_id)
        cache_key = _build_cache_key(
            namespace="metrics",
            portfolio_id=resolved_portfolio_id,
            user_id=user_id,
            timeframe=timeframe,
            version=cache_version,
        )
        cached_payload = await _cache_get_json(cache_key)
        if cached_payload is not None:
            cached_payload.update(self._market_fields_payload(market_fields))
            return cached_payload

        portfolio, snapshot_rows = await self._load_snapshot_context(
            portfolio_id=resolved_portfolio_id,
            user_id=user_id,
            timeframe=timeframe,
            instance="/api/v1/analytics/metrics",
        )
        if not snapshot_rows:
            payload = {
                "portfolio_id": str(resolved_portfolio_id),
                "timeframe": timeframe,
                "base_currency": str(portfolio.base_currency.value),
                "as_of_date": date.today().isoformat(),
                "portfolio_value": None,
                "cost_basis": None,
                **self._market_fields_payload(market_fields),
                "risk_free_rate": self.risk_free_rate,
                "pnl": None,
                "roi": None,
                "volatility": None,
                "sharpe_ratio": None,
                "risk_score": None,
                "risk_level": None,
                "risk_assessment": None,
            }
            await _cache_set_json(cache_key, payload)
            return payload
        benchmark_rows = await self.repository.fetch_benchmark_rows(
            benchmark_type=self.benchmark_type,
            start_date=snapshot_rows[0].snapshot_date,
            end_date=snapshot_rows[-1].snapshot_date,
        )

        try:
            payload = await run_in_threadpool(
                self._build_metrics_payload,
                resolved_portfolio_id,
                timeframe,
                str(portfolio.base_currency.value),
                snapshot_rows,
                benchmark_rows,
                self.risk_free_rate,
                market_fields,
            )
        except ValueError:
            payload = {
                "portfolio_id": str(resolved_portfolio_id),
                "timeframe": timeframe,
                "base_currency": str(portfolio.base_currency.value),
                "as_of_date": date.today().isoformat(),
                "portfolio_value": None,
                "cost_basis": None,
                **self._market_fields_payload(market_fields),
                "risk_free_rate": self.risk_free_rate,
                "pnl": None,
                "roi": None,
                "volatility": None,
                "sharpe_ratio": None,
                "risk_score": None,
                "risk_level": None,
                "risk_assessment": None,
            }
        await _cache_set_json(cache_key, payload)
        return payload

    @staticmethod
    def _market_fields_payload(market_fields: PortfolioMarketFields) -> dict[str, Any]:
        return {
            "current_price": market_fields.current_price,
            "closing_price": market_fields.closing_price,
            "daily_pnl": market_fields.daily_pnl,
            "total_unrealized_pnl": market_fields.total_unrealized_pnl,
            "last_market_update": (
                market_fields.last_market_update.isoformat()
                if market_fields.last_market_update is not None
                else None
            ),
        }

    async def _load_snapshot_context(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        timeframe: Timeframe,
        instance: str,
    ) -> tuple[Portfolio, list[PortfolioSnapshotRow]]:
        portfolio = await self.repository.get_portfolio_for_user(
            portfolio_id=portfolio_id,
            user_id=user_id,
        )
        if portfolio is None:
            raise_problem(
                status_code=404,
                title="Portfolio Not Found",
                detail="The requested portfolio does not exist or is not accessible.",
                instance=instance,
                type_slug="portfolio-not-found",
            )

        latest_snapshot_date = await self.repository.fetch_latest_snapshot_date(
            portfolio_id=portfolio_id,
        )
        if latest_snapshot_date is None:
            synthetic_row = await self.repository.fetch_position_based_snapshot_row(
                portfolio_id=portfolio_id,
            )
            if synthetic_row is not None:
                return portfolio, [synthetic_row]
            return portfolio, []

        start_date = self._resolve_timeframe_start(
            latest_snapshot_date=latest_snapshot_date,
            timeframe=timeframe,
        )
        snapshot_rows = await self.repository.fetch_snapshot_rows(
            portfolio_id=portfolio_id,
            start_date=start_date,
            end_date=latest_snapshot_date,
        )
        if not snapshot_rows:
            synthetic_row = await self.repository.fetch_position_based_snapshot_row(
                portfolio_id=portfolio_id,
            )
            if synthetic_row is not None:
                return portfolio, [synthetic_row]
        return portfolio, snapshot_rows

    async def _resolve_portfolio_id(
        self,
        *,
        portfolio_id: uuid.UUID | None,
        user_id: uuid.UUID,
        instance: str,
    ) -> uuid.UUID:
        if portfolio_id is not None:
            return portfolio_id

        default_portfolio = await self.repository.get_default_portfolio_for_user(
            user_id=user_id,
        )
        if default_portfolio is not None:
            return default_portfolio.id

        raise_problem(
            status_code=404,
            title="Portfolio Not Found",
            detail="No active portfolio is available for analytics.",
            instance=instance,
            type_slug="portfolio-not-found",
        )
        raise RuntimeError("unreachable")

    @staticmethod
    def _resolve_timeframe_start(
        *,
        latest_snapshot_date: date,
        timeframe: Timeframe,
    ) -> date | None:
        if timeframe == "ALL":
            return None

        latest_ts = pd.Timestamp(latest_snapshot_date)
        offsets: dict[Timeframe, pd.DateOffset] = {
            "1M": pd.DateOffset(months=1),
            "3M": pd.DateOffset(months=3),
            "6M": pd.DateOffset(months=6),
            "1Y": pd.DateOffset(years=1),
            "ALL": pd.DateOffset(days=0),
        }
        return (latest_ts - offsets[timeframe]).date()

    @staticmethod
    def _build_snapshot_frame(snapshot_rows: list[PortfolioSnapshotRow]) -> pd.DataFrame:
        if not snapshot_rows:
            raise ValueError("snapshot_rows must not be empty")

        frame = pd.DataFrame(
            {
                "snapshot_date": [row.snapshot_date for row in snapshot_rows],
                "market_value": [row.market_value for row in snapshot_rows],
                "cost_basis": [row.cost_basis for row in snapshot_rows],
                "pnl": [row.gain_loss for row in snapshot_rows],
                "roi": [row.gain_loss_pct for row in snapshot_rows],
            }
        )
        frame["snapshot_date"] = pd.to_datetime(frame["snapshot_date"])
        frame = (
            frame.sort_values("snapshot_date")
            .drop_duplicates(subset=["snapshot_date"], keep="last")
            .set_index("snapshot_date")
        )

        frame["market_value"] = pd.to_numeric(frame["market_value"], errors="coerce")
        frame["cost_basis"] = pd.to_numeric(frame["cost_basis"], errors="coerce")
        frame["pnl"] = pd.to_numeric(frame["pnl"], errors="coerce")
        frame["roi"] = pd.to_numeric(frame["roi"], errors="coerce")
        frame = frame.replace([np.inf, -np.inf], np.nan)

        # Keep API output stable even when partial snapshot fields are NULL in storage.
        frame["market_value"] = frame["market_value"].combine_first(frame["cost_basis"])
        frame = frame.dropna(how="all", subset=["market_value", "cost_basis"])
        if frame.empty:
            raise ValueError("snapshot_rows contain no finite market/cost values")

        full_index = pd.date_range(
            start=frame.index.min(),
            end=frame.index.max(),
            freq="D",
        )
        frame = frame.reindex(full_index).ffill()
        frame["pnl"] = frame["market_value"] - frame["cost_basis"]
        frame["roi"] = np.where(
            frame["cost_basis"] > 0,
            (frame["pnl"] / frame["cost_basis"]) * PERCENT_MULTIPLIER,
            np.nan,
        )
        frame = frame.replace([np.inf, -np.inf], np.nan)
        frame.index.name = "snapshot_date"
        return frame

    @staticmethod
    def _build_benchmark_series(
        benchmark_rows: list[BenchmarkHistoryRow],
    ) -> pd.Series:
        if not benchmark_rows:
            return pd.Series(dtype="float64", name="benchmark")

        frame = pd.DataFrame(
            {
                "snapshot_date": [row.snapshot_date for row in benchmark_rows],
                "benchmark_value": [row.benchmark_value for row in benchmark_rows],
            }
        )
        frame["snapshot_date"] = pd.to_datetime(frame["snapshot_date"])
        frame = (
            frame.sort_values("snapshot_date")
            .drop_duplicates(subset=["snapshot_date"], keep="last")
            .set_index("snapshot_date")
        )
        series = pd.to_numeric(frame["benchmark_value"], errors="coerce")
        return series.replace([np.inf, -np.inf], np.nan).dropna()

    @staticmethod
    def _build_log_return_series(frame: pd.DataFrame) -> pd.Series:
        market_values = pd.to_numeric(frame["market_value"], errors="coerce")
        previous_values = market_values.shift(1)
        valid_mask = (market_values > 0) & (previous_values > 0)

        log_returns = pd.Series(np.nan, index=market_values.index, dtype="float64")
        log_returns.loc[valid_mask] = np.log(
            market_values.loc[valid_mask] / previous_values.loc[valid_mask]
        )
        return log_returns.dropna()

    @staticmethod
    def _calculate_annualized_volatility(
        frame: pd.DataFrame,
    ) -> float | None:
        if len(frame.index) < 2:
            return None

        log_returns = AnalyticsService._build_log_return_series(frame)
        if log_returns.empty:
            return None

        daily_sigma = float(np.nanstd(log_returns.to_numpy(dtype=float), ddof=0))
        annualized_volatility = daily_sigma * math.sqrt(TRADING_DAYS_PER_YEAR)
        return annualized_volatility if math.isfinite(annualized_volatility) else None

    @staticmethod
    def _calculate_sharpe_ratio(
        frame: pd.DataFrame,
        *,
        annualized_volatility: float | None,
        risk_free_rate: float,
    ) -> float | None:
        if annualized_volatility is None:
            return None
        if annualized_volatility == 0 or not math.isfinite(annualized_volatility):
            return None

        log_returns = AnalyticsService._build_log_return_series(frame)
        if log_returns.empty:
            return None

        annualized_portfolio_return = float(log_returns.mean()) * TRADING_DAYS_PER_YEAR
        sharpe_ratio = (annualized_portfolio_return - risk_free_rate) / annualized_volatility
        return sharpe_ratio if math.isfinite(sharpe_ratio) else None

    @staticmethod
    def _build_performance_payload(
        portfolio_id: uuid.UUID,
        timeframe: Timeframe,
        base_currency: str,
        snapshot_rows: list[PortfolioSnapshotRow],
        market_fields: PortfolioMarketFields,
    ) -> dict[str, Any]:
        frame = AnalyticsService._build_snapshot_frame(snapshot_rows)
        payload_frame = frame.reset_index(names="date")
        payload_frame["date"] = payload_frame["date"].dt.date.astype(str)

        points = payload_frame.to_dict(orient="records")
        return _sanitize_value(
            {
                "portfolio_id": str(portfolio_id),
                "timeframe": timeframe,
                "base_currency": base_currency,
                **AnalyticsService._market_fields_payload(market_fields),
                "points": points,
            }
        )

    @staticmethod
    def _build_metrics_payload(
        portfolio_id: uuid.UUID,
        timeframe: Timeframe,
        base_currency: str,
        snapshot_rows: list[PortfolioSnapshotRow],
        benchmark_rows: list[BenchmarkHistoryRow],
        risk_free_rate: float,
        market_fields: PortfolioMarketFields,
    ) -> dict[str, Any]:
        frame = AnalyticsService._build_snapshot_frame(snapshot_rows)
        latest_row = frame.iloc[-1]
        benchmark_series = AnalyticsService._build_benchmark_series(benchmark_rows)

        annualized_volatility = AnalyticsService._calculate_annualized_volatility(
            frame,
        )
        sharpe_ratio = AnalyticsService._calculate_sharpe_ratio(
            frame,
            annualized_volatility=annualized_volatility,
            risk_free_rate=risk_free_rate,
        )
        risk_assessment = calculate_advanced_risk_metrics(
            portfolio_values=frame["market_value"],
            benchmark_values=benchmark_series,
            risk_free_rate=risk_free_rate,
            trading_days_per_year=TRADING_DAYS_PER_YEAR,
        )
        risk_score, risk_level = AnalyticsService._calculate_risk_score(
            annualized_volatility=annualized_volatility,
            risk_assessment=risk_assessment,
        )

        return _sanitize_value(
            {
                "portfolio_id": str(portfolio_id),
                "timeframe": timeframe,
                "base_currency": base_currency,
                "as_of_date": frame.index[-1].date().isoformat(),
                "portfolio_value": float(latest_row["market_value"]),
                "cost_basis": float(latest_row["cost_basis"]),
                **AnalyticsService._market_fields_payload(market_fields),
                "risk_free_rate": risk_free_rate,
                "pnl": float(latest_row["pnl"]),
                "roi": float(latest_row["roi"]),
                "volatility": annualized_volatility,
                "sharpe_ratio": sharpe_ratio,
                "risk_score": risk_score,
                "risk_level": risk_level,
                "risk_assessment": risk_assessment,
            }
        )

    @staticmethod
    def _calculate_risk_score(
        *,
        annualized_volatility: float | None,
        risk_assessment: dict[str, Any] | None,
    ) -> tuple[float | None, str | None]:
        if not isinstance(risk_assessment, dict):
            risk_assessment = {}

        components: list[tuple[float, float]] = []

        if annualized_volatility is not None and math.isfinite(annualized_volatility):
            volatility_pct = max(annualized_volatility, 0.0) * PERCENT_MULTIPLIER
            normalized_volatility = min(
                volatility_pct / RISK_SCORE_MAX_VOLATILITY_PERCENT,
                1.0,
            )
            components.append((normalized_volatility, 0.35))

        maximum_drawdown = risk_assessment.get("maximum_drawdown")
        if isinstance(maximum_drawdown, (float, int)) and math.isfinite(maximum_drawdown):
            normalized_drawdown = min(
                max(float(maximum_drawdown), 0.0) / RISK_SCORE_MAX_DRAWDOWN,
                1.0,
            )
            components.append((normalized_drawdown, 0.35))

        value_at_risk = risk_assessment.get("value_at_risk")
        if isinstance(value_at_risk, dict):
            historical = value_at_risk.get("historical")
            parametric = value_at_risk.get("parametric")
            var_candidates = [
                historical.get("confidence_99") if isinstance(historical, dict) else None,
                parametric.get("confidence_99") if isinstance(parametric, dict) else None,
            ]
            finite_var_values = [
                float(item)
                for item in var_candidates
                if isinstance(item, (float, int)) and math.isfinite(item)
            ]
            if finite_var_values:
                representative_var = max(max(finite_var_values), 0.0)
                normalized_var = min(representative_var / RISK_SCORE_MAX_VAR, 1.0)
                components.append((normalized_var, 0.2))

        beta = risk_assessment.get("beta")
        if isinstance(beta, (float, int)) and math.isfinite(beta):
            beta_distance = abs(float(beta) - 1.0)
            normalized_beta = min(beta_distance / RISK_SCORE_MAX_BETA_DISTANCE, 1.0)
            components.append((normalized_beta, 0.1))

        if not components:
            return None, None

        total_weight = sum(weight for _, weight in components)
        if total_weight <= 0:
            return None, None

        weighted_score = sum(value * weight for value, weight in components) / total_weight
        risk_score = round(weighted_score * PERCENT_MULTIPLIER, 2)
        risk_level = (
            "low" if risk_score < 34 else "medium" if risk_score < 67 else "high"
        )
        return risk_score, risk_level


def build_analytics_service(
    db: AsyncSession,
    redis_client: Any | None = None,
    *,
    risk_free_rate: float | None = None,
    benchmark_type: BenchmarkType | None = None,
) -> AnalyticsService:
    """Factory helper for dependency wiring in FastAPI deps/router layers."""

    # `redis_client` remains in the signature for backward-compatible DI wiring.
    _ = redis_client
    return AnalyticsService(
        repository=SQLAlchemyAnalyticsRepository(db),
        risk_free_rate=risk_free_rate,
        benchmark_type=benchmark_type,
    )
