"""CQRS read-side repository for low-latency analytics queries."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

import sqlalchemy as sa
from sqlalchemy import exc as sa_exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.portfolio import Portfolio


@dataclass(slots=True, frozen=True)
class PortfolioRollupRow:
    bucket_start: datetime
    close_market_value: Decimal
    close_cost_basis: Decimal
    realized_pnl_cumulative: Decimal
    close_unrealized_pnl: Decimal


@dataclass(slots=True, frozen=True)
class PortfolioRiskSnapshotRow:
    snapshot_at: datetime
    max_drawdown: Decimal | None
    sharpe_ratio: Decimal | None


@dataclass(slots=True, frozen=True)
class OhlcvRow:
    bucket_start: datetime
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    close_price: Decimal
    total_volume: int
    total_notional: Decimal


@dataclass(slots=True, frozen=True)
class AssetMetadataRow:
    asset_id: uuid.UUID
    ticker_symbol: str
    name_en: str | None


class AnalyticsReadRepository:
    """Read-model repository backed by TimescaleDB hypertables/CAGGs."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    @staticmethod
    def _is_missing_relation_error(exc: Exception, relation_name: str) -> bool:
        message = str(exc).lower()
        return (
            "undefinedtableerror" in message
            or f'relation "{relation_name.lower()}" does not exist' in message
        )

    async def get_portfolio_currency_for_user(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> str | None:
        result = await self.db.execute(
            sa.select(Portfolio.base_currency)
            .where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
            .limit(1)
        )
        currency = result.scalar_one_or_none()
        return currency.value if currency is not None else None

    async def fetch_portfolio_rollup_rows(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_at: datetime,
        end_at: datetime,
        limit: int,
    ) -> list[PortfolioRollupRow]:
        stmt = sa.text(
            """
            SELECT
                bucket_start,
                close_market_value,
                close_cost_basis,
                realized_pnl_cumulative,
                close_unrealized_pnl
            FROM portfolio_pnl_daily_rollup
            WHERE portfolio_id = :portfolio_id
              AND bucket_start >= :start_at
              AND bucket_start <= :end_at
            ORDER BY bucket_start ASC
            LIMIT :limit
            """
        )
        try:
            result = await self.db.execute(
                stmt,
                {
                    "portfolio_id": portfolio_id,
                    "start_at": start_at,
                    "end_at": end_at,
                    "limit": limit,
                },
            )
        except sa_exc.ProgrammingError as exc:
            if self._is_missing_relation_error(exc, "portfolio_pnl_daily_rollup"):
                return []
            raise

        rows: list[PortfolioRollupRow] = []
        for row in result.mappings().all():
            rows.append(
                PortfolioRollupRow(
                    bucket_start=row["bucket_start"],
                    close_market_value=row["close_market_value"] or Decimal("0"),
                    close_cost_basis=row["close_cost_basis"] or Decimal("0"),
                    realized_pnl_cumulative=row["realized_pnl_cumulative"] or Decimal("0"),
                    close_unrealized_pnl=row["close_unrealized_pnl"] or Decimal("0"),
                )
            )
        return rows

    async def fetch_latest_risk_snapshot(
        self,
        *,
        portfolio_id: uuid.UUID,
        end_at: datetime,
    ) -> PortfolioRiskSnapshotRow | None:
        stmt = sa.text(
            """
            SELECT snapshot_at, max_drawdown, sharpe_ratio
            FROM portfolio_analytics_snapshots
            WHERE portfolio_id = :portfolio_id
              AND snapshot_at <= :end_at
            ORDER BY snapshot_at DESC
            LIMIT 1
            """
        )
        try:
            result = await self.db.execute(
                stmt,
                {
                    "portfolio_id": portfolio_id,
                    "end_at": end_at,
                },
            )
        except sa_exc.ProgrammingError as exc:
            if self._is_missing_relation_error(exc, "portfolio_analytics_snapshots"):
                return None
            raise
        row = result.mappings().first()
        if row is None:
            return None

        return PortfolioRiskSnapshotRow(
            snapshot_at=row["snapshot_at"],
            max_drawdown=row["max_drawdown"],
            sharpe_ratio=row["sharpe_ratio"],
        )

    async def fetch_asset_ohlcv_rows(
        self,
        *,
        asset_id: uuid.UUID,
        start_at: datetime,
        end_at: datetime,
        limit: int,
    ) -> list[OhlcvRow]:
        stmt = sa.text(
            """
            SELECT
                bucket_start,
                open_price,
                high_price,
                low_price,
                close_price,
                total_volume,
                total_notional
            FROM market_ticks_1m_ohlcv
            WHERE asset_id = :asset_id
              AND bucket_start >= :start_at
              AND bucket_start <= :end_at
            ORDER BY bucket_start ASC
            LIMIT :limit
            """
        )
        try:
            result = await self.db.execute(
                stmt,
                {
                    "asset_id": asset_id,
                    "start_at": start_at,
                    "end_at": end_at,
                    "limit": limit,
                },
            )
        except sa_exc.ProgrammingError as exc:
            if self._is_missing_relation_error(exc, "market_ticks_1m_ohlcv"):
                return []
            raise

        rows: list[OhlcvRow] = []
        for row in result.mappings().all():
            rows.append(
                OhlcvRow(
                    bucket_start=row["bucket_start"],
                    open_price=row["open_price"] or Decimal("0"),
                    high_price=row["high_price"] or Decimal("0"),
                    low_price=row["low_price"] or Decimal("0"),
                    close_price=row["close_price"] or Decimal("0"),
                    total_volume=int(row["total_volume"] or 0),
                    total_notional=row["total_notional"] or Decimal("0"),
                )
            )
        return rows

    async def fetch_asset_metadata(self, *, asset_id: uuid.UUID) -> AssetMetadataRow | None:
        result = await self.db.execute(
            sa.select(Asset.id, Asset.ticker_symbol, Asset.name_en)
            .where(Asset.id == asset_id, Asset.is_active.is_(True))
            .limit(1)
        )
        row = result.first()
        if row is None:
            return None

        return AssetMetadataRow(
            asset_id=row.id,
            ticker_symbol=row.ticker_symbol,
            name_en=row.name_en,
        )
