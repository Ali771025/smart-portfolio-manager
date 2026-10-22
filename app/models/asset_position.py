"""
Asset position model with cumulative realized PnL tracking.
Updated atomically alongside every transaction for O(1) reads.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import NUMERIC, ForeignKey, Index, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin


class AssetPosition(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "asset_positions"

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )

    # Current holdings
    total_quantity: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
    )
    weighted_avg_cost: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
    )
    total_cost_basis: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
    )
    manual_break_even_price: Mapped[Decimal | None] = mapped_column(
        NUMERIC(24, 8),
        nullable=True,
        comment=(
            "User-entered break-even sell price for this portfolio asset, "
            "including the user's expected buy/sell fees when provided."
        ),
    )

    # ═══════════════════════════════════════════════════════════════
    # NEW: Cumulative Realized PnL for this specific position.
    # Running total of all realized_pnl from SELL transactions.
    # Allows O(1) per-asset PnL reads without scanning txn history.
    # ═══════════════════════════════════════════════════════════════
    cumulative_realized_pnl: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8),
        nullable=False,
        default=Decimal("0.00000000"),
        comment="Running total of realized PnL across all SELLs for this position.",
    )

    # Total number of executed trades (BUY + SELL) for this position
    trade_count: Mapped[int] = mapped_column(
        nullable=False,
        default=0,
        comment="Number of trades executed on this position.",
    )

    last_updated: Mapped[datetime] = mapped_column(
        nullable=False,
        default=datetime.utcnow,
    )

    __table_args__ = (
        UniqueConstraint("portfolio_id", "asset_id", name="uq_portfolio_asset"),
        Index("idx_portfolio_positions", "portfolio_id"),
        Index("idx_active_positions", "portfolio_id", "total_quantity"),
    )

    @property
    def current_quantity(self) -> Decimal:
        """Domain-friendly alias used by import membership language."""

        return self.total_quantity

    @current_quantity.setter
    def current_quantity(self, value: Decimal) -> None:
        self.total_quantity = value

    @property
    def average_cost(self) -> Decimal:
        """Domain-friendly alias used by import membership language."""

        return self.weighted_avg_cost

    @average_cost.setter
    def average_cost(self, value: Decimal) -> None:
        self.weighted_avg_cost = value


# Backward/forward compatible alias for Phase 2 terminology.
PortfolioAsset = AssetPosition
