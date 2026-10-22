"""Shared analytics repository for cross-service data access.

Provides unified access to:
  - Asset metadata and price history
  - Benchmark history
  - Portfolio positions and snapshots
  - Watchlist items and alerts

This repository eliminates duplicate data access patterns across
analytics services and ensures consistent data retrieval.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import BenchmarkType
from app.models.market_data import BenchmarkHistory, DailyPrice, PortfolioSnapshot
from app.models.portfolio import Portfolio
from app.models.watchlist import AlertRule, WatchlistItem

logger = logging.getLogger("analytics_repository")


@dataclass(slots=True, frozen=True)
class AssetMetadata:
    """Lightweight asset metadata."""
    asset_id: uuid.UUID
    ticker_symbol: str
    name_fa: str | None
    name_en: str | None
    exchange: str
    tsetmc_id: str | None
    is_active: bool


@dataclass(slots=True, frozen=True)
class PriceBar:
    """Single price bar for analytics."""
    date: date
    close_price: Decimal
    adjusted_close: Decimal
    volume: int


@dataclass(slots=True, frozen=True)
class BenchmarkBar:
    """Single benchmark price bar."""
    date: date
    close_price: Decimal
    adjusted_close: Decimal


@dataclass(slots=True, frozen=True)
class PortfolioPosition:
    """Portfolio position for holdings analysis."""
    asset_id: uuid.UUID
    ticker_symbol: str
    quantity: Decimal
    weighted_avg_cost: Decimal
    total_cost_basis: Decimal
    current_price: Decimal | None


class AnalyticsRepository:
    """Unified repository for analytics data access.

    This repository provides a single source of truth for reading
    market data, asset metadata, and portfolio positions.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ═══════════════════════════════════════════════════════════════
    # Asset Metadata
    # ═══════════════════════════════════════════════════════════════

    async def get_asset_metadata(
        self,
        asset_id: uuid.UUID,
    ) -> AssetMetadata | None:
        """Get lightweight asset metadata."""
        result = await self.db.execute(
            select(Asset).where(Asset.id == asset_id)
        )
        asset = result.scalar_one_or_none()
        if asset is None:
            return None

        return AssetMetadata(
            asset_id=asset.id,
            ticker_symbol=asset.ticker_symbol,
            name_fa=asset.name_fa,
            name_en=asset.name_en,
            exchange=asset.exchange,
            tsetmc_id=asset.tsetmc_id,
            is_active=asset.is_active,
        )

    async def get_asset_by_ticker(
        self,
        ticker_symbol: str,
    ) -> AssetMetadata | None:
        """Get asset metadata by ticker symbol."""
        result = await self.db.execute(
            select(Asset).where(Asset.ticker_symbol == ticker_symbol)
        )
        asset = result.scalar_one_or_none()
        if asset is None:
            return None

        return AssetMetadata(
            asset_id=asset.id,
            ticker_symbol=asset.ticker_symbol,
            name_fa=asset.name_fa,
            name_en=asset.name_en,
            exchange=asset.exchange,
            tsetmc_id=asset.tsetmc_id,
            is_active=asset.is_active,
        )

    # ═══════════════════════════════════════════════════════════════
    # Price History
    # ═══════════════════════════════════════════════════════════════

    async def get_price_history(
        self,
        asset_id: uuid.UUID,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        """Get price history for an asset."""
        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id == asset_id,
                DailyPrice.date >= start_date,
                DailyPrice.date <= end_date,
            )
            .order_by(DailyPrice.date.asc())
        )
        rows = result.scalars().all()

        return [
            PriceBar(
                date=row.date,
                close_price=row.close_price,
                adjusted_close=row.adjusted_close,
                volume=row.volume,
            )
            for row in rows
        ]

    async def get_multi_asset_price_history(
        self,
        asset_ids: list[uuid.UUID],
        start_date: date,
        end_date: date,
    ) -> dict[uuid.UUID, list[PriceBar]]:
        """Get price history for multiple assets."""
        if not asset_ids:
            return {}

        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id.in_(asset_ids),
                DailyPrice.date >= start_date,
                DailyPrice.date <= end_date,
            )
            .order_by(DailyPrice.asset_id.asc(), DailyPrice.date.asc())
        )
        rows = result.scalars().all()

        grouped: dict[uuid.UUID, list[PriceBar]] = {aid: [] for aid in asset_ids}
        for row in rows:
            grouped[row.asset_id].append(
                PriceBar(
                    date=row.date,
                    close_price=row.close_price,
                    adjusted_close=row.adjusted_close,
                    volume=row.volume,
                )
            )

        return grouped

    async def get_latest_price(
        self,
        asset_id: uuid.UUID,
        as_of_date: date,
    ) -> PriceBar | None:
        """Get the latest price for an asset."""
        result = await self.db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id == asset_id,
                DailyPrice.date <= as_of_date,
            )
            .order_by(DailyPrice.date.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row is None:
            return None

        return PriceBar(
            date=row.date,
            close_price=row.close_price,
            adjusted_close=row.adjusted_close,
            volume=row.volume,
        )

    async def get_asset_inception_date(
        self,
        asset_id: uuid.UUID,
    ) -> date | None:
        """Get the earliest price date for an asset."""
        result = await self.db.execute(
            select(DailyPrice.date)
            .where(DailyPrice.asset_id == asset_id)
            .order_by(DailyPrice.date.asc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════
    # Benchmark History
    # ═══════════════════════════════════════════════════════════════

    async def get_benchmark_history(
        self,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkBar]:
        """Get benchmark history."""
        result = await self.db.execute(
            select(BenchmarkHistory)
            .where(
                BenchmarkHistory.benchmark_type == benchmark_type,
                BenchmarkHistory.date >= start_date,
                BenchmarkHistory.date <= end_date,
            )
            .order_by(BenchmarkHistory.date.asc())
        )
        rows = result.scalars().all()

        return [
            BenchmarkBar(
                date=row.date,
                close_price=row.close_price,
                adjusted_close=row.adjusted_close,
            )
            for row in rows
        ]

    # ═══════════════════════════════════════════════════════════════
    # Portfolio Positions
    # ═══════════════════════════════════════════════════════════════

    async def get_portfolio_positions(
        self,
        portfolio_id: uuid.UUID,
    ) -> list[PortfolioPosition]:
        """Get portfolio positions for holdings analysis."""
        result = await self.db.execute(
            select(AssetPosition, Asset)
            .join(Asset, Asset.id == AssetPosition.asset_id)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.total_quantity > 0,
            )
        )
        rows = result.all()

        return [
            PortfolioPosition(
                asset_id=asset.id,
                ticker_symbol=asset.ticker_symbol,
                quantity=position.total_quantity,
                weighted_avg_cost=position.weighted_avg_cost,
                total_cost_basis=position.total_cost_basis,
                current_price=(
                    asset.last_trade_price
                    if asset.last_trade_price and asset.last_trade_price > 0
                    else asset.closing_price
                ),
            )
            for position, asset in rows
        ]

    async def get_user_watchlist_items(
        self,
        user_id: uuid.UUID,
    ) -> list[uuid.UUID]:
        """Get all asset IDs from user's watchlists."""
        result = await self.db.execute(
            select(WatchlistItem.asset_id)
            .join(AlertRule, AlertRule.watchlist_item_id == WatchlistItem.id)
            .where(AlertRule.user_id == user_id)
            .distinct()
        )
        return [row[0] for row in result.all()]

    # ═══════════════════════════════════════════════════════════════
    # Freshness Checks
    # ═══════════════════════════════════════════════════════════════

    async def get_latest_price_date(
        self,
        asset_id: uuid.UUID,
    ) -> date | None:
        """Get the most recent price date for an asset."""
        result = await self.db.execute(
            select(func.max(DailyPrice.date))
            .where(DailyPrice.asset_id == asset_id)
        )
        return result.scalar_one_or_none()

    async def is_data_fresh(
        self,
        asset_id: uuid.UUID,
        max_age_days: int = 2,
    ) -> bool:
        """Check if asset data is fresh enough for analytics."""
        latest_date = await self.get_latest_price_date(asset_id)
        if latest_date is None:
            return False
        age_days = (date.today() - latest_date).days
        return age_days <= max_age_days
