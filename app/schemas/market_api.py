"""Pydantic schemas for Market API endpoints.

Provides stable, Flutter-friendly response structures for:
  - Live market snapshots
  - Historical price data
  - Market status and freshness metadata
  - Index snapshots

All schemas use consistent naming and decimal string serialization
for Flutter JSON parsing compatibility.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


# ═══════════════════════════════════════════════════════════════
# Live Market Snapshot
# ═══════════════════════════════════════════════════════════════

class LiveMarketSnapshotResponse(BaseModel):
    """Response schema for live market data of a single instrument.

    Flutter usage:
        final snapshot = LiveMarketSnapshotResponse.fromJson(json);
        final price = snapshot.closePrice;
    """
    model_config = ConfigDict(populate_by_name=True)

    ins_code: str = Field(..., alias="insCode", description="TSETMC instrument code")
    ticker: str = Field(..., description="Ticker symbol")
    close_price: str = Field(..., alias="closePrice", description="Latest closing price")
    last_trade_price: str = Field(..., alias="lastTradePrice", description="Last trade price")
    last_price: str = Field(..., alias="lastPrice", description="Latest last-trade price")
    closing_price: str = Field(..., alias="closingPrice", description="Latest closing price")
    price_change: str | None = Field(None, alias="priceChange", description="Absolute price change")
    price_change_percent: str | None = Field(None, alias="priceChangePercent", description="Price change percentage")
    last_updated_at: str | None = Field(None, alias="lastUpdatedAt", description="Market Engine update timestamp")
    open_price: str = Field(..., alias="openPrice", description="Opening price")
    high_price: str = Field(..., alias="highPrice", description="Day high price")
    low_price: str = Field(..., alias="lowPrice", description="Day low price")
    volume: int = Field(..., description="Trading volume")
    state: str = Field(..., description="Instrument state (TRADEABLE, HALT, etc.)")
    has_corporate_action: bool = Field(..., alias="hasCorporateAction", description="Corporate action flag")
    fetched_at: str | None = Field(None, alias="fetchedAt", description="Data timestamp (ISO 8601)")
    is_fresh: bool = Field(True, alias="isFresh", description="True if data is within expected freshness")

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> LiveMarketSnapshotResponse:
        """Create from market_cache deserialized dict."""
        return cls(
            ins_code=data.get("ins_code", ""),
            ticker=data.get("ticker", ""),
            close_price=str(data.get("close_price", "0")),
            last_trade_price=str(data.get("last_trade_price", "0")),
            last_price=str(data.get("last_trade_price", data.get("close_price", "0"))),
            closing_price=str(data.get("close_price", "0")),
            price_change=str(data["price_change"]) if data.get("price_change") is not None else None,
            price_change_percent=(
                str(data["price_change_percent"])
                if data.get("price_change_percent") is not None
                else None
            ),
            last_updated_at=data.get("fetched_at").isoformat() if data.get("fetched_at") else None,
            open_price=str(data.get("open_price", "0")),
            high_price=str(data.get("high_price", "0")),
            low_price=str(data.get("low_price", "0")),
            volume=int(data.get("volume", 0)),
            state=data.get("state", "UNKNOWN"),
            has_corporate_action=bool(data.get("has_corporate_action", False)),
            fetched_at=data.get("fetched_at").isoformat() if data.get("fetched_at") else None,
        )


class LiveMarketBatchResponse(BaseModel):
    """Response schema for batch live market data."""
    snapshots: list[LiveMarketSnapshotResponse]
    count: int
    fetched_at: str


# ═══════════════════════════════════════════════════════════════
# Historical Price Data
# ═══════════════════════════════════════════════════════════════

class PriceBarResponse(BaseModel):
    """Response schema for a single historical price bar.

    Flutter usage:
        final bar = PriceBarResponse.fromJson(json);
        final date = bar.date;
        final close = double.parse(bar.closePrice);
    """
    model_config = ConfigDict(populate_by_name=True)

    date: str = Field(..., description="Price date (YYYY-MM-DD)")
    open_price: str = Field(..., alias="openPrice", description="Opening price")
    high_price: str = Field(..., alias="highPrice", description="High price")
    low_price: str = Field(..., alias="lowPrice", description="Low price")
    close_price: str = Field(..., alias="closePrice", description="Closing price")
    adjusted_close: str = Field(..., alias="adjustedClose", description="Adjusted close price")
    volume: int = Field(..., description="Trading volume")


class SymbolHistoryResponse(BaseModel):
    """Response schema for symbol historical data.

    Flutter usage:
        final history = SymbolHistoryResponse.fromJson(json);
        for (final bar in history.bars) { ... }
    """
    model_config = ConfigDict(populate_by_name=True)

    asset_id: str = Field(..., alias="assetId", description="Asset UUID")
    ticker: str = Field(..., description="Ticker symbol")
    bars: list[PriceBarResponse]
    count: int = Field(..., description="Number of bars")
    start_date: str = Field(..., alias="startDate", description="First bar date")
    end_date: str = Field(..., alias="endDate", description="Last bar date")


# ═══════════════════════════════════════════════════════════════
# Market Status
# ═══════════════════════════════════════════════════════════════

class MarketStatusResponse(BaseModel):
    """Response schema for market status and freshness metadata.

    Flutter usage:
        final status = MarketStatusResponse.fromJson(json);
        if (status.isStale) { showRefreshPrompt(); }
    """
    model_config = ConfigDict(populate_by_name=True)

    provider_status: str = Field(..., alias="providerStatus", description="Provider health status")
    last_sync_at: str | None = Field(None, alias="lastSyncAt", description="Last successful sync timestamp")
    synced_assets: int = Field(0, alias="syncedAssets", description="Assets synced in last cycle")
    failed_assets: int = Field(0, alias="failedAssets", description="Assets that failed sync")
    is_market_open: bool = Field(True, alias="isMarketOpen", description="True if market is in trading hours")
    is_trading_day: bool = Field(True, alias="isTradingDay", description="True if today is a trading day")
    data_freshness_seconds: int | None = Field(None, alias="dataFreshnessSeconds", description="Seconds since last data update")
    is_stale: bool = Field(False, alias="isStale", description="True if data is considered stale")
    checked_at: str = Field(..., alias="checkedAt", description="Status check timestamp")
    market_status: str = Field(..., description="open or closed")
    is_current_session: bool = Field(..., description="True when data belongs to the active open session")
    price_info_timestamp: str | None = None
    server_received_at: str | None = None
    source: str = "UNKNOWN"
    data_quality_status: str = Field(..., description="current, stale, or unavailable")


# ═══════════════════════════════════════════════════════════════
# Index Snapshot
# ═══════════════════════════════════════════════════════════════

class IndexSnapshotResponse(BaseModel):
    """Response schema for market index snapshot.

    Flutter usage:
        final index = IndexSnapshotResponse.fromJson(json);
        final value = double.parse(index.lastValue);
    """
    model_config = ConfigDict(populate_by_name=True)

    index_code: str = Field(..., alias="indexCode", description="Index code")
    name: str = Field(..., description="Index name")
    last_value: str = Field(..., alias="lastValue", description="Current index value")
    change_value: str = Field(..., alias="changeValue", description="Change from previous close")
    change_percent: str = Field(..., alias="changePercent", description="Percentage change")
    open_value: str = Field(..., alias="openValue", description="Opening value")
    high_value: str = Field(..., alias="highValue", description="Day high")
    low_value: str = Field(..., alias="lowValue", description="Day low")
    volume: int = Field(..., description="Total volume")
    fetched_at: str | None = Field(None, alias="fetchedAt", description="Data timestamp")
    source: str = "UNKNOWN"


class MarketOverviewResponse(BaseModel):
    """Normalized market overview contract."""
    model_config = ConfigDict(populate_by_name=True)

    total_index_value: str
    total_index_change: str | None
    equal_weight_index_value: str
    equal_weight_index_change: str | None
    market_value: str | None
    trades_count: int
    trades_value: str | None
    trades_volume: int
    price_info_timestamp: str
    server_received_at: str
    market_status: str
    is_current_session: bool
    source: str
    data_quality_status: str


class MarketIndicesResponse(BaseModel):
    indices: list[IndexSnapshotResponse]
    price_info_timestamp: str | None
    server_received_at: str
    market_status: str
    is_current_session: bool
    source: str
    data_quality_status: str


class QuoteResponse(BaseModel):
    """Canonical Flutter quote contract for latest symbol-like market data."""

    symbol: str
    instrument_id: str | None = None
    last_price: str | None = None
    closing_price: str | None = None
    yesterday_price: str | None = None
    price_change: str | None = None
    price_change_percent: str | None = None
    volume: int
    value: str | None = None
    trade_count: int
    trade_date: date | None = None
    event_time: datetime | None = None
    received_at: datetime | None = None
    market_status: str
    is_current_session: bool
    is_stale: bool
    source: str


class MarketWatchResponse(BaseModel):
    """Paginated latest market-watch snapshot, never raw provider payloads."""

    items: list[QuoteResponse]
    page: int
    page_size: int
    count: int
    compact: bool
    server_time: datetime
    data_quality_status: str
    market_status: str
    is_current_session: bool
    is_stale: bool
    source: str


class SymbolResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    symbol: str
    instrument_id: str | None = None
    ins_code: str | None = None
    isin: str | None = None
    company_name: str | None = None
    market: str | None = None
    board: str | None = None
    sector_code: str | None = None
    sector_name: str | None = None
    instrument_type: str | None = None
    is_active: bool = True


class SymbolListResponse(BaseModel):
    items: list[SymbolResponse]
    page: int
    page_size: int
    count: int


class NormalizedPriceBarResponse(BaseModel):
    trade_date: date
    open_price: str | None = None
    high_price: str | None = None
    low_price: str | None = None
    closing_price: str | None = None
    last_price: str | None = None
    yesterday_price: str | None = None
    adjusted_close: str | None = None
    volume: int
    value: str | None = None
    trade_count: int
    source: str


class SymbolHistoryNormalizedResponse(BaseModel):
    symbol: str
    instrument_id: str | None = None
    period: dict[str, str | int | None]
    bars: list[NormalizedPriceBarResponse]
    missing_dates: list[date]
    non_trading_dates: list[date]
    count: int
    data_quality_status: str


class ClientTypesResponse(BaseModel):
    symbol: str
    instrument_id: str | None = None
    trade_date: date
    individual_buy_count: int
    individual_buy_volume: int
    individual_sell_count: int
    individual_sell_volume: int
    legal_buy_count: int
    legal_buy_volume: int
    legal_sell_count: int
    legal_sell_volume: int
    source: str = "TSETMC"


class OrderBookLevelResponse(BaseModel):
    level: int
    buy_price: str | None = None
    buy_volume: int | None = None
    buy_count: int | None = None
    sell_price: str | None = None
    sell_volume: int | None = None
    sell_count: int | None = None


class OrderBookResponse(BaseModel):
    symbol: str
    instrument_id: str | None = None
    event_time: datetime | None = None
    levels: list[OrderBookLevelResponse]
    source: str = "TSETMC"


# ═══════════════════════════════════════════════════════════════
# Sync Trigger (Admin/Internal)
# ═══════════════════════════════════════════════════════════════

class SyncTriggerResponse(BaseModel):
    """Response schema for sync trigger endpoint."""
    task_id: str = Field(..., alias="taskId", description="Celery task ID")
    status: str = Field(..., description="Task status")
    message: str = Field(..., description="Human-readable message")


# ═══════════════════════════════════════════════════════════════
# Error Responses
# ═══════════════════════════════════════════════════════════════

class MarketErrorResponse(BaseModel):
    """Standard error response for market API."""
    error: str
    detail: str | None = None
    status_code: int
