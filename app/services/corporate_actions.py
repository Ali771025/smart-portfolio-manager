"""Corporate action service implementing strict accounting and ACID semantics."""

from __future__ import annotations

import uuid
from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError, OperationalError

from app.models.corporate_action import CorporateActionExecution, DividendTransaction
from app.repositories.corporate_actions import CorporateActionRepository
from app.repositories.pnl import PnLRepository
from app.schemas.corporate_actions import CapitalIncreaseRequest, CashDividendRequest

FOUR_PLACES = Decimal("0.0001")
ZERO = Decimal("0.0000")


def q4(value: Decimal) -> Decimal:
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


class CorporateActionsService:
    """Application service for dividend and capital increase processing."""

    def __init__(self, repository: CorporateActionRepository, pnl_repo: PnLRepository) -> None:
        self.repository = repository
        self.pnl_repo = pnl_repo

    async def register_cash_dividend(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: CashDividendRequest,
        idempotency_key: str,
    ) -> DividendTransaction:
        """
        Register a DPS event with strict accounting semantics.

        Formula:
          Dividend Profit = Holding Quantity × DPS Amount

        Accounting constraints:
        - Realized profit increases
        - Quantity remains unchanged
        - WAC remains unchanged
        """

        portfolio = await self.pnl_repo.get_portfolio_for_user(portfolio_id=portfolio_id, user_id=user_id)
        if portfolio is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        existing = await self.repository.get_dividend_by_idempotency(
            portfolio_id=portfolio_id,
            idempotency_key=idempotency_key,
        )
        if existing is not None:
            return existing

        try:
            position = await self.repository.lock_position_nowait(
                portfolio_id=portfolio_id,
                asset_id=payload.asset_id,
            )
        except OperationalError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Position row is locked by another transaction. Please retry.",
            ) from exc

        if position is None or position.total_quantity <= ZERO:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot register dividend for an empty position",
            )

        total_profit = q4(position.total_quantity * q4(payload.dps_amount))

        dividend = DividendTransaction(
            portfolio_id=portfolio_id,
            asset_id=payload.asset_id,
            effective_date=payload.effective_date,
            dps_amount=q4(payload.dps_amount),
            holding_quantity=q4(position.total_quantity),
            total_dividend_profit=total_profit,
            idempotency_key=idempotency_key,
            notes=payload.notes,
        )

        # Dividend is realized profit but must not change quantity/WAC.
        position.cumulative_realized_pnl = q4(position.cumulative_realized_pnl + total_profit)

        try:
            await self.repository.add_dividend(dividend)
            await self.repository.commit()
        except IntegrityError:
            await self.repository.rollback()
            existing = await self.repository.get_dividend_by_idempotency(
                portfolio_id=portfolio_id,
                idempotency_key=idempotency_key,
            )
            if existing is not None:
                return existing
            raise

        await self.repository.refresh(dividend)
        return dividend

    async def apply_capital_increase(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        payload: CapitalIncreaseRequest,
        idempotency_key: str,
    ) -> CorporateActionExecution:
        """
        Apply rights/bonus shares while locking the position row pessimistically.

        Formula:
          New WAC = ((Old Quantity × Old WAC) + (New Quantity × Issue Price))
                    / (Old Quantity + New Quantity)

        This operation uses `SELECT ... FOR UPDATE NOWAIT` to prevent race
        conditions when concurrent corporate-action requests hit the same row.
        """

        portfolio = await self.pnl_repo.get_portfolio_for_user(portfolio_id=portfolio_id, user_id=user_id)
        if portfolio is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found")

        existing = await self.repository.get_execution_by_idempotency(
            portfolio_id=portfolio_id,
            idempotency_key=idempotency_key,
        )
        if existing is not None:
            return existing

        try:
            position = await self.repository.lock_position_nowait(
                portfolio_id=portfolio_id,
                asset_id=payload.asset_id,
            )
        except OperationalError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Position row is locked by another transaction. Please retry.",
            ) from exc

        if position is None:
            position = await self.repository.create_position_if_missing(
                portfolio_id=portfolio_id,
                asset_id=payload.asset_id,
            )

        issue_quantity = q4(Decimal(payload.issue_quantity))
        issue_price = q4(payload.issue_price)

        old_quantity = q4(position.total_quantity)
        old_wac = q4(position.weighted_avg_cost)

        new_quantity = q4(old_quantity + issue_quantity)
        numerator = q4((old_quantity * old_wac) + (issue_quantity * issue_price))
        new_wac = ZERO if new_quantity == ZERO else q4(numerator / new_quantity)

        position.total_quantity = new_quantity
        position.weighted_avg_cost = new_wac
        position.total_cost_basis = q4(new_quantity * new_wac)

        execution = CorporateActionExecution(
            portfolio_id=portfolio_id,
            asset_id=payload.asset_id,
            action_type=payload.action_type,
            issue_quantity=issue_quantity,
            issue_price=issue_price,
            old_quantity=old_quantity,
            old_wac=old_wac,
            new_quantity=new_quantity,
            new_wac=new_wac,
            idempotency_key=idempotency_key,
        )

        try:
            await self.repository.add_execution(execution)
            await self.repository.commit()
        except IntegrityError:
            await self.repository.rollback()
            existing = await self.repository.get_execution_by_idempotency(
                portfolio_id=portfolio_id,
                idempotency_key=idempotency_key,
            )
            if existing is not None:
                return existing
            raise

        await self.repository.refresh(execution)
        return execution
