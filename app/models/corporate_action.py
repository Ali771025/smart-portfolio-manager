"""Corporate actions and their accounting execution ledger."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum as PGEnum,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import CorporateActionType
from app.models.mixins import TimestampMixin, UUIDMixin


class CorporateAction(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "corporate_actions"

    asset_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action_type: Mapped[CorporateActionType] = mapped_column(
        PGEnum(CorporateActionType, name="corporate_action_type_enum", create_type=True),
        nullable=False,
        index=True,
    )
    effective_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        index=True,
    )
    payload: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
    )

    __table_args__ = (
        Index("ix_corp_action_asset_date", "asset_id", "effective_date"),
    )


class DividendTransaction(UUIDMixin, TimestampMixin, Base):
    """
    Cash dividend accounting entry.

    Important accounting behavior:
    - Realized profit is recognized
    - Position quantity and WAC remain unchanged
    """

    __tablename__ = "dividend_transactions"

    __table_args__ = (
        UniqueConstraint("portfolio_id", "idempotency_key", name="uq_dividend_idempotency"),
        Index("ix_dividend_portfolio_asset", "portfolio_id", "asset_id"),
        Index("ix_dividend_effective_date", "effective_date"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )
    effective_date: Mapped[date] = mapped_column(Date, nullable=False)
    dps_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        comment="Dividend per share (DPS)",
    )
    holding_quantity: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        comment="Quantity held at the accounting cut-off",
    )
    total_dividend_profit: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        comment="holding_quantity * dps_amount",
    )
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)


class CorporateActionExecution(UUIDMixin, TimestampMixin, Base):
    """
    Immutable execution record for quantity-impacting corporate actions.

    This table is also used as idempotency sink to avoid re-applying a
    capital increase/rights issue when clients retry after network errors.
    """

    __tablename__ = "corporate_action_executions"

    __table_args__ = (
        UniqueConstraint("portfolio_id", "idempotency_key", name="uq_corp_action_idempotency"),
        Index("ix_corp_exec_portfolio_asset", "portfolio_id", "asset_id"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=False,
    )
    action_type: Mapped[CorporateActionType] = mapped_column(
        PGEnum(CorporateActionType, name="corporate_action_type_enum", create_type=False),
        nullable=False,
    )
    executed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
    )
    issue_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    issue_price: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    old_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    old_wac: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    new_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    new_wac: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
