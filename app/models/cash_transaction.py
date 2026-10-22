"""Immutable cash/non-trade ledger rows produced by broker imports."""

from __future__ import annotations

import uuid
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import TimestampMixin, UUIDMixin


class PortfolioCashTransaction(UUIDMixin, TimestampMixin, Base):
    """Immutable cash event row linked to an import batch/job."""

    __tablename__ = "portfolio_cash_transactions"
    __table_args__ = (
        UniqueConstraint("portfolio_id", "idempotency_key", name="uq_cash_txn_portfolio_idempotency"),
        UniqueConstraint("row_hash", name="uq_cash_txn_row_hash"),
        Index("ix_cash_txn_portfolio_date", "portfolio_id", "event_date"),
        CheckConstraint("source_row_number >= 0", name="ck_cash_txn_row_number_non_negative"),
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
    import_batch_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("import_jobs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    source_broker: Mapped[str] = mapped_column(String(32), nullable=False)
    source_row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    raw_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    normalized_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    event_date: Mapped[str] = mapped_column(String(32), nullable=False, index=True)

    raw_description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    normalized_description: Mapped[str] = mapped_column(Text, nullable=False, default="")

    amount: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    quantity: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    price_per_unit: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    gross_amount: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    fees: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    tax: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    net_amount: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False, default=Decimal("0.00000000"))
    fee_or_adjustment: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    cash_effect: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    debit_amount: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    credit_amount: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    balance_after: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)

    source_file_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    row_hash: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    diagnostics: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
