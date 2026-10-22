"""API contracts for normalized fund and risk-free benchmark data."""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict


class FundResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fund_id: str
    name: str
    type: str | None = None
    nav: Decimal | None = None
    nav_date: date | None = None
    return_1m: Decimal | None = None
    return_3m: Decimal | None = None
    return_6m: Decimal | None = None
    return_1y: Decimal | None = None
    source: str


class FundNavResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fund_id: str
    nav_date: date
    subscription_nav: Decimal | None = None
    redemption_nav: Decimal | None = None
    statistical_nav: Decimal | None = None
    source: str


class RiskFreeBenchmarkResponse(BaseModel):
    benchmark_id: str = "RISK_FREE"
    name: str
    annual_return_percent: Decimal
    source: str
    fund_id: str | None = None
    nav: Decimal | None = None
    nav_date: date | None = None
    is_valid: Literal[True] = True
    fallback_used: bool = False
