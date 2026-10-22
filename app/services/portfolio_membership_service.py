"""Ensure portfolio-asset membership rows exist before persistence."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset_position import PortfolioAsset

ZERO = Decimal("0.00000000")


class PortfolioMembershipService:
    """Upsert service for PortfolioAsset membership rows."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def ensure_membership(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> PortfolioAsset:
        membership, _created = await self.ensure_membership_with_status(
            portfolio_id=portfolio_id,
            asset_id=asset_id,
        )
        return membership

    async def ensure_membership_with_status(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> tuple[PortfolioAsset, bool]:
        result = await self.db.execute(
            select(PortfolioAsset).where(
                PortfolioAsset.portfolio_id == portfolio_id,
                PortfolioAsset.asset_id == asset_id,
            ).with_for_update()
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            return existing, False

        created = PortfolioAsset(
            portfolio_id=portfolio_id,
            asset_id=asset_id,
            total_quantity=ZERO,
            weighted_avg_cost=ZERO,
            total_cost_basis=ZERO,
            cumulative_realized_pnl=ZERO,
            trade_count=0,
            last_updated=datetime.now(UTC).replace(tzinfo=None),
        )
        self.db.add(created)
        return created, True

    async def ensure_bulk_membership(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_ids: set[uuid.UUID],
    ) -> dict[uuid.UUID, PortfolioAsset]:
        memberships, _created_count = await self.ensure_bulk_membership_with_status(
            portfolio_id=portfolio_id,
            asset_ids=asset_ids,
        )
        return memberships

    async def ensure_bulk_membership_with_status(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_ids: set[uuid.UUID],
    ) -> tuple[dict[uuid.UUID, PortfolioAsset], int]:
        if not asset_ids:
            return {}, 0

        result = await self.db.execute(
            select(PortfolioAsset).where(
                PortfolioAsset.portfolio_id == portfolio_id,
                PortfolioAsset.asset_id.in_(asset_ids),
            ).with_for_update()
        )
        by_asset_id = {row.asset_id: row for row in result.scalars().all()}
        created_count = 0

        for asset_id in asset_ids:
            if asset_id in by_asset_id:
                continue
            created = PortfolioAsset(
                portfolio_id=portfolio_id,
                asset_id=asset_id,
                total_quantity=ZERO,
                weighted_avg_cost=ZERO,
                total_cost_basis=ZERO,
                cumulative_realized_pnl=ZERO,
                trade_count=0,
                last_updated=datetime.now(UTC).replace(tzinfo=None),
            )
            self.db.add(created)
            by_asset_id[asset_id] = created
            created_count += 1

        return by_asset_id, created_count
