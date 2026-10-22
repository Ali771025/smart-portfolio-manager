"""Cross-portfolio trade reconciliation persistence models.

Imported transactions remain the immutable source ledger. These tables record
user-approved quantity attribution and its audited accounting projection.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum as PGEnum,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.enums import (
    ReconciliationAuditAction,
    ReconciliationMatchingMethod,
    ReconciliationStatus,
)
from app.models.mixins import TimestampMixin, UUIDMixin


class TradeReconciliation(UUIDMixin, TimestampMixin, Base):
    """One sell-side reconciliation case with one or more buy allocations."""

    __tablename__ = "trade_reconciliations"
    __table_args__ = (
        CheckConstraint(
            "confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)",
            name="ck_trade_reconciliation_confidence_range",
        ),
        Index("ix_trade_reconciliation_user_status", "user_id", "status"),
        Index("ix_trade_reconciliation_user_asset", "user_id", "asset_id"),
        Index("ix_trade_reconciliation_sell_status", "sell_transaction_id", "status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="RESTRICT"),
        nullable=False,
    )
    sell_transaction_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="RESTRICT"),
        nullable=False,
    )
    destination_portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="RESTRICT"),
        nullable=False,
    )
    status: Mapped[ReconciliationStatus] = mapped_column(
        PGEnum(
            ReconciliationStatus,
            name="trade_reconciliation_status_enum",
            create_type=True,
        ),
        nullable=False,
        default=ReconciliationStatus.SUGGESTED,
        server_default=ReconciliationStatus.SUGGESTED.value,
    )
    matching_method: Mapped[ReconciliationMatchingMethod] = mapped_column(
        PGEnum(
            ReconciliationMatchingMethod,
            name="trade_reconciliation_method_enum",
            create_type=True,
        ),
        nullable=False,
    )
    confidence_score: Mapped[Decimal | None] = mapped_column(Numeric(5, 4), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    rationale: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    updated_by_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    confirmed_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=True
    )
    rejected_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=True
    )
    canceled_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=True
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    canceled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    allocations: Mapped[list["TradeReconciliationAllocation"]] = relationship(
        back_populates="reconciliation",
        lazy="selectin",
        cascade="all, delete-orphan",
        order_by="TradeReconciliationAllocation.created_at.asc()",
    )
    audit_events: Mapped[list["TradeReconciliationAuditEvent"]] = relationship(
        back_populates="reconciliation",
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="TradeReconciliationAuditEvent.created_at.asc()",
    )


class TradeReconciliationAllocation(UUIDMixin, TimestampMixin, Base):
    """Partial quantity link from one buy transaction to a reconciliation sell."""

    __tablename__ = "trade_reconciliation_allocations"
    __table_args__ = (
        UniqueConstraint(
            "reconciliation_id",
            "buy_transaction_id",
            name="uq_trade_reconciliation_allocation_buy",
        ),
        CheckConstraint("matched_quantity > 0", name="ck_reconciliation_allocation_quantity_positive"),
        CheckConstraint(
            "allocated_buy_cost IS NULL OR allocated_buy_cost >= 0",
            name="ck_reconciliation_allocation_buy_cost_non_negative",
        ),
        CheckConstraint(
            "allocated_sell_proceeds IS NULL OR allocated_sell_proceeds >= 0",
            name="ck_reconciliation_allocation_sell_proceeds_non_negative",
        ),
        Index("ix_reconciliation_allocation_buy", "buy_transaction_id"),
        Index("ix_reconciliation_allocation_source", "source_portfolio_id", "buy_transaction_id"),
    )

    reconciliation_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("trade_reconciliations.id", ondelete="CASCADE"),
        nullable=False,
    )
    buy_transaction_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("transactions.id", ondelete="RESTRICT"),
        nullable=False,
    )
    source_portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="RESTRICT"),
        nullable=False,
    )
    matched_quantity: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    allocated_buy_cost: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    allocated_sell_proceeds: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    realized_pnl: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)

    reconciliation: Mapped[TradeReconciliation] = relationship(back_populates="allocations")


class TradeReconciliationAuditEvent(UUIDMixin, Base):
    """Append-only status and allocation audit record."""

    __tablename__ = "trade_reconciliation_audit_events"
    __table_args__ = (
        Index("ix_reconciliation_audit_case_time", "reconciliation_id", "created_at"),
        Index("ix_reconciliation_audit_actor", "actor_user_id", "created_at"),
    )

    reconciliation_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("trade_reconciliations.id", ondelete="CASCADE"),
        nullable=False,
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    action: Mapped[ReconciliationAuditAction] = mapped_column(
        PGEnum(
            ReconciliationAuditAction,
            name="trade_reconciliation_audit_action_enum",
            create_type=True,
        ),
        nullable=False,
    )
    reason: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    event_metadata: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
    )

    reconciliation: Mapped[TradeReconciliation] = relationship(back_populates="audit_events")
