"""Core domain models for the advanced analytics engine.

This module separates write-side immutable ledger events from read-side
high-frequency time-series tables prepared for TimescaleDB hypertables.
All monetary values are Decimal-backed NUMERIC columns.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    Enum as PGEnum,
    ForeignKey,
    Index,
    Numeric,
    PrimaryKeyConstraint,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.enums import InventoryAccountingMethod, LedgerEventType
from app.models.mixins import TimestampMixin, UUIDMixin

if TYPE_CHECKING:
    from app.models.asset import Asset
    from app.models.portfolio import Portfolio


class LedgerEventRecord(UUIDMixin, TimestampMixin, Base):
    """Immutable write-side event ledger with strict idempotency guarantees."""

    __tablename__ = "ledger_events"

    __table_args__ = (
        UniqueConstraint(
            "portfolio_id",
            "idempotency_key",
            name="uq_ledger_events_portfolio_idempotency",
        ),
        UniqueConstraint("event_hash", name="uq_ledger_events_event_hash"),
        Index("ix_ledger_events_portfolio_time", "portfolio_id", "event_time"),
        Index("ix_ledger_events_asset_time", "asset_id", "event_time"),
        CheckConstraint("quantity >= 0", name="ck_ledger_events_quantity_non_negative"),
        CheckConstraint("price >= 0", name="ck_ledger_events_price_non_negative"),
        CheckConstraint("fees >= 0", name="ck_ledger_events_fees_non_negative"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )

    event_type: Mapped[LedgerEventType] = mapped_column(
        PGEnum(LedgerEventType, name="ledger_event_type_enum", create_type=True),
        nullable=False,
        index=True,
    )
    inventory_method: Mapped[InventoryAccountingMethod] = mapped_column(
        PGEnum(
            InventoryAccountingMethod,
            name="inventory_accounting_method_enum",
            create_type=True,
        ),
        nullable=False,
        default=InventoryAccountingMethod.WAC,
    )

    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(28, 10), nullable=False, default=Decimal("0"))
    price: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))
    fees: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))
    gross_amount: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))
    net_amount: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))
    realized_pnl: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))

    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    event_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Deterministic SHA-256 payload digest for replay-safe ingestion.",
    )
    payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    portfolio: Mapped["Portfolio"] = relationship(lazy="noload")
    asset: Mapped["Asset | None"] = relationship(lazy="noload")


class MarketTick(Base):
    """High-throughput tick table intended to become a TimescaleDB hypertable."""

    __tablename__ = "market_ticks"

    __table_args__ = (
        PrimaryKeyConstraint(
            "asset_id",
            "tick_time",
            "sequence_no",
            name="pk_market_ticks",
        ),
        Index("ix_market_ticks_asset_time", "asset_id", "tick_time"),
        Index("ix_market_ticks_time", "tick_time"),
        CheckConstraint("price >= 0", name="ck_market_ticks_price_non_negative"),
        CheckConstraint("volume >= 0", name="ck_market_ticks_volume_non_negative"),
        CheckConstraint("sequence_no >= 0", name="ck_market_ticks_sequence_non_negative"),
    )

    asset_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )
    tick_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    sequence_no: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        default=0,
        comment="Monotonic sequence from upstream feed to break same-timestamp ties.",
    )

    price: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    notional: Mapped[Decimal] = mapped_column(
        Numeric(28, 8),
        nullable=False,
        default=Decimal("0"),
        comment="price * volume materialized for rollups.",
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="UNKNOWN")
    ingest_idempotency_key: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    asset: Mapped["Asset"] = relationship(lazy="noload")


class PortfolioAnalyticsSnapshot(UUIDMixin, TimestampMixin, Base):
    """Read-side point-in-time portfolio metrics for real-time and historical analytics."""

    __tablename__ = "portfolio_analytics_snapshots"

    __table_args__ = (
        UniqueConstraint(
            "portfolio_id",
            "snapshot_at",
            name="uq_portfolio_analytics_snapshot_time",
        ),
        Index("ix_portfolio_analytics_portfolio_time", "portfolio_id", "snapshot_at"),
        CheckConstraint(
            "total_market_value >= 0",
            name="ck_portfolio_analytics_total_market_value_non_negative",
        ),
        CheckConstraint(
            "total_cost_basis >= 0",
            name="ck_portfolio_analytics_total_cost_basis_non_negative",
        ),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    snapshot_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)

    total_market_value: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    total_cost_basis: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    unrealized_pnl: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))
    realized_pnl_cumulative: Mapped[Decimal] = mapped_column(
        Numeric(24, 8),
        nullable=False,
        default=Decimal("0"),
    )
    realized_pnl_delta: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0"))

    twr: Mapped[Decimal | None] = mapped_column(Numeric(18, 10), nullable=True)
    mwr: Mapped[Decimal | None] = mapped_column(Numeric(18, 10), nullable=True)
    max_drawdown: Mapped[Decimal | None] = mapped_column(Numeric(18, 10), nullable=True)
    sharpe_ratio: Mapped[Decimal | None] = mapped_column(Numeric(18, 10), nullable=True)

    metrics_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    portfolio: Mapped["Portfolio"] = relationship(lazy="noload")
