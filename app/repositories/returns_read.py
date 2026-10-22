"""Read-side repository for historical returns computation.

Provides efficient queries for:
  - Asset price history (single and multi-asset)
  - Benchmark history for comparison
  - Date range queries with gap handling
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.enums import BenchmarkType
from app.models.market_data import BenchmarkHistory, DailyPrice

logger = logging.getLogger("returns_repository")


@dataclass(slots=True, frozen=True)
class PriceRow:
    """Lightweight price row for returns computation."""
    asset_id: uuid.UUID
    date: date
    close_price: Decimal
    adjusted_close: Decimal
    volume: int


@dataclass(slots=True, frozen=True)
class BenchmarkPriceRow:
    """Lightweight benchmark row for returns computation."""
    benchmark_type: BenchmarkType
    date: date
    close_price: Decimal
    adjusted_close: Decimal


class ReturnsReadRepository:
    """Repository for reading price data for returns computation."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_asset_info(
        self,
        asset_id: uuid.UUID,
    ) -> Asset | None:
        """Get asset metadata."""
        result = await self.db.execute(
            select(Asset).where(Asset.id == asset_id)
        )
        return result.scalar_one_or_none()

    async def get_asset_by_ticker(
        self,
        ticker_symbol: str,
    ) -> Asset | None:
        """Get asset by ticker symbol."""
        result = await self.db.execute(
            select(Asset).where(Asset.ticker_symbol == ticker_symbol)
        )
        return result.scalar_one_or_none()

    async def get_price_history(
        self,
        asset_id: uuid.UUID,
        start_date: date,
        end_date: date,
        *,
        use_adjusted: bool = True,
    ) -> list[PriceRow]:
        """Fetch price history for a single asset.

        Args:
            asset_id: Asset UUID.
            start_date: Start of date range (inclusive).
            end_date: End of date range (inclusive).
            use_adjusted: If True, use adjusted_close for returns.

        Returns:
            List of PriceRow sorted by date ascending.
        """
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
            PriceRow(
                asset_id=row.asset_id,
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
        *,
        use_adjusted: bool = True,
    ) -> dict[uuid.UUID, list[PriceRow]]:
        """Fetch price history for multiple assets.

        Returns:
            Dict mapping asset_id to list of PriceRow.
        """
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

        grouped: dict[uuid.UUID, list[PriceRow]] = {aid: [] for aid in asset_ids}
        for row in rows:
            grouped[row.asset_id].append(
                PriceRow(
                    asset_id=row.asset_id,
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
    ) -> PriceRow | None:
        """Get the latest price for an asset up to as_of_date."""
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

        return PriceRow(
            asset_id=row.asset_id,
            date=row.date,
            close_price=row.close_price,
            adjusted_close=row.adjusted_close,
            volume=row.volume,
        )

    async def get_benchmark_history(
        self,
        benchmark_type: BenchmarkType,
        start_date: date,
        end_date: date,
    ) -> list[BenchmarkPriceRow]:
        """Fetch benchmark history for returns computation."""
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
            BenchmarkPriceRow(
                benchmark_type=row.benchmark_type,
                date=row.date,
                close_price=row.close_price,
                adjusted_close=row.adjusted_close,
            )
            for row in rows
        ]

    async def get_asset_inception_date(
        self,
        asset_id: uuid.UUID,
    ) -> date | None:
        """Get the earliest price date for an asset (inception date)."""
        result = await self.db.execute(
            select(DailyPrice.date)
            .where(DailyPrice.asset_id == asset_id)
            .order_by(DailyPrice.date.asc())
            .limit(1)
        )
        return result.scalar_one_or_none()
