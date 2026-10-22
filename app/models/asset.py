"""
Asset model with live market price fields.
current_price is updated by the background sync engine
and cached in Redis for sub-millisecond dashboard reads.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    NUMERIC,
    String,
    Boolean,
    DateTime,
    UniqueConstraint,
    Index,
    CheckConstraint,
    Integer,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDMixin, TimestampMixin
from app.models.enums import AssetType

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.transaction import Transaction
    from app.models.market_data import DailyPrice
    from app.models.corporate_action import DividendTransaction, CorporateActionExecution


class Asset(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "assets"

    ticker_symbol: Mapped[str] = mapped_column(
        String(50), nullable=False,
    )
    normalized_symbol: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="Canonical symbol used for import-time idempotent resolution.",
    )
    name_fa: Mapped[str] = mapped_column(
        String(255), nullable=False, comment="Persian name from TSETMC",
    )
    name_en: Mapped[str | None] = mapped_column(
        String(255), nullable=True,
    )
    asset_type: Mapped[AssetType] = mapped_column(
        nullable=False, default=AssetType.STOCK,
    )
    exchange: Mapped[str] = mapped_column(
        String(50), nullable=False, default="TSETMC",
    )
    isin: Mapped[str | None] = mapped_column(
        String(30), nullable=True, comment="ISIN code from TSETMC",
    )
    tsetmc_id: Mapped[str | None] = mapped_column(
        String(50), nullable=True, index=True,
        comment="Unique instrument ID on TSETMC (e.g., ins_code)",
    )
    display_metadata: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Optional UI-facing metadata (sector, logo, aliases, etc).",
    )

    # ═══════════════════════════════════════════════════════════════
    # LIVE MARKET DATA — Updated by background sync engine
    # ═══════════════════════════════════════════════════════════════

    current_price: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
        comment="Backward-compatible valuation price; synchronized to closing_price",
    )
    last_trade_price: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
        comment="Latest Last Price / pDrCotVal from TSETMC",
    )
    closing_price: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
        comment="Latest Closing Price / pClosing from TSETMC",
    )
    previous_close_price: Mapped[Decimal] = mapped_column(
        NUMERIC(24, 8), nullable=False, default=Decimal("0.00000000"),
        comment="Previous day close — used for sanity checks",
    )
    price_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="Timestamp of last successful price update",
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True,
    )
    is_tradeable: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True,
        comment="False if halted or suspended on TSETMC",
    )
    version_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
    )

    __table_args__ = (
        UniqueConstraint(
            "ticker_symbol", "exchange",
            name="uq_asset_ticker_exchange",
        ),
        CheckConstraint(
            "current_price >= 0",
            name="ck_asset_current_price_non_negative",
        ),
        CheckConstraint(
            "last_trade_price >= 0",
            name="ck_asset_last_trade_price_non_negative",
        ),
        CheckConstraint(
            "closing_price >= 0",
            name="ck_asset_closing_price_non_negative",
        ),
        Index("idx_asset_tsetmc_id", "tsetmc_id"),
        Index("idx_asset_active", "is_active", "exchange"),
    )

    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="asset",
        lazy="noload",
    )
    price_history: Mapped[list["DailyPrice"]] = relationship(
        back_populates="asset",
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="DailyPrice.date.desc()",
    )
    dividend_transactions: Mapped[list["DividendTransaction"]] = relationship(
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="DividendTransaction.effective_date.desc()",
    )
    corporate_action_executions: Mapped[list["CorporateActionExecution"]] = relationship(
        lazy="noload",
        cascade="all, delete-orphan",
        order_by="CorporateActionExecution.executed_at.desc()",
    )

    __mapper_args__ = {"version_id_col": version_id}

    @property
    def symbol(self) -> str:
        """Domain alias for import workflows that use `symbol` terminology."""

        return self.ticker_symbol

    @property
    def last_price(self) -> Decimal:
        """Market Engine alias for TSETMC Last Price."""

        return self.last_trade_price

    @property
    def price_change(self) -> Decimal:
        """Absolute change from the previous persisted close."""

        return self.closing_price - self.previous_close_price

    @property
    def price_change_percent(self) -> Decimal:
        """Percentage change from the previous persisted close."""

        if self.previous_close_price <= 0:
            return Decimal("0")
        return (self.price_change / self.previous_close_price) * Decimal("100")

    @property
    def last_updated_at(self) -> datetime | None:
        """Market Engine alias for the price update timestamp."""

        return self.price_updated_at
