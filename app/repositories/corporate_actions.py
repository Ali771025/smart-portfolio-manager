"""Repository operations for corporate action accounting and idempotency."""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset_position import AssetPosition
from app.models.corporate_action import CorporateActionExecution, DividendTransaction


class CorporateActionRepository:
    """Persistence gateway used by CorporateActionsService."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_dividend_by_idempotency(
        self,
        *,
        portfolio_id: uuid.UUID,
        idempotency_key: str,
    ) -> DividendTransaction | None:
        result = await self.db.execute(
            select(DividendTransaction).where(
                DividendTransaction.portfolio_id == portfolio_id,
                DividendTransaction.idempotency_key == idempotency_key,
            )
        )
        return result.scalar_one_or_none()

    async def get_execution_by_idempotency(
        self,
        *,
        portfolio_id: uuid.UUID,
        idempotency_key: str,
    ) -> CorporateActionExecution | None:
        result = await self.db.execute(
            select(CorporateActionExecution).where(
                CorporateActionExecution.portfolio_id == portfolio_id,
                CorporateActionExecution.idempotency_key == idempotency_key,
            )
        )
        return result.scalar_one_or_none()

    async def lock_position_nowait(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> AssetPosition | None:
        """Lock portfolio-asset position row using SELECT .. FOR UPDATE NOWAIT."""

        result = await self.db.execute(
            select(AssetPosition)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset_id,
            )
            .with_for_update(nowait=True)
        )
        return result.scalar_one_or_none()

    async def create_position_if_missing(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> AssetPosition:
        position = AssetPosition(
            portfolio_id=portfolio_id,
            asset_id=asset_id,
            total_quantity=Decimal("0.0000"),
            weighted_avg_cost=Decimal("0.0000"),
            total_cost_basis=Decimal("0.0000"),
            cumulative_realized_pnl=Decimal("0.0000"),
            trade_count=0,
        )
        self.db.add(position)
        await self.db.flush()
        return position

    async def add_dividend(self, dividend: DividendTransaction) -> None:
        self.db.add(dividend)
        await self.db.flush()

    async def add_execution(self, execution: CorporateActionExecution) -> None:
        self.db.add(execution)
        await self.db.flush()

    async def commit(self) -> None:
        await self.db.commit()

    async def rollback(self) -> None:
        await self.db.rollback()

    async def refresh(self, entity: DividendTransaction | CorporateActionExecution) -> None:
        await self.db.refresh(entity)
