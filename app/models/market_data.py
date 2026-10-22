"""
Market data: historical OHLCV prices and portfolio valuation snapshots.

• AssetPriceHistory: one row per asset per trading day.
• PortfolioSnapshot: nightly batch-computed portfolio valuation.
"""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger, Numeric, Date, DateTime, ForeignKey,
    UniqueConstraint, Index, Enum as PGEnum, String, CheckConstraint, Integer, text,
    Boolean, Text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.enums import BenchmarkType
from app.models.mixins import UUIDMixin, TimestampMixin

from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.models.asset import Asset
    from app.models.portfolio import Portfolio


class DailyPrice(UUIDMixin, TimestampMixin, Base):
    """
    Daily OHLCV price bar for a given asset.

    The composite unique constraint (asset_id, date) prevents duplicate
    entries.  A covering index accelerates the common query:
       "Get the latest close for asset X."
    """
    __tablename__ = "daily_prices"

    __table_args__ = (
        UniqueConstraint(
            "asset_id", "date",
            name="uq_daily_price_asset_date",
        ),
        UniqueConstraint(
            "instrument_id", "date",
            name="uq_daily_price_instrument_date",
        ),
        Index("ix_daily_price_asset_date_desc", "asset_id", "date"),
        Index("ix_daily_price_asset_time_desc", "asset_id", "price_time"),
        Index("ix_daily_price_instrument_date_desc", "instrument_id", "date"),
        CheckConstraint("open_price >= 0", name="ck_daily_price_open_non_negative"),
        CheckConstraint("high_price >= 0", name="ck_daily_price_high_non_negative"),
        CheckConstraint("low_price >= 0", name="ck_daily_price_low_non_negative"),
        CheckConstraint("close_price >= 0", name="ck_daily_price_close_non_negative"),
        CheckConstraint("last_trade_price >= 0", name="ck_daily_price_last_trade_non_negative"),
        CheckConstraint("adjusted_close >= 0", name="ck_daily_price_adjusted_non_negative"),
        CheckConstraint("volume >= 0", name="ck_daily_price_volume_non_negative"),
    )

    # ── Foreign Keys ─────────────────────────────────────
    asset_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("assets.id", ondelete="CASCADE"),
        nullable=True,
    )
    instrument_id: Mapped[str | None] = mapped_column(String(64), nullable=True)

    # ── OHLCV (ALL NUMERIC — NO FLOATS EVER) ────────────
    price_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="TimescaleDB hypertable time dimension.",
    )
    date: Mapped[date] = mapped_column(
        Date, nullable=False,
    )
    open_price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8), nullable=True,
    )
    high_price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8), nullable=True,
    )
    low_price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8), nullable=True,
    )
    close_price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8), nullable=True,
    )
    last_trade_price: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8),
        nullable=True,
        comment="TSETMC Last Price / pDrCotVal for this trading day",
    )
    yesterday_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    adjusted_close: Mapped[Decimal | None] = mapped_column(
        Numeric(24, 8), nullable=True,
        comment="Split/dividend-adjusted close price",
    )
    adjustment_factor: Mapped[Decimal] = mapped_column(
        Numeric(24, 8),
        nullable=False,
        default=Decimal("1.00000000"),
        comment="Adjusted price = close_price * adjustment_factor",
    )
    volume: Mapped[int] = mapped_column(
        BigInteger, nullable=False, default=0,
    )
    value: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    trade_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="UNKNOWN")
    version_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        server_default=text("1"),
    )

    # ── Relationships ────────────────────────────────────
    asset: Mapped["Asset | None"] = relationship(back_populates="price_history")

    def __repr__(self) -> str:
        return f"<DailyPrice {self.asset_id} {self.date} close={self.close_price}>"

    def get_price(self, use_adjusted: bool) -> Decimal:
        """
        Return adjusted or unadjusted close according to charting mode.

        Iranian market frontends typically need both:
        - Unadjusted for raw tape replay
        - Adjusted for corporate-action-safe trend analysis
        """

        return self.adjusted_close if use_adjusted else self.close_price

    @property
    def last_price(self) -> Decimal:
        """Market Engine alias for the latest price in this daily bar."""

        return self.last_trade_price

    @property
    def closing_price(self) -> Decimal:
        """Canonical closing price alias for schemas that use market terms."""

        return self.close_price

    @property
    def price_change(self) -> Decimal | None:
        """Daily bars do not carry previous-close context by themselves."""

        return None

    @property
    def price_change_percent(self) -> Decimal | None:
        """Daily bars do not carry previous-close context by themselves."""

        return None

    @property
    def last_updated_at(self) -> datetime:
        """Timestamp associated with this market data row."""

        return self.price_time

    __mapper_args__ = {"version_id_col": version_id}


class BenchmarkHistory(UUIDMixin, TimestampMixin, Base):
    """
    Daily OHLCV bar for a benchmark series (Gold 18k, USD/IRR, TEDPIX).
    """

    __tablename__ = "benchmark_history"

    __table_args__ = (
        UniqueConstraint(
            "benchmark_type", "date",
            name="uq_benchmark_type_date",
        ),
        Index("ix_benchmark_type_date", "benchmark_type", "date"),
    )

    benchmark_type: Mapped[BenchmarkType] = mapped_column(
        PGEnum(BenchmarkType, name="benchmark_type_enum", create_type=True),
        nullable=False,
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    open_price: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    high_price: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    low_price: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    close_price: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        comment="Raw (unadjusted) close for benchmark",
    )
    adjusted_close: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        comment="Adjusted close for benchmark chart continuity",
    )
    adjustment_factor: Mapped[Decimal] = mapped_column(
        Numeric(18, 4),
        nullable=False,
        default=Decimal("1.0000"),
    )
    volume: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="UNKNOWN")

    def get_price(self, use_adjusted: bool) -> Decimal:
        return self.adjusted_close if use_adjusted else self.close_price


class Instrument(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "instruments"
    __table_args__ = (
        UniqueConstraint("instrument_id", name="uq_instruments_instrument_id"),
        UniqueConstraint("ins_code", name="uq_instruments_ins_code"),
        Index("ix_instruments_symbol", "symbol"),
        Index("ix_instruments_active_market", "is_active", "market"),
    )

    ins_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    instrument_id: Mapped[str] = mapped_column(String(64), nullable=False)
    isin: Mapped[str | None] = mapped_column(String(32), nullable=True)
    symbol: Mapped[str] = mapped_column(String(64), nullable=False)
    company_name: Mapped[str | None] = mapped_column(String(512), nullable=True)
    market: Mapped[str | None] = mapped_column(String(64), nullable=True)
    board: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sector_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    sector_name: Mapped[str | None] = mapped_column(String(256), nullable=True)
    instrument_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class MarketQuote(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "market_quotes"
    __table_args__ = (
        UniqueConstraint("instrument_id", "event_time", name="uq_market_quote_instrument_event"),
        Index("ix_market_quote_instrument_event_desc", "instrument_id", "event_time"),
        Index("ix_market_quote_symbol_event_desc", "symbol", "event_time"),
        CheckConstraint("closing_price IS NULL OR closing_price >= 0", name="ck_market_quote_closing_non_negative"),
        CheckConstraint("last_price IS NULL OR last_price >= 0", name="ck_market_quote_last_non_negative"),
        CheckConstraint("volume >= 0", name="ck_market_quote_volume_non_negative"),
        CheckConstraint("value IS NULL OR value >= 0", name="ck_market_quote_value_non_negative"),
        CheckConstraint("trade_count >= 0", name="ck_market_quote_trade_count_non_negative"),
    )

    instrument_id: Mapped[str] = mapped_column(String(64), nullable=False)
    symbol: Mapped[str] = mapped_column(String(64), nullable=False)
    trade_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    first_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    last_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    closing_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    yesterday_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    high_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    low_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    trade_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    value: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    buy_count: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    sell_count: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    status: Mapped[str | None] = mapped_column(String(64), nullable=True)
    received_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="TSETMC")


class ClientType(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "client_types"
    __table_args__ = (
        UniqueConstraint("instrument_id", "trade_date", name="uq_client_type_instrument_date"),
        Index("ix_client_type_instrument_date", "instrument_id", "trade_date"),
    )

    instrument_id: Mapped[str] = mapped_column(String(64), nullable=False)
    trade_date: Mapped[date] = mapped_column(Date, nullable=False)
    individual_buy_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    individual_buy_volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    individual_sell_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    individual_sell_volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    legal_buy_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    legal_buy_volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    legal_sell_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    legal_sell_volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)


class OrderBook(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "order_book"
    __table_args__ = (
        UniqueConstraint("instrument_id", "event_time", "level", name="uq_order_book_instrument_event_level"),
        Index("ix_order_book_instrument_event", "instrument_id", "event_time"),
    )

    instrument_id: Mapped[str] = mapped_column(String(64), nullable=False)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    level: Mapped[int] = mapped_column(Integer, nullable=False)
    buy_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    buy_volume: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    buy_count: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    sell_price: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    sell_volume: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    sell_count: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class MarketIndex(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "market_indices"
    __table_args__ = (
        UniqueConstraint("index_code", "event_time", name="uq_market_index_code_event"),
        Index("ix_market_index_code_event_desc", "index_code", "event_time"),
    )

    index_code: Mapped[str] = mapped_column(String(64), nullable=False)
    name: Mapped[str] = mapped_column(String(256), nullable=False)
    value: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    change: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    change_percent: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="TSETMC")


class MarketOverview(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "market_overviews"
    __table_args__ = (
        UniqueConstraint(
            "source",
            "price_info_timestamp",
            name="uq_market_overview_source_timestamp",
        ),
        Index(
            "ix_market_overview_price_info_desc",
            "price_info_timestamp",
        ),
        CheckConstraint("total_index_value >= 0", name="ck_market_overview_total_index_non_negative"),
        CheckConstraint(
            "equal_weight_index_value >= 0",
            name="ck_market_overview_equal_weight_non_negative",
        ),
        CheckConstraint("market_value IS NULL OR market_value >= 0", name="ck_market_overview_value_non_negative"),
        CheckConstraint("trades_count >= 0", name="ck_market_overview_trades_count_non_negative"),
        CheckConstraint("trades_value IS NULL OR trades_value >= 0", name="ck_market_overview_trades_value_non_negative"),
        CheckConstraint("trades_volume >= 0", name="ck_market_overview_trades_volume_non_negative"),
    )

    total_index_value: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    total_index_change: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    equal_weight_index_value: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    equal_weight_index_change: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    market_value: Mapped[Decimal | None] = mapped_column(Numeric(32, 8), nullable=True)
    trades_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    trades_value: Mapped[Decimal | None] = mapped_column(Numeric(32, 8), nullable=True)
    trades_volume: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    price_info_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    server_received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="TSETMC")


class Disclosure(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "disclosures"
    __table_args__ = (
        UniqueConstraint("tracking_number", name="uq_disclosure_tracking_number"),
        Index("ix_disclosure_symbol_published", "symbol", "published_at"),
    )

    tracking_number: Mapped[str] = mapped_column(String(128), nullable=False)
    symbol: Mapped[str] = mapped_column(String(64), nullable=False)
    company_name: Mapped[str | None] = mapped_column(String(512), nullable=True)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    letter_code: Mapped[str | None] = mapped_column(String(128), nullable=True)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    category: Mapped[str | None] = mapped_column(String(128), nullable=True)
    url: Mapped[str | None] = mapped_column(Text, nullable=True)
    has_attachment: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="CODAL")


class Fund(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "funds"
    __table_args__ = (
        UniqueConstraint("fund_id", name="uq_funds_fund_id"),
        Index("ix_funds_name", "name"),
    )

    fund_id: Mapped[str] = mapped_column(String(128), nullable=False)
    name: Mapped[str] = mapped_column(String(512), nullable=False)
    type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    nav: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    nav_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    return_1m: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    return_3m: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    return_6m: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    return_1y: Mapped[Decimal | None] = mapped_column(Numeric(18, 8), nullable=True)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="FIPIRAN")


class FundNavHistory(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "fund_navs"
    __table_args__ = (
        UniqueConstraint("fund_id", "nav_date", "source", name="uq_fund_nav_fund_date_source"),
        Index("ix_fund_nav_fund_date_desc", "fund_id", "nav_date"),
        CheckConstraint(
            "subscription_nav IS NULL OR subscription_nav >= 0",
            name="ck_fund_nav_subscription_non_negative",
        ),
        CheckConstraint(
            "redemption_nav IS NULL OR redemption_nav >= 0",
            name="ck_fund_nav_redemption_non_negative",
        ),
        CheckConstraint(
            "statistical_nav IS NULL OR statistical_nav >= 0",
            name="ck_fund_nav_statistical_non_negative",
        ),
    )

    fund_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("funds.fund_id", ondelete="CASCADE"),
        nullable=False,
    )
    nav_date: Mapped[date] = mapped_column(Date, nullable=False)
    subscription_nav: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    redemption_nav: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    statistical_nav: Mapped[Decimal | None] = mapped_column(Numeric(24, 8), nullable=True)
    source: Mapped[str] = mapped_column(String(64), nullable=False, default="FIPIRAN")


class IngestionRun(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "ingestion_runs"
    __table_args__ = (
        Index("ix_ingestion_runs_source_started", "source", "started_at"),
        Index("ix_ingestion_runs_status", "status"),
    )

    source: Mapped[str] = mapped_column(String(64), nullable=False)
    provider: Mapped[str | None] = mapped_column(String(64), nullable=True)
    run_type: Mapped[str] = mapped_column(String(64), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="running")
    records_received: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    records_valid: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    records_inserted: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    records_updated: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    errors_count: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    last_success_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    records_seen: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    records_upserted: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    records_failed: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)


class PortfolioSnapshot(UUIDMixin, TimestampMixin, Base):
    """
    Point-in-time valuation snapshot of a portfolio.

    Generated nightly by a background task.  The `holdings_breakdown`
    JSONB column stores per-asset detail to avoid expensive re-computation
    when rendering historical charts.
    """
    __tablename__ = "portfolio_snapshots"

    __table_args__ = (
        UniqueConstraint(
            "portfolio_id", "snapshot_date",
            name="uq_snapshot_portfolio_date",
        ),
        Index("ix_snapshot_portfolio_date", "portfolio_id", "snapshot_date"),
    )

    # ── Foreign Keys ─────────────────────────────────────
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
    )

    # ── Valuation (ALL NUMERIC — NO FLOATS) ──────────────
    snapshot_date: Mapped[date] = mapped_column(
        Date, nullable=False,
    )
    total_market_value: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
        comment="Sum of (quantity × close_price) for all holdings",
    )
    total_cost_basis: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
        comment="Sum of net purchase cost across all holdings",
    )
    total_gain_loss: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
        comment="total_market_value - total_cost_basis",
    )
    total_gain_loss_pct: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False,
        comment="(gain / cost_basis) × 100, stored as percentage",
    )
    cash_balance: Mapped[Decimal] = mapped_column(
        Numeric(18, 4), nullable=False, default=Decimal("0.0000"),
        comment="Uninvested cash from dividends or deposits",
    )

    # ── Denormalized per-asset detail ────────────────────
    holdings_breakdown: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True,
        comment=(
            "Array of {asset_id, ticker, quantity, avg_cost, market_price, "
            "market_value, gain_loss, weight_pct}"
        ),
    )

    # ── Relationships ────────────────────────────────────
    portfolio: Mapped["Portfolio"] = relationship(back_populates="snapshots")

    def __repr__(self) -> str:
        return (
            f"<Snapshot portfolio={self.portfolio_id} "
            f"date={self.snapshot_date} value={self.total_market_value}>"
        )


# Backward-compatible alias for legacy imports.
AssetPriceHistory = DailyPrice
