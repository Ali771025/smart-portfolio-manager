"""Frontend-oriented portfolio API response contracts."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field
from pydantic import field_serializer

from app.models.enums import PortfolioCurrency


def to_camel(value: str) -> str:
    parts = value.split("_")
    return parts[0] + "".join(part.capitalize() for part in parts[1:])


class PortfolioApiModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        serialize_by_alias=True,
    )

    @field_serializer("*", when_used="json")
    def serialize_decimal(self, value):
        if isinstance(value, Decimal):
            return int(value) if value == value.to_integral_value() else float(value)
        return value


class PortfolioHoldingApiItem(PortfolioApiModel):
    asset_id: uuid.UUID
    symbol: str
    name: str | None = None
    quantity: Decimal
    average_cost: Decimal
    weighted_avg_cost: Decimal
    cost_basis: Decimal
    current_price: Decimal | None = None
    latest_price: Decimal | None = None
    market_value: Decimal | None = None
    unrealized_pnl: Decimal | None = None
    unrealized_pnl_percent: Decimal | None = None
    realized_pnl: Decimal
    total_pnl: Decimal | None = None
    total_pnl_percent: Decimal | None = None
    roi: Decimal | None = None
    price_date: datetime | None = None
    price_source: str | None = None
    has_market_price: bool = False
    is_price_stale: bool | None = None
    calculation_status: str = "missing_market_price"
    data_status: str = "missing_market_price"
    warnings: list[str] = Field(default_factory=list)
    currency: PortfolioCurrency = PortfolioCurrency.IRR


class PortfolioHoldingsApiResponse(PortfolioApiModel):
    portfolio_id: uuid.UUID
    currency: PortfolioCurrency
    holdings: list[PortfolioHoldingApiItem]
    priced_holdings_count: int = 0
    missing_price_count: int = 0
    missing_price_symbols: list[str] = Field(default_factory=list)
    has_missing_market_prices: bool = False
    calculation_status: str = "complete"
    warnings: list[str] = Field(default_factory=list)


class PortfolioSummaryApiResponse(PortfolioApiModel):
    portfolio_id: uuid.UUID
    currency: PortfolioCurrency
    total_cost_basis: Decimal
    total_market_value: Decimal
    total_unrealized_pnl: Decimal
    total_unrealized_pnl_percent: Decimal | None = None
    total_realized_pnl: Decimal
    realized_pnl: Decimal
    unrealized_pnl: Decimal
    total_pnl: Decimal
    total_pnl_percent: Decimal | None = None
    roi: Decimal | None = None
    total_portfolio_value: Decimal
    cash_balance: Decimal
    holdings_count: int
    missing_market_price_count: int
    priced_holdings_count: int
    missing_price_count: int
    missing_price_symbols: list[str] = Field(default_factory=list)
    has_missing_market_prices: bool = False
    calculation_status: str = "complete"
    warnings: list[str] = Field(default_factory=list)
