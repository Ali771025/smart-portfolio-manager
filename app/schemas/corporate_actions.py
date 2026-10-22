"""Schemas for corporate action accounting endpoints."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import CorporateActionType


class CashDividendRequest(BaseModel):
    asset_id: uuid.UUID
    effective_date: date
    dps_amount: Decimal = Field(gt=Decimal("0"), description="Dividend per share")
    notes: str | None = Field(default=None, max_length=500)


class CashDividendResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    effective_date: date
    dps_amount: Decimal
    holding_quantity: Decimal
    total_dividend_profit: Decimal
    idempotency_key: str
    created_at: datetime


class CapitalIncreaseRequest(BaseModel):
    asset_id: uuid.UUID
    action_type: CorporateActionType
    issue_quantity: int = Field(gt=0, description="Number of new shares issued")
    issue_price: Decimal = Field(ge=Decimal("0"), description="0 for bonus shares")
    effective_date: date

    @field_validator("action_type")
    @classmethod
    def validate_action_type(cls, value: CorporateActionType) -> CorporateActionType:
        allowed = {
            CorporateActionType.CAPITAL_INCREASE,
            CorporateActionType.RIGHTS_ISSUE,
            CorporateActionType.STOCK_DIVIDEND,
        }
        if value not in allowed:
            raise ValueError("action_type must be CAPITAL_INCREASE, RIGHTS_ISSUE, or STOCK_DIVIDEND")
        return value

    @model_validator(mode="after")
    def validate_issue_pricing(self) -> "CapitalIncreaseRequest":
        if self.action_type == CorporateActionType.STOCK_DIVIDEND and self.issue_price != Decimal("0"):
            raise ValueError("Stock dividend (bonus shares) must use issue_price = 0")
        if self.action_type == CorporateActionType.RIGHTS_ISSUE and self.issue_price <= Decimal("0"):
            raise ValueError("Rights issue must use issue_price > 0")
        return self


class CapitalIncreaseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    action_type: CorporateActionType
    executed_at: datetime
    issue_quantity: Decimal
    issue_price: Decimal
    old_quantity: Decimal
    old_wac: Decimal
    new_quantity: Decimal
    new_wac: Decimal
    idempotency_key: str
