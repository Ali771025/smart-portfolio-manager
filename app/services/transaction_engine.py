"""
High-performance transaction engine with:
- ACID guarantees via atomic DB transactions
- Pessimistic locking (SELECT ... FOR UPDATE)
- WAC (Weighted Average Cost) calculation
- Realized PnL tracking on every SELL
- Idempotency protection

Fee Handling Rules (Tehran Stock Market):
  BUY  → Trade Value = (Quantity × Price) + Fees
         Fees increase acquisition cost
         WAC = (old_quantity × old_wac + trade_value) / new_quantity

  SELL → Trade Value = (Quantity × Price) - Fees
         Fees decrease net proceeds
         Realized PnL = proceeds - (quantity × old_wac) - fees

Tehran Stock Market Constraints:
  - Quantities must be positive integers (whole shares)
  - No short selling: sell quantity cannot exceed current holdings
  - Price per unit must be positive
  - Fees must be non-negative

All monetary calculations use Decimal for precision.
"""

import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import logging

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis
from app.models.transaction import Transaction
from app.models.asset_position import AssetPosition
from app.models.enums import TransactionType
from app.schemas.transaction import TransactionCreate
from app.services.advanced_benchmark_service import invalidate_portfolio_benchmark_cache
from app.services.analytics_service import invalidate_portfolio_analytics_cache

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════
# Financial precision constant: all Decimal values quantized to 4 places
# ═══════════════════════════════════════════════════════════════════════
FOUR_PLACES = Decimal("0.0001")


def _q(value: Decimal) -> Decimal:
    """Quantize a Decimal to 4 decimal places with banker's rounding."""
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


async def execute_trade(
    db: AsyncSession,
    portfolio_id: uuid.UUID,
    trade: TransactionCreate,
    idempotency_key: str,
) -> Transaction:
    """
    Execute a trade with full ACID guarantees.

    Pipeline:
        1. Idempotency gate
        2. Pessimistic lock on AssetPosition
        3. Trade value calculation
        4. WAC update (BUY) or Realized PnL calculation (SELL)
        5. Atomic persist (Transaction + AssetPosition)
        6. Commit

    Returns:
        The persisted Transaction ORM instance.
    """
    if trade.transaction_type not in {TransactionType.BUY, TransactionType.SELL}:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="execute_trade supports only BUY and SELL transaction types",
        )

    # ═══════════════════════════════════════════════════════════════
    # STEP 1: Idempotency Gate
    # ═══════════════════════════════════════════════════════════════
    # Check if a transaction with this idempotency key already exists
    # for this portfolio. If so, return the cached result immediately.

    existing = await db.execute(
        select(Transaction).where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.idempotency_key == idempotency_key,
        )
    )
    cached_txn = existing.scalar_one_or_none()
    if cached_txn:
        return cached_txn

    # ═══════════════════════════════════════════════════════════════
    # STEP 2: Acquire Pessimistic Lock on AssetPosition
    # ═══════════════════════════════════════════════════════════════
    # SELECT ... FOR UPDATE ensures no other concurrent transaction
    # can read or modify this row until we commit or rollback.
    # This prevents race conditions like double-spending.

    result = await db.execute(
        select(AssetPosition)
        .where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.asset_id == trade.asset_id,
        )
        .with_for_update()  # 🔒 Row-level pessimistic lock
    )
    position = result.scalar_one_or_none()

    # If no position exists yet, initialize with zeros
    if not position:
        position = AssetPosition(
            portfolio_id=portfolio_id,
            asset_id=trade.asset_id,
            total_quantity=Decimal("0.0000"),
            weighted_avg_cost=Decimal("0.0000"),
            total_cost_basis=Decimal("0.0000"),
            cumulative_realized_pnl=Decimal("0.0000"),
            trade_count=0,
        )
        db.add(position)
        # Flush to obtain the row lock for the newly created position
        await db.flush()

    # ═══════════════════════════════════════════════════════════════
    # STEP 3: Sanitize and Quantize Inputs
    # ═══════════════════════════════════════════════════════════════

    quantity = _q(trade.quantity)
    price    = _q(trade.price_per_unit)
    fees     = _q(trade.fees)

    # ═══════════════════════════════════════════════════════════════
    # STEP 4: Calculate Trade Value
    # ═══════════════════════════════════════════════════════════════
    #   BUY  → Trade Value = (Quantity × Price) + Fees
    #   SELL → Trade Value = (Quantity × Price) - Fees

    if trade.transaction_type == TransactionType.BUY:
        trade_value = _q(quantity * price + fees)
    else:
        trade_value = _q(quantity * price - fees)

    # ═══════════════════════════════════════════════════════════════
    # STEP 5: Snapshot current position state BEFORE mutation
    # ═══════════════════════════════════════════════════════════════
    # This snapshot is critical for:
    #   - Realized PnL formula (uses old_wac)
    #   - Audit trail (wac_at_execution)

    old_quantity: Decimal = position.total_quantity
    old_wac: Decimal      = position.weighted_avg_cost

    # ═══════════════════════════════════════════════════════════════
    # STEP 6: Apply Position Logic + Realized PnL
    # ═══════════════════════════════════════════════════════════════

    realized_pnl = Decimal("0.0000")  # Default for BUY

    if trade.transaction_type == TransactionType.BUY:
        # ─────────────────────────────────────────────────────────
        # BUY LOGIC
        # ─────────────────────────────────────────────────────────
        #
        # New Quantity = Old Quantity + Buy Quantity
        #
        #              (Old Quantity × Old WAC) + Trade Value
        # New WAC    = ──────────────────────────────────────────
        #                        New Quantity
        #
        # Realized PnL = 0 (no profit/loss on buying)
        # ─────────────────────────────────────────────────────────

        new_quantity = _q(old_quantity + quantity)

        if new_quantity > 0:
            numerator = _q(old_quantity * old_wac) + trade_value
            new_wac = _q(numerator / new_quantity)
        else:
            new_wac = Decimal("0.0000")

        position.total_quantity    = new_quantity
        position.weighted_avg_cost = new_wac
        position.total_cost_basis  = _q(new_quantity * new_wac)

    else:
        # ─────────────────────────────────────────────────────────
        # SELL LOGIC (with Realized PnL)
        # ─────────────────────────────────────────────────────────
        #
        # BUSINESS RULE: Cannot sell more than current holdings.
        # ─────────────────────────────────────────────────────────

        if quantity > old_quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Insufficient balance. "
                    f"Available: {old_quantity}, Requested: {quantity}"
                ),
            )

        # ─────────────────────────────────────────────────────────
        # REALIZED PnL CALCULATION
        # ─────────────────────────────────────────────────────────
        # Must be computed BEFORE the WAC Reset Rule is applied,
        # because the formula depends on old_wac.
        #
        # Formula:
        #   Realized PnL = (Sell Qty × Sell Price) 
        #                 - (Sell Qty × Old WAC) 
        #                 - Sell Fees
        #
        # Interpretation:
        #   Revenue from sale  = Sell Qty × Sell Price
        #   Cost of sold units = Sell Qty × Old WAC
        #   Net profit         = Revenue - Cost - Fees
        # ─────────────────────────────────────────────────────────

        revenue       = _q(quantity * price)     # What we received
        cost_of_sold  = _q(quantity * old_wac)   # What those units cost us
        realized_pnl  = _q(revenue - cost_of_sold - fees)

        # ─────────────────────────────────────────────────────────
        # UPDATE QUANTITY
        # ─────────────────────────────────────────────────────────

        new_quantity = _q(old_quantity - quantity)

        # ─────────────────────────────────────────────────────────
        # WAC RESET RULE
        # ─────────────────────────────────────────────────────────
        # If position is fully liquidated (quantity == 0), reset
        # WAC to 0. Otherwise, WAC is UNCHANGED on SELL.
        # This is standard WAC accounting: selling does not alter
        # the average cost of remaining shares.
        # ─────────────────────────────────────────────────────────

        if new_quantity == Decimal("0.0000"):
            new_wac = Decimal("0.0000")
        else:
            new_wac = old_wac  # SELL never changes WAC

        position.total_quantity    = new_quantity
        position.weighted_avg_cost = new_wac
        position.total_cost_basis  = _q(new_quantity * new_wac)

        # ─────────────────────────────────────────────────────────
        # ACCUMULATE REALIZED PnL INTO POSITION
        # ─────────────────────────────────────────────────────────
        # Running total enables O(1) per-asset PnL reads
        # without scanning transaction history.
        # ─────────────────────────────────────────────────────────

        position.cumulative_realized_pnl = _q(
            position.cumulative_realized_pnl + realized_pnl
        )

    # ═══════════════════════════════════════════════════════════════
    # STEP 7: Update position metadata
    # ═══════════════════════════════════════════════════════════════

    position.trade_count += 1
    position.last_updated = datetime.utcnow()

    # ═══════════════════════════════════════════════════════════════
    # STEP 8: Create Transaction Record
    # ═══════════════════════════════════════════════════════════════
    # The Transaction is the immutable audit record.
    # It captures the realized_pnl and the WAC snapshot for
    # forensic and reconciliation purposes.

    # Determine currency from portfolio (default to IRR for Tehran market)
    currency = "IRR"  # Tehran Stock Exchange uses Iranian Rial

    transaction = Transaction(
        portfolio_id=portfolio_id,
        asset_id=trade.asset_id,
        transaction_type=trade.transaction_type,
        quantity=quantity,
        price_per_unit=price,
        fees=fees,
        total_amount=trade_value,
        currency=currency,
        realized_pnl=realized_pnl,          # ← PnL for this trade
        wac_at_execution=old_wac,            # ← WAC audit snapshot
        executed_at=trade.executed_at,
        notes=trade.notes,
        reference_hash=hashlib.sha256(
            f"{portfolio_id}|{idempotency_key}".encode("utf-8")
        ).hexdigest(),
        idempotency_key=idempotency_key,
    )
    db.add(transaction)

    # ═══════════════════════════════════════════════════════════════
    # STEP 9: Atomic Commit
    # ═══════════════════════════════════════════════════════════════
    # Both the Transaction INSERT and AssetPosition UPDATE are
    # committed in a single database transaction — ACID guaranteed.
    # If anything fails, everything rolls back.

    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        logger.warning(
            "Trade commit failed due to integrity constraint",
            extra={
                "portfolio_id": str(portfolio_id),
                "asset_id": str(trade.asset_id),
                "idempotency_key": idempotency_key,
                "exception_message": str(exc.orig),
            },
        )
        existing_after_conflict = await db.execute(
            select(Transaction).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.idempotency_key == idempotency_key,
            )
        )
        existing_txn = existing_after_conflict.scalar_one_or_none()
        if existing_txn:
            logger.info(
                "Recovered existing transaction after commit conflict",
                extra={
                    "portfolio_id": str(portfolio_id),
                    "idempotency_key": idempotency_key,
                    "transaction_id": str(existing_txn.id),
                },
            )
            return existing_txn

        message = "Trade violates database integrity constraints."
        status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
        conflict_text = str(exc.orig).lower()
        if "reference_hash" in conflict_text or "unique" in conflict_text:
            message = "Duplicate transaction detected and rejected by the ledger."
            status_code = status.HTTP_409_CONFLICT
        raise HTTPException(status_code=status_code, detail=message) from exc

    await db.refresh(transaction)
    try:
        await invalidate_portfolio_analytics_cache(portfolio_id=portfolio_id)
        await invalidate_portfolio_benchmark_cache(
            portfolio_id=portfolio_id,
            redis_client=get_redis(),
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "Cache invalidation failed after trade commit for portfolio %s: %s",
            portfolio_id,
            exc,
        )

    return transaction
