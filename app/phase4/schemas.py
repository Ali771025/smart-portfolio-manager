"""Phase 4 Pydantic v2 contracts for auth, portfolios, trades, and dashboard DTOs."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal, ROUND_HALF_EVEN
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.phase4.models import PortfolioCurrency, TradeSide

MONEY_QUANT = Decimal("0.0001")
PERCENT_QUANT = Decimal("0.01")

DecimalMoney = Annotated[Decimal, Field(max_digits=18, decimal_places=4)]
DecimalPercent = Annotated[Decimal, Field(max_digits=10, decimal_places=2)]


def bankers_round(value: Decimal, quant: Decimal = MONEY_QUANT) -> Decimal:
    """Normalize Decimal values using ROUND_HALF_EVEN (banker's rounding)."""

    return value.quantize(quant, rounding=ROUND_HALF_EVEN)


class APIModel(BaseModel):
    """Shared strict base config for request/response contracts."""

    model_config = ConfigDict(
        extra="forbid",
        populate_by_name=True,
        str_strip_whitespace=True,
    )


class ProblemDetails(APIModel):
    """RFC 7807 Problem Details payload."""

    type: str = Field(default="about:blank")
    title: str
    status: int
    detail: str
    instance: str


class UserRegisterRequest(APIModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=255)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).lower().strip()

    @field_validator("full_name")
    @classmethod
    def normalize_full_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("full_name cannot be blank.")
        return normalized


class UserLoginRequest(APIModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).lower().strip()


class RefreshTokenRequest(APIModel):
    refresh_token: str = Field(min_length=20)


class TokenPairResponse(APIModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    access_expires_in_seconds: int = Field(gt=0)
    refresh_expires_in_seconds: int = Field(gt=0)


class AccessTokenResponse(APIModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    access_expires_in_seconds: int = Field(gt=0)


class UserRead(APIModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: uuid.UUID
    email: EmailStr
    full_name: str
    is_active: bool
    is_verified: bool
    last_login_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class PortfolioCreateRequest(APIModel):
    name: str = Field(min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=1000)
    base_currency: PortfolioCurrency = PortfolioCurrency.IRR
    is_default: bool = False

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("name cannot be blank.")
        return normalized


class PortfolioUpdateRequest(APIModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=1000)
    base_currency: PortfolioCurrency | None = None
    is_default: bool | None = None

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("name cannot be blank.")
        return normalized


class PortfolioRead(APIModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    description: str | None
    base_currency: PortfolioCurrency
    is_default: bool
    is_deleted: bool
    deleted_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PortfolioListResponse(APIModel):
    items: list[PortfolioRead] = Field(default_factory=list)
    total: int = Field(ge=0)


class PortfolioPerformanceMetrics(APIModel):
    """ROI% = ((unrealized_pnl + realized_pnl) / invested_capital) * 100."""

    total_current_value: DecimalMoney
    total_invested_capital: DecimalMoney
    total_unrealized_pnl: DecimalMoney
    total_realized_pnl: DecimalMoney
    overall_roi_percent: DecimalPercent
    risk_std_deviation: DecimalPercent | None = None
    sharpe_ratio: DecimalPercent | None = None

    @classmethod
    def from_components(
        cls,
        *,
        total_current_value: Decimal,
        total_invested_capital: Decimal,
        total_unrealized_pnl: Decimal,
        total_realized_pnl: Decimal,
        risk_std_deviation: Decimal | None = None,
        sharpe_ratio: Decimal | None = None,
    ) -> "PortfolioPerformanceMetrics":
        total_pnl = total_unrealized_pnl + total_realized_pnl
        if total_invested_capital == 0:
            roi_percent = Decimal("0")
        else:
            roi_percent = (total_pnl / total_invested_capital) * Decimal("100")

        return cls(
            total_current_value=bankers_round(total_current_value),
            total_invested_capital=bankers_round(total_invested_capital),
            total_unrealized_pnl=bankers_round(total_unrealized_pnl),
            total_realized_pnl=bankers_round(total_realized_pnl),
            overall_roi_percent=bankers_round(roi_percent, PERCENT_QUANT),
            risk_std_deviation=(
                bankers_round(risk_std_deviation, PERCENT_QUANT) if risk_std_deviation is not None else None
            ),
            sharpe_ratio=bankers_round(sharpe_ratio, PERCENT_QUANT) if sharpe_ratio is not None else None,
        )


class TradeBaseRequest(APIModel):
    portfolio_id: uuid.UUID
    symbol: str = Field(min_length=1, max_length=32)
    asset_name: str | None = Field(default=None, max_length=255)
    quantity: DecimalMoney = Field(gt=0)
    price: DecimalMoney = Field(gt=0)
    fees: DecimalMoney = Field(default=Decimal("0.0000"), ge=0)
    executed_at: datetime
    notes: str | None = Field(default=None, max_length=2000)
    idempotency_key: str = Field(min_length=8, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")
    external_order_id: str | None = Field(default=None, max_length=128)

    @field_validator("symbol")
    @classmethod
    def normalize_symbol(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not normalized:
            raise ValueError("symbol cannot be blank.")
        return normalized

    @field_validator("idempotency_key")
    @classmethod
    def normalize_idempotency_key(cls, value: str) -> str:
        return value.strip()

    @field_validator("executed_at")
    @classmethod
    def validate_executed_at_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("executed_at must be timezone-aware.")
        return value

    @field_validator("quantity", "price", "fees")
    @classmethod
    def normalize_money(cls, value: Decimal) -> Decimal:
        return bankers_round(value)


class BuyTradeRequest(TradeBaseRequest):
    side: Literal[TradeSide.BUY] = TradeSide.BUY


class SellTradeRequest(TradeBaseRequest):
    side: Literal[TradeSide.SELL] = TradeSide.SELL


class TradeRead(APIModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: uuid.UUID
    portfolio_id: uuid.UUID
    user_id: uuid.UUID
    side: TradeSide
    symbol: str
    asset_name: str | None
    quantity: DecimalMoney
    price: DecimalMoney
    fees: DecimalMoney
    gross_amount: DecimalMoney
    realized_pnl: DecimalMoney
    executed_at: datetime
    idempotency_key: str
    external_order_id: str | None
    notes: str | None
    created_at: datetime
    updated_at: datetime


class TradeListResponse(APIModel):
    items: list[TradeRead] = Field(default_factory=list)
    total: int = Field(ge=0)
    limit: int = Field(ge=1, le=200)
    offset: int = Field(ge=0)


class AssetAllocationItem(APIModel):
    symbol: str
    value: DecimalMoney
    weight_percent: DecimalPercent


class DashboardOverviewResponse(APIModel):
    total_current_value: DecimalMoney
    overall_roi_percent: DecimalPercent
    asset_allocation: list[AssetAllocationItem] = Field(default_factory=list)


class GrowthChartPoint(APIModel):
    # Jalali date format (YYYY/MM/DD) expected by Persian charting clients.
    date: str = Field(pattern=r"^\d{4}/\d{2}/\d{2}$")
    total_value: DecimalMoney


class GrowthChartResponse(APIModel):
    portfolio_id: uuid.UUID | None = None
    points: list[GrowthChartPoint] = Field(default_factory=list)
