"""Manual transaction ledger for trades and corporate actions."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    CheckConstraint,
    Date,
    Enum as PGEnum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import TransactionType
from app.models.mixins import AuditTrailMixin, UUIDMixin


class ManualTransaction(UUIDMixin, AuditTrailMixin, Base):
    """
    Unified write-side ledger entry for manual trade + corporate action commands.

    Corporate action-specific fields are encoded in `event_metadata` (JSONB).
    """

    __tablename__ = "manual_transactions"

    __table_args__ = (
        UniqueConstraint(
            "created_by_user_id",
            "idempotency_key",
            name="uq_manual_txn_user_idempotency",
        ),
        UniqueConstraint(
            "created_by_user_id",
            "idempotency_fingerprint",
            name="uq_manual_txn_user_fingerprint",
        ),
        Index("ix_manual_txn_portfolio_date", "portfolio_id", "transaction_date"),
        Index("ix_manual_txn_symbol_date", "symbol", "transaction_date"),
        CheckConstraint("quantity > 0", name="ck_manual_txn_quantity_positive"),
        CheckConstraint(
            "(price IS NULL) OR (price >= 0)",
            name="ck_manual_txn_price_non_negative",
        ),
        CheckConstraint("commission >= 0", name="ck_manual_txn_commission_non_negative"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    symbol: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    transaction_type: Mapped[TransactionType] = mapped_column(
        PGEnum(
            TransactionType,
            name="manual_transaction_type_enum",
            create_type=True,
        ),
        nullable=False,
        index=True,
    )
    transaction_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    quantity: Mapped[Decimal] = mapped_column(
        Numeric(24, 8),
        nullable=False,
    )
    price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8),
        nullable=True,
        comment="Nullable for cash dividend payloads where price is not applicable.",
    )
    commission: Mapped[Decimal] = mapped_column(
        Numeric(24, 8),
        nullable=False,
        default=Decimal("0.00000000"),
        server_default="0",
    )
    total_value: Mapped[Decimal] = mapped_column(
        Numeric(24, 8),
        nullable=False,
    )

    event_metadata: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )
    idempotency_key: Mapped[str] = mapped_column(String(128), nullable=False)
    idempotency_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    version_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default="1",
    )
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    __mapper_args__ = {"version_id_col": version_id}

