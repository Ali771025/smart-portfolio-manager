"""Phase 4 core domain models (Auth, Multi-Portfolio, Trade Ledger, Dashboard snapshots).

All monetary/financial quantities are mapped as NUMERIC(18,4) and represented as Decimal.
"""

from __future__ import annotations

import enum
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

MONEY_NUMERIC = Numeric(18, 4, asdecimal=True)


class PortfolioCurrency(str, enum.Enum):
    IRR = "IRR"
    USD = "USD"
    EUR = "EUR"


class TradeSide(str, enum.Enum):
    BUY = "BUY"
    SELL = "SELL"


class UUIDTimestampMixin:
    """Shared UUID primary key plus audit timestamps."""

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        sort_order=-100,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        sort_order=9000,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        sort_order=9001,
    )


class SoftDeleteMixin:
    """Logical deletion for recoverability and audit retention."""

    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class User(UUIDTimestampMixin, Base):
    """Authentication principal and ownership root aggregate."""

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("char_length(trim(full_name)) > 0", name="ck_users_full_name_not_blank"),
        Index("uq_users_email_lower", text("lower(email)"), unique=True),
    )

    email: Mapped[str] = mapped_column(String(320), nullable=False)
    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Argon2 hash only; plaintext passwords are never persisted.",
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    portfolios: Mapped[list["Portfolio"]] = relationship(
        back_populates="owner",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="noload",
    )
    trades: Mapped[list["TradeLedger"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="noload",
    )


class RefreshToken(UUIDTimestampMixin, Base):
    """Persisted refresh-token sessions for rotation, revocation, and device tracking."""

    __tablename__ = "refresh_tokens"
    __table_args__ = (
        Index("ix_refresh_tokens_user_revoked", "user_id", "revoked_at"),
        Index("ix_refresh_tokens_expires_at", "expires_at"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_jti: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        nullable=False,
        unique=True,
        default=uuid.uuid4,
    )
    token_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="SHA-256 (or stronger) hash of refresh token for safe storage.",
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    user_agent: Mapped[str | None] = mapped_column(String(512))
    ip_address: Mapped[str | None] = mapped_column(String(64))

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class Portfolio(UUIDTimestampMixin, SoftDeleteMixin, Base):
    """User-owned portfolio aggregate with native multi-portfolio support."""

    __tablename__ = "portfolios"
    __table_args__ = (
        CheckConstraint("char_length(trim(name)) > 0", name="ck_portfolios_name_not_blank"),
        # Allows reusing a name after soft-delete while preventing duplicates among active portfolios.
        Index(
            "uq_portfolios_user_name_active",
            "user_id",
            text("lower(name)"),
            unique=True,
            postgresql_where=text("is_deleted = false"),
        ),
        # Guarantees at most one active default portfolio per user.
        Index(
            "uq_portfolios_user_default_active",
            "user_id",
            unique=True,
            postgresql_where=text("is_deleted = false AND is_default = true"),
        ),
        Index("ix_portfolios_user_deleted", "user_id", "is_deleted"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    base_currency: Mapped[PortfolioCurrency] = mapped_column(
        SAEnum(PortfolioCurrency, name="phase4_portfolio_currency_enum"),
        nullable=False,
        default=PortfolioCurrency.IRR,
    )
    is_default: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("false"),
    )

    owner: Mapped[User] = relationship(back_populates="portfolios")
    trades: Mapped[list["TradeLedger"]] = relationship(
        back_populates="portfolio",
        cascade="all, delete-orphan",
        lazy="noload",
        order_by="TradeLedger.executed_at.desc()",
    )
    daily_snapshots: Mapped[list["PortfolioDailySnapshot"]] = relationship(
        back_populates="portfolio",
        cascade="all, delete-orphan",
        lazy="noload",
        order_by="PortfolioDailySnapshot.snapshot_date.desc()",
    )


class TradeLedger(UUIDTimestampMixin, Base):
    """Immutable trade ledger entries used for inventory replay and PnL."""

    __tablename__ = "trade_ledger"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_trade_ledger_quantity_positive"),
        CheckConstraint("price > 0", name="ck_trade_ledger_price_positive"),
        CheckConstraint("fees >= 0", name="ck_trade_ledger_fees_non_negative"),
        CheckConstraint("gross_amount > 0", name="ck_trade_ledger_gross_positive"),
        UniqueConstraint("portfolio_id", "idempotency_key", name="uq_trade_ledger_portfolio_idempotency"),
        Index("ix_trade_ledger_portfolio_time", "portfolio_id", "executed_at"),
        Index("ix_trade_ledger_user_time", "user_id", "executed_at"),
        Index("ix_trade_ledger_symbol_time", "symbol", "executed_at"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    side: Mapped[TradeSide] = mapped_column(
        SAEnum(TradeSide, name="phase4_trade_side_enum"),
        nullable=False,
    )
    symbol: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        comment="Normalized ticker symbol (Latin and Persian symbols supported).",
    )
    asset_name: Mapped[str | None] = mapped_column(String(255))

    quantity: Mapped[Decimal] = mapped_column(MONEY_NUMERIC, nullable=False)
    price: Mapped[Decimal] = mapped_column(MONEY_NUMERIC, nullable=False)
    fees: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0"),
    )
    gross_amount: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        comment="Materialized quantity * price for deterministic reporting.",
    )
    realized_pnl: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0"),
        comment="Populated for SELL trades after cost-basis matching.",
    )

    executed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    idempotency_key: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
        comment="Client-generated dedupe key for exactly-once trade submission.",
    )
    external_order_id: Mapped[str | None] = mapped_column(String(128), index=True)
    notes: Mapped[str | None] = mapped_column(Text)

    portfolio: Mapped[Portfolio] = relationship(back_populates="trades")
    user: Mapped[User] = relationship(back_populates="trades")


class PortfolioDailySnapshot(UUIDTimestampMixin, Base):
    """End-of-day valuation series for growth charts, risk, and Sharpe approximations."""

    __tablename__ = "portfolio_daily_snapshots"
    __table_args__ = (
        CheckConstraint("total_value >= 0", name="ck_snapshot_total_value_non_negative"),
        CheckConstraint("invested_capital >= 0", name="ck_snapshot_invested_non_negative"),
        UniqueConstraint("portfolio_id", "snapshot_date", name="uq_portfolio_daily_snapshot"),
        Index("ix_portfolio_daily_snapshot_portfolio_date", "portfolio_id", "snapshot_date"),
    )

    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    snapshot_date: Mapped[date] = mapped_column(Date, nullable=False)
    total_value: Mapped[Decimal] = mapped_column(MONEY_NUMERIC, nullable=False)
    invested_capital: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0"),
    )
    total_unrealized_pnl: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0"),
    )
    total_realized_pnl: Mapped[Decimal] = mapped_column(
        MONEY_NUMERIC,
        nullable=False,
        default=Decimal("0.0000"),
        server_default=text("0"),
    )

    portfolio: Mapped[Portfolio] = relationship(back_populates="daily_snapshots")
