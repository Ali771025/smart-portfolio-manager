"""Polymorphic manual transaction contracts with strict validation."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Discriminator, Field, field_validator, model_validator

from app.models.enums import TransactionType

MoneyDecimal = Annotated[Decimal, Field(max_digits=24, decimal_places=8)]
QuantityDecimal = Annotated[
    Decimal,
    Field(
        max_digits=24,
        decimal_places=8,
        gt=Decimal("0"),
        description="Supports fractional positions up to 8 decimal places.",
    ),
]


class StrictSchema(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ManualTransactionBase(StrictSchema):
    transaction_type: TransactionType
    portfolio_id: uuid.UUID
    symbol: str = Field(min_length=1, max_length=32)
    transaction_date: date
    quantity: QuantityDecimal
    notes: str | None = Field(default=None, max_length=1000)

    @field_validator("symbol")
    @classmethod
    def normalize_symbol(cls, value: str) -> str:
        symbol = value.strip().upper()
        if not symbol:
            raise ValueError("symbol cannot be blank")
        return symbol


class BuyTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.BUY]
    price: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")


class SellTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.SELL]
    price: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")


class CashDividendTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.CASH_DIVIDEND]
    dps: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    price: Annotated[MoneyDecimal | None, Field(default=None, ge=Decimal("0"))] = None
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")

    @model_validator(mode="after")
    def validate_dividend_rules(self) -> "CashDividendTransactionCreate":
        if self.price not in (None, Decimal("0")):
            raise ValueError("price must be omitted or set to 0 for CASH_DIVIDEND")
        if self.commission != Decimal("0"):
            raise ValueError("commission must be 0 for CASH_DIVIDEND")
        return self


class CapitalIncreaseBonusTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.CAPITAL_INCREASE_BONUS]
    bonus_ratio: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    price: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")

    @model_validator(mode="after")
    def validate_zero_cost_rules(self) -> "CapitalIncreaseBonusTransactionCreate":
        if self.price != Decimal("0") or self.commission != Decimal("0"):
            raise ValueError("CAPITAL_INCREASE_BONUS requires price=0 and commission=0")
        return self


class StockSplitTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.STOCK_SPLIT]
    split_from: int = Field(ge=1)
    split_to: int = Field(ge=1)
    price: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")

    @model_validator(mode="after")
    def validate_split_rules(self) -> "StockSplitTransactionCreate":
        if self.split_to <= self.split_from:
            raise ValueError("split_to must be greater than split_from")
        if self.price != Decimal("0") or self.commission != Decimal("0"):
            raise ValueError("STOCK_SPLIT requires price=0 and commission=0")
        return self


class PreEmptiveRightsTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.PRE_EMPTIVE_RIGHTS]
    rights_ratio: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    subscription_price: Annotated[MoneyDecimal, Field(gt=Decimal("0"))]
    price: Annotated[MoneyDecimal | None, Field(default=None, ge=Decimal("0"))] = None
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")

    @model_validator(mode="after")
    def validate_rights_pricing(self) -> "PreEmptiveRightsTransactionCreate":
        if self.price is None:
            self.price = self.subscription_price
        if self.price <= Decimal("0"):
            raise ValueError("price must be > 0 for PRE_EMPTIVE_RIGHTS")
        return self


class AssetTransferTransactionCreate(ManualTransactionBase):
    transaction_type: Literal[TransactionType.ASSET_TRANSFER]
    target_symbol: str = Field(min_length=1, max_length=32)
    price: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")
    commission: Annotated[MoneyDecimal, Field(ge=Decimal("0"))] = Decimal("0")

    @field_validator("target_symbol")
    @classmethod
    def normalize_target_symbol(cls, value: str) -> str:
        symbol = value.strip().upper()
        if not symbol:
            raise ValueError("target_symbol cannot be blank")
        return symbol

    @model_validator(mode="after")
    def validate_target_symbol(self) -> "AssetTransferTransactionCreate":
        if self.target_symbol == self.symbol:
            raise ValueError("target_symbol must differ from symbol")
        return self


ManualTransactionPayload = (
    BuyTransactionCreate
    | SellTransactionCreate
    | CapitalIncreaseBonusTransactionCreate
    | StockSplitTransactionCreate
    | PreEmptiveRightsTransactionCreate
    | CashDividendTransactionCreate
    | AssetTransferTransactionCreate
)

ManualTransactionCreateRequest = Annotated[
    ManualTransactionPayload,
    Discriminator("transaction_type"),
]


class ManualTransactionRead(StrictSchema):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    portfolio_id: uuid.UUID
    created_by_user_id: uuid.UUID
    symbol: str
    transaction_type: TransactionType
    transaction_date: date
    quantity: Decimal
    price: Decimal | None
    commission: Decimal
    total_value: Decimal
    event_metadata: dict[str, str | int | float | bool | None]
    idempotency_key: str
    idempotency_fingerprint: str
    version_id: int
    notes: str | None
    created_at: datetime
    updated_at: datetime


class ValidationFieldError(StrictSchema):
    field: str
    message: str


class ProblemDetails(StrictSchema):
    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: str
    errors: list[ValidationFieldError] | None = None

