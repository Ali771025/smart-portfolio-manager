"""Market data provider abstraction for Tehran Stock Exchange (TSETMC).

Defines a Protocol-based interface that decouples the sync engine from
any specific HTTP client implementation. This allows:
  - Swapping providers without touching business logic
  - Testing with mock providers
  - Future multi-source support (e.g., regional exchanges)

Usage:
    provider: MarketDataProvider = TSETMCProvider(config)
    snapshot = await provider.fetch_live_market_snapshot("ins_code")
"""

from __future__ import annotations

import abc
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import Any, Protocol, runtime_checkable

from pydantic import BaseModel, ConfigDict, Field

from app.services.market_provider_errors import (
    FieldValidationError,
    MarketProviderError,
    PayloadSchemaError,
    ProviderCircuitOpenError,
    ProviderConnectionError,
    ProviderHTTPError,
    ProviderNetworkError,
    ProviderParseError,
    ProviderRateLimitError,
    ProviderServerError,
    ProviderTimeoutError,
)


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class MarketProviderStatus(str, Enum):
    """Health status of a market data provider."""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"


class InstrumentState(str, Enum):
    """Trading state of an instrument on TSETMC."""
    TRADEABLE = "TRADEABLE"
    HALT = "HALT"
    SUSPENDED = "SUSPENDED"
    CLOSED = "CLOSED"
    STOPPED = "STOPPED"
    UNKNOWN = "UNKNOWN"


def _validate_required_text(value: str | None, field_name: str) -> None:
    if value is None or not str(value).strip():
        raise ValueError(f"{field_name} is required")


def _validate_non_negative_decimal(value: Decimal | None, field_name: str) -> None:
    if value is not None and value < 0:
        raise ValueError(f"{field_name} must not be negative")


def _validate_non_negative_int(value: int | None, field_name: str) -> None:
    if value is not None and value < 0:
        raise ValueError(f"{field_name} must not be negative")


def _validate_aware_datetime(value: datetime | None, field_name: str) -> None:
    if value is not None and value.tzinfo is None:
        raise ValueError(f"{field_name} must be timezone-aware")


# ═══════════════════════════════════════════════════════════════
# Value Objects (Internal Contracts)
# ═══════════════════════════════════════════════════════════════

@dataclass(slots=True, frozen=True)
class LiveMarketSnapshot:
    """Real-time market data for a single instrument."""
    ins_code: str
    ticker: str
    close_price: Decimal
    last_trade_price: Decimal
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    volume: int
    state: InstrumentState
    has_corporate_action: bool
    fetched_at: datetime
    price_change: Decimal | None = None
    price_change_percent: Decimal | None = None


@dataclass(slots=True, frozen=True)
class PriceBar:
    """Single OHLCV price bar for historical data."""
    date: date
    open_price: Decimal
    high_price: Decimal
    low_price: Decimal
    close_price: Decimal
    adjusted_close: Decimal
    adjustment_factor: Decimal
    volume: int
    last_trade_price: Decimal | None = None


@dataclass(slots=True, frozen=True)
class IndexSnapshot:
    """Market index snapshot (e.g., TEDPIX, TEP10)."""
    index_code: str
    name: str
    last_value: Decimal
    change_value: Decimal
    change_percent: Decimal
    open_value: Decimal
    high_value: Decimal
    low_value: Decimal
    volume: int
    fetched_at: datetime


@dataclass(slots=True, frozen=True)
class MarketInstrument:
    """Normalized exchange instrument metadata."""

    instrument_id: str
    symbol: str
    ins_code: str | None = None
    internal_id: str | None = None
    isin: str | None = None
    company_name: str | None = None
    market: str = "TSETMC"
    board: str | None = None
    sector_code: str | None = None
    sector_name: str | None = None
    instrument_type: str | None = None
    is_active: bool = True

    @property
    def id(self) -> str | None:
        return self.internal_id

    @property
    def name(self) -> str | None:
        return self.company_name

    def __post_init__(self) -> None:
        _validate_required_text(self.instrument_id or self.ins_code, "instrument_id/ins_code")
        _validate_required_text(self.symbol, "symbol")


@dataclass(slots=True, frozen=True)
class MarketQuote:
    """Normalized latest quote for a single instrument."""

    instrument_id: str
    symbol: str
    trade_date: date | None = None
    event_time: datetime | None = None
    first_price: Decimal | None = None
    last_price: Decimal | None = None
    closing_price: Decimal | None = None
    yesterday_price: Decimal | None = None
    high_price: Decimal | None = None
    low_price: Decimal | None = None
    trade_count: int = 0
    volume: int = 0
    value: Decimal | None = None
    buy_count: int | None = None
    sell_count: int | None = None
    status: InstrumentState | str = InstrumentState.UNKNOWN
    received_at: datetime | None = None
    source: str = "TSETMC"

    @property
    def last_trade_price(self) -> Decimal | None:
        return self.last_price

    @property
    def open_price(self) -> Decimal | None:
        return self.first_price

    @property
    def previous_close_price(self) -> Decimal | None:
        return self.yesterday_price

    @property
    def state(self) -> InstrumentState | str:
        return self.status

    @property
    def fetched_at(self) -> datetime | None:
        return self.received_at

    @property
    def price_change(self) -> Decimal | None:
        if self.last_price is None or self.yesterday_price is None:
            return None
        return self.last_price - self.yesterday_price

    @property
    def price_change_percent(self) -> Decimal | None:
        if self.price_change is None or not self.yesterday_price:
            return None
        return self.price_change / self.yesterday_price * Decimal("100")

    def __post_init__(self) -> None:
        _validate_required_text(self.instrument_id, "instrument_id")
        _validate_required_text(self.symbol, "symbol")
        _validate_non_negative_decimal(self.closing_price, "closing_price")
        _validate_non_negative_decimal(self.last_price, "last_price")
        _validate_non_negative_decimal(self.value, "value")
        _validate_non_negative_int(self.volume, "volume")
        _validate_non_negative_int(self.trade_count, "trade_count")
        _validate_non_negative_int(self.buy_count, "buy_count")
        _validate_non_negative_int(self.sell_count, "sell_count")
        _validate_aware_datetime(self.event_time, "event_time")
        _validate_aware_datetime(self.received_at, "received_at")


@dataclass(slots=True, frozen=True)
class DailyPrice:
    """Normalized daily OHLCV market price."""

    instrument_id: str
    trade_date: date
    open_price: Decimal | None = None
    high_price: Decimal | None = None
    low_price: Decimal | None = None
    last_price: Decimal | None = None
    closing_price: Decimal | None = None
    yesterday_price: Decimal | None = None
    volume: int = 0
    value: Decimal | None = None
    trade_count: int = 0
    adjusted_close: Decimal | None = None
    source: str = "TSETMC"
    updated_at: datetime | None = None

    @property
    def last_trade_price(self) -> Decimal | None:
        return self.last_price

    @property
    def close_price(self) -> Decimal | None:
        return self.closing_price

    def __post_init__(self) -> None:
        _validate_required_text(self.instrument_id, "instrument_id")
        _validate_non_negative_decimal(self.closing_price, "closing_price")
        _validate_non_negative_decimal(self.last_price, "last_price")
        _validate_non_negative_decimal(self.value, "value")
        _validate_non_negative_int(self.volume, "volume")
        _validate_non_negative_int(self.trade_count, "trade_count")
        _validate_aware_datetime(self.updated_at, "updated_at")


@dataclass(slots=True, frozen=True)
class MarketSnapshot:
    """Normalized whole-market snapshot."""

    provider: str
    fetched_at: datetime
    quotes: list[MarketQuote]
    instruments_count: int = 0


@dataclass(slots=True, frozen=True)
class ClientTypeBreakdown:
    """Normalized client-type trading breakdown for one instrument/day."""

    instrument_id: str
    trade_date: date
    individual_buy_volume: int = 0
    individual_sell_volume: int = 0
    legal_buy_volume: int = 0
    legal_sell_volume: int = 0
    individual_buy_count: int = 0
    individual_sell_count: int = 0
    legal_buy_count: int = 0
    legal_sell_count: int = 0

    def __post_init__(self) -> None:
        _validate_required_text(self.instrument_id, "instrument_id")
        for field_name in (
            "individual_buy_volume",
            "individual_sell_volume",
            "legal_buy_volume",
            "legal_sell_volume",
            "individual_buy_count",
            "individual_sell_count",
            "legal_buy_count",
            "legal_sell_count",
        ):
            _validate_non_negative_int(getattr(self, field_name), field_name)


ClientType = ClientTypeBreakdown


@dataclass(slots=True, frozen=True)
class OrderBookLevel:
    """Normalized single order-book level."""

    instrument_id: str
    event_time: datetime
    level: int
    buy_price: Decimal | None = None
    buy_volume: int | None = None
    buy_count: int | None = None
    sell_price: Decimal | None = None
    sell_volume: int | None = None
    sell_count: int | None = None

    @property
    def bid_price(self) -> Decimal | None:
        return self.buy_price

    @property
    def bid_volume(self) -> int | None:
        return self.buy_volume

    @property
    def ask_price(self) -> Decimal | None:
        return self.sell_price

    @property
    def ask_volume(self) -> int | None:
        return self.sell_volume

    def __post_init__(self) -> None:
        _validate_required_text(self.instrument_id, "instrument_id")
        _validate_aware_datetime(self.event_time, "event_time")
        _validate_non_negative_int(self.level, "level")
        _validate_non_negative_decimal(self.buy_price, "buy_price")
        _validate_non_negative_decimal(self.sell_price, "sell_price")
        _validate_non_negative_int(self.buy_volume, "buy_volume")
        _validate_non_negative_int(self.sell_volume, "sell_volume")
        _validate_non_negative_int(self.buy_count, "buy_count")
        _validate_non_negative_int(self.sell_count, "sell_count")


@dataclass(slots=True, frozen=True)
class OrderBookSnapshot:
    """Normalized order book for one instrument."""

    instrument_id: str
    fetched_at: datetime
    levels: list[OrderBookLevel]


@dataclass(slots=True, frozen=True)
class MarketIndex:
    """Normalized market index quote."""

    index_code: str
    name: str
    value: Decimal
    change: Decimal | None
    change_percent: Decimal | None
    event_time: datetime
    source: str = "TSETMC"

    @property
    def index_id(self) -> str:
        return self.index_code

    @property
    def fetched_at(self) -> datetime:
        return self.event_time

    def __post_init__(self) -> None:
        _validate_required_text(self.index_code, "index_code")
        _validate_required_text(self.name, "name")
        _validate_non_negative_decimal(self.value, "value")
        _validate_aware_datetime(self.event_time, "event_time")


@dataclass(slots=True, frozen=True)
class MarketOverview:
    """Normalized Tehran market overview snapshot."""

    total_index_value: Decimal
    total_index_change: Decimal | None
    equal_weight_index_value: Decimal
    equal_weight_index_change: Decimal | None
    market_value: Decimal | None
    trades_count: int
    trades_value: Decimal | None
    trades_volume: int
    price_info_timestamp: datetime
    server_received_at: datetime
    source: str = "TSETMC"

    def __post_init__(self) -> None:
        _validate_non_negative_decimal(self.total_index_value, "total_index_value")
        _validate_non_negative_decimal(
            self.equal_weight_index_value,
            "equal_weight_index_value",
        )
        _validate_non_negative_decimal(self.market_value, "market_value")
        _validate_non_negative_decimal(self.trades_value, "trades_value")
        _validate_non_negative_int(self.trades_count, "trades_count")
        _validate_non_negative_int(self.trades_volume, "trades_volume")
        _validate_aware_datetime(self.price_info_timestamp, "price_info_timestamp")
        _validate_aware_datetime(self.server_received_at, "server_received_at")
        _validate_required_text(self.source, "source")


@dataclass(slots=True, frozen=True)
class SymbolStatus:
    """Normalized symbol trading status."""

    instrument_id: str
    symbol: str
    state: InstrumentState
    reason: str | None = None
    updated_at: datetime | None = None


@dataclass(slots=True, frozen=True)
class SupervisorMessage:
    """Normalized market supervisor message."""

    message_id: str
    title: str
    body: str | None
    published_at: datetime | None
    instrument_id: str | None = None
    symbol: str | None = None


@dataclass(slots=True, frozen=True)
class CodalDisclosureFilters:
    """Normalized filters for Codal disclosure search."""

    symbol: str | None = None
    category: str | None = None
    from_date: date | None = None
    to_date: date | None = None
    has_attachment: bool | None = None
    page: int = 1
    page_size: int = 50


@dataclass(slots=True, frozen=True)
class CodalDisclosure:
    """Normalized Codal disclosure list item."""

    tracking_number: str
    symbol: str
    title: str
    company_name: str | None = None
    letter_code: str | None = None
    sent_at: datetime | None = None
    published_at: datetime | None = None
    category: str | None = None
    url: str | None = None
    has_attachment: bool = False
    source: str = "CODAL"

    def __post_init__(self) -> None:
        _validate_required_text(self.tracking_number, "tracking_number")
        _validate_required_text(self.symbol, "symbol")
        _validate_required_text(self.title, "title")
        _validate_aware_datetime(self.sent_at, "sent_at")
        _validate_aware_datetime(self.published_at, "published_at")


@dataclass(slots=True, frozen=True)
class CodalDisclosureDetail:
    """Normalized Codal disclosure detail."""

    tracking_number: str
    symbol: str
    title: str
    published_at: datetime | None
    body: str | None = None
    attachments: list[str] = field(default_factory=list)


@dataclass(slots=True, frozen=True)
class Fund:
    """Normalized fund metadata."""

    fund_id: str
    name: str
    symbol: str | None = None
    type: str | None = None
    nav: Decimal | None = None
    nav_date: date | None = None
    return_1m: Decimal | None = None
    return_3m: Decimal | None = None
    return_6m: Decimal | None = None
    return_1y: Decimal | None = None
    manager: str | None = None
    source: str = "FIPIRAN"

    @property
    def fund_type(self) -> str | None:
        return self.type

    def __post_init__(self) -> None:
        _validate_required_text(self.fund_id, "fund_id")
        _validate_required_text(self.name, "name")
        _validate_non_negative_decimal(self.nav, "nav")


@dataclass(slots=True, frozen=True)
class FundNav:
    """Normalized fund NAV snapshot."""

    fund_id: str
    nav_date: date
    subscription_nav: Decimal | None = None
    redemption_nav: Decimal | None = None
    statistical_nav: Decimal | None = None
    source: str = "FIPIRAN"

    def __post_init__(self) -> None:
        _validate_required_text(self.fund_id, "fund_id")
        _validate_non_negative_decimal(self.subscription_nav, "subscription_nav")
        _validate_non_negative_decimal(self.redemption_nav, "redemption_nav")
        _validate_non_negative_decimal(self.statistical_nav, "statistical_nav")


@dataclass(slots=True, frozen=True)
class FundReturn:
    """Normalized fund return for a named window."""

    fund_id: str
    window: str
    return_percent: Decimal | None
    as_of_date: date | None = None


@dataclass(slots=True, frozen=True)
class ProviderHealth:
    """Health check result for a market data provider."""
    provider_name: str
    status: MarketProviderStatus
    latency_ms: float | None = None
    last_success_at: datetime | None = None
    error_message: str | None = None
    details: dict[str, str] = field(default_factory=dict)


# ═══════════════════════════════════════════════════════════════
# Provider Configuration
# ═══════════════════════════════════════════════════════════════

class MarketProviderConfig(BaseModel):
    """Configuration for market data providers.

    All retry/timeout settings are centralized here to avoid
    spreading provider-specific constants across the codebase.
    """
    model_config = ConfigDict(frozen=True)

    # Connection
    base_url: str = "http://www.tsetmc.com/tsev2/data"
    request_timeout: float = 15.0
    connect_timeout: float = 5.0
    max_concurrent: int = 10

    # Retry policy
    retry_attempts: int = 3
    retry_base_delay: float = 1.0
    retry_max_delay: float = 30.0
    retry_backoff_multiplier: float = 2.0

    # Circuit breaker
    circuit_breaker_failure_threshold: int = 9
    circuit_breaker_reset_seconds: float = 60.0

    # Health check
    health_check_interval: float = 300.0


# ═══════════════════════════════════════════════════════════════
# Provider Protocol (Interface)
# ═══════════════════════════════════════════════════════════════

@runtime_checkable
class MarketDataProvider(Protocol):
    """Protocol defining the contract for market data providers.

    Any provider implementation must satisfy this interface.
    The Protocol is structural (duck-typed), so implementations
    don't need to inherit from it explicitly.
    """

    @property
    def name(self) -> str:
        """Unique identifier for this provider (e.g., 'tsetmc')."""
        ...

    async def fetch_live_market_snapshot(
        self,
        ins_code: str,
    ) -> LiveMarketSnapshot | None:
        """Fetch real-time market data for a single instrument.

        Args:
            ins_code: TSETMC instrument code.

        Returns:
            LiveMarketSnapshot if successful, None if unavailable.
        """
        ...

    async def get_instruments(self) -> list[MarketInstrument]:
        """Return normalized instrument metadata."""
        ...

    async def get_market_snapshot(self) -> MarketSnapshot:
        """Return a normalized whole-market snapshot."""
        ...

    async def get_latest_quote(
        self,
        symbol_or_instrument_id: str,
    ) -> MarketQuote | None:
        """Return a normalized latest quote."""
        ...

    async def get_daily_prices(
        self,
        instrument_id: str,
        from_date: date,
        to_date: date,
    ) -> list[PriceBar]:
        """Return normalized daily price bars."""
        ...

    async def get_client_types(
        self,
        trade_date: date | None = None,
    ) -> list[ClientTypeBreakdown]:
        """Return normalized client-type breakdowns."""
        ...

    async def get_order_book(self, instrument_id: str) -> OrderBookSnapshot:
        """Return normalized order-book levels."""
        ...

    async def get_indices(self) -> list[MarketIndex]:
        """Return normalized market indices."""
        ...

    async def get_market_overview(self) -> MarketOverview | None:
        """Return the latest normalized market overview."""
        ...

    async def get_symbol_statuses(self) -> list[SymbolStatus]:
        """Return normalized symbol statuses."""
        ...

    async def get_supervisor_messages(self) -> list[SupervisorMessage]:
        """Return normalized supervisor messages."""
        ...

    async def fetch_symbol_history(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        """Fetch historical OHLCV data for an instrument.

        Args:
            ins_code: TSETMC instrument code.
            start_date: Start of date range (inclusive).
            end_date: End of date range (inclusive).

        Returns:
            List of PriceBar sorted by date ascending.
        """
        ...

    async def fetch_index_snapshot(
        self,
        index_code: str,
    ) -> IndexSnapshot | None:
        """Fetch current market index value.

        Args:
            index_code: Index instrument code (e.g., TEDPIX).

        Returns:
            IndexSnapshot if successful, None if unavailable.
        """
        ...

    async def healthcheck(self) -> ProviderHealth:
        """Check provider connectivity and return health status.

        Returns:
            ProviderHealth with current status and diagnostics.
        """
        ...

    async def close(self) -> None:
        """Release any resources held by the provider."""
        ...


@runtime_checkable
class CodalProvider(Protocol):
    """Protocol for normalized Codal disclosure providers."""

    @property
    def name(self) -> str:
        ...

    async def get_disclosures(
        self,
        filters: CodalDisclosureFilters,
    ) -> list[CodalDisclosure]:
        ...

    async def get_disclosure_detail(
        self,
        tracking_number: str,
    ) -> CodalDisclosureDetail | None:
        ...

    async def close(self) -> None:
        ...


@runtime_checkable
class FipiranProvider(Protocol):
    """Protocol for normalized Fipiran fund-data providers."""

    @property
    def name(self) -> str:
        ...

    async def get_funds(self) -> list[Fund]:
        ...

    async def get_fund_nav(self, fund_id: str) -> FundNav | None:
        ...

    async def get_fund_returns(
        self,
        fund_id: str,
        window: str,
    ) -> list[FundReturn]:
        ...

    async def close(self) -> None:
        ...


# ═══════════════════════════════════════════════════════════════
# Abstract Base (for explicit inheritance if desired)
# ═══════════════════════════════════════════════════════════════

class BaseMarketDataProvider(abc.ABC):
    """Abstract base class for market data providers.

    Provides shared utilities and enforces the interface contract.
    Implementations can inherit from this or just satisfy the Protocol.
    """

    def __init__(self, config: MarketProviderConfig) -> None:
        self._config = config
        self._name: str = "base"

    @property
    def name(self) -> str:
        return self._name

    @abc.abstractmethod
    async def fetch_live_market_snapshot(
        self,
        ins_code: str,
    ) -> LiveMarketSnapshot | None:
        ...

    @abc.abstractmethod
    async def get_instruments(self) -> list[MarketInstrument]:
        ...

    @abc.abstractmethod
    async def get_market_snapshot(self) -> MarketSnapshot:
        ...

    @abc.abstractmethod
    async def get_latest_quote(
        self,
        symbol_or_instrument_id: str,
    ) -> MarketQuote | None:
        ...

    @abc.abstractmethod
    async def get_daily_prices(
        self,
        instrument_id: str,
        from_date: date,
        to_date: date,
    ) -> list[PriceBar]:
        ...

    @abc.abstractmethod
    async def get_client_types(
        self,
        trade_date: date | None = None,
    ) -> list[ClientTypeBreakdown]:
        ...

    @abc.abstractmethod
    async def get_order_book(self, instrument_id: str) -> OrderBookSnapshot:
        ...

    @abc.abstractmethod
    async def get_indices(self) -> list[MarketIndex]:
        ...

    @abc.abstractmethod
    async def get_market_overview(self) -> MarketOverview | None:
        ...

    @abc.abstractmethod
    async def get_symbol_statuses(self) -> list[SymbolStatus]:
        ...

    @abc.abstractmethod
    async def get_supervisor_messages(self) -> list[SupervisorMessage]:
        ...

    @abc.abstractmethod
    async def fetch_symbol_history(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        ...

    @abc.abstractmethod
    async def fetch_index_snapshot(
        self,
        index_code: str,
    ) -> IndexSnapshot | None:
        ...

    @abc.abstractmethod
    async def healthcheck(self) -> ProviderHealth:
        ...

    @abc.abstractmethod
    async def close(self) -> None:
        ...

    def __repr__(self) -> str:
        return f"<{self.__class__.__name__} name={self._name!r}>"
