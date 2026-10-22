"""Per-asset snapshot rows for broker holdings imports."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import Date, ForeignKey, Index, Numeric, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import TimestampMixin, UUIDMixin


class HoldingSnapshot(UUIDMixin, TimestampMixin, Base):
    """Point-in-time holdings row for one asset in one portfolio."""

    __tablename__ = "holding_snapshots"
    __table_args__ = (
        UniqueConstraint(
            "portfolio_id",
            "asset_id",
            "snapshot_date",
            name="uq_holding_snapshot_portfolio_asset_date",
        ),
        Index(
            "ix_holding_snapshot_portfolio_date",
            "portfolio_id",
            "snapshot_date",
        ),
        Index(
            "ix_holding_snapshot_portfolio_asset_date",
            "portfolio_id",
            "asset_id",
            "snapshot_date",
        ),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )
    snapshot_date: Mapped[date] = mapped_column(Date, nullable=False)
    quantity: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    average_cost: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    cost_basis: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    market_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    market_value: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    unrealized_pnl: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    weight_pct: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    source_metadata: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Optional source details (broker, import job id, row number).",
    )
