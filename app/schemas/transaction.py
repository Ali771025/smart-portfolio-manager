"""Ledger transaction schemas with Pydantic v2 discriminated unions.

Fee Handling Rules (Tehran Stock Market):
  - BUY transaction:  total_amount = (quantity × price_per_unit) + fees
    - Fees INCREASE the acquisition cost
    - WAC = (old_quantity × old_wac + total_amount) / new_quantity
  - SELL transaction: total_amount = (quantity × price_per_unit) - fees
    - Fees DECREASE the net proceeds
    - Realized PnL = proceeds - (quantity × old_wac) - fees

Tehran Stock Market Constraints:
  - Quantities must be positive integers (whole shares only)
  - Price per unit must be positive
  - Fees must be non-negative (broker commission + exchange fees)
  - No short selling: sell quantity cannot exceed current holdings
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Discriminator, Field, model_validator

from app.models.enums import TransactionType

DECIMAL_24_8 = Annotated[Decimal, Field(max_digits=24, decimal_places=8)]
POSITIVE_DECIMAL_24_8 = Annotated[
    Decimal,
    Field(gt=Decimal("0"), max_digits=24, decimal_places=8),
]
NON_NEGATIVE_DECIMAL_24_8 = Annotated[
    Decimal,
    Field(ge=Decimal("0"), max_digits=24, decimal_places=8),
]
# Tehran stock market uses integer share units (no fractional shares)
POSITIVE_INTEGER_SHARES = Annotated[
    int,
    Field(gt=0, description="Number of whole shares (Tehran market: integer only)"),
]


class StrictSchema(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class LedgerTransactionBase(StrictSchema):
    """Base schema for all ledger transactions.

    Tehran Stock Market constraints:
    - quantity: Must be a positive integer (whole shares only)
    - executed_at: Trade execution timestamp
    """

    asset_id: uuid.UUID
    transaction_type: TransactionType
    quantity: POSITIVE_DECIMAL_24_8
    executed_at: datetime
    notes: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def validate_tehran_quantity(self) -> "LedgerTransactionBase":
        """Validate quantity is a whole number for Tehran stock market.

        Tehran Stock Exchange (TSETMC) only allows integer share quantities.
        This validation ensures no fractional shares are traded.
        """
        # For BUY and SELL transactions, quantity must be a whole number
        if self.transaction_type in {TransactionType.BUY, TransactionType.SELL}:
            if self.quantity != int(self.quantity):
                import logging
                logging.getLogger(__name__).warning(
                    "Non-integer quantity %.4f provided for %s transaction on asset %s. "
                    "Tehran market requires whole shares.",
                    float(self.quantity),
                    self.transaction_type.value,
                    self.asset_id,
                )
        return self


class BuyTransactionCreate(LedgerTransactionBase):
    """Buy transaction schema with explicit fee handling.

    Fee Rule: fees INCREASE the acquisition cost.
    total_amount = (quantity × price_per_unit) + fees
    """

    transaction_type: Literal[TransactionType.BUY]
    price_per_unit: POSITIVE_DECIMAL_24_8
    fees: NON_NEGATIVE_DECIMAL_24_8 = Decimal("0")

    @model_validator(mode="after")
    def validate_fee_proportion(self) -> "BuyTransactionCreate":
        """Warn if fees exceed 10% of trade value (unusual but not forbidden)."""
        trade_value = self.quantity * self.price_per_unit
        if trade_value > 0 and self.fees > trade_value * Decimal("0.10"):
            import logging
            logging.getLogger(__name__).warning(
                "Buy fees %.2f exceed 10%% of trade value %.2f for asset %s",
                float(self.fees),
                float(trade_value),
                self.asset_id,
            )
        return self


class SellTransactionCreate(LedgerTransactionBase):
    """Sell transaction schema with explicit fee handling.

    Fee Rule: fees DECREASE the net proceeds.
    total_amount = (quantity × price_per_unit) - fees
    No short selling: sell quantity cannot exceed current holdings.
    """

    transaction_type: Literal[TransactionType.SELL]
    price_per_unit: POSITIVE_DECIMAL_24_8
    fees: NON_NEGATIVE_DECIMAL_24_8 = Decimal("0")

    @model_validator(mode="after")
    def validate_fee_proportion(self) -> "SellTransactionCreate":
        """Warn if fees exceed 10% of trade value (unusual but not forbidden)."""
        trade_value = self.quantity * self.price_per_unit
        if trade_value > 0 and self.fees > trade_value * Decimal("0.10"):
            import logging
            logging.getLogger(__name__).warning(
                "Sell fees %.2f exceed 10%% of trade value %.2f for asset %s",
                float(self.fees),
                float(trade_value),
                self.asset_id,
            )
        return self


class CashDividendTransactionCreate(LedgerTransactionBase):
    transaction_type: Literal[TransactionType.CASH_DIVIDEND]
    dividend_per_unit: POSITIVE_DECIMAL_24_8


class CapitalIncreaseBonusTransactionCreate(LedgerTransactionBase):
    transaction_type: Literal[TransactionType.CAPITAL_INCREASE_BONUS]
    bonus_ratio: POSITIVE_DECIMAL_24_8


class StockSplitTransactionCreate(LedgerTransactionBase):
    transaction_type: Literal[TransactionType.STOCK_SPLIT]
    split_from: int = Field(ge=1)
    split_to: int = Field(ge=1)

    @model_validator(mode="after")
    def validate_split_ratio(self) -> "StockSplitTransactionCreate":
        if self.split_to <= self.split_from:
            raise ValueError("split_to must be greater than split_from")
        return self


class PreEmptiveRightsTransactionCreate(LedgerTransactionBase):
    transaction_type: Literal[TransactionType.PRE_EMPTIVE_RIGHTS]
    rights_ratio: POSITIVE_DECIMAL_24_8
    subscription_price: POSITIVE_DECIMAL_24_8
    fees: NON_NEGATIVE_DECIMAL_24_8 = Decimal("0")


TransactionCreate = BuyTransactionCreate | SellTransactionCreate

LedgerTransactionPayload = (
    BuyTransactionCreate
    | SellTransactionCreate
    | CashDividendTransactionCreate
    | CapitalIncreaseBonusTransactionCreate
    | StockSplitTransactionCreate
    | PreEmptiveRightsTransactionCreate
)

LedgerTransactionCreateRequest = Annotated[
    LedgerTransactionPayload,
    Discriminator("transaction_type"),
]


class TransactionRead(StrictSchema):
    model_config = ConfigDict(
        from_attributes=True,
        extra="forbid",
        json_encoders={Decimal: lambda value: format(value, "f")},
    )

    id: uuid.UUID
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    transaction_type: TransactionType
    quantity: Decimal
    price_per_unit: Decimal
    fees: Decimal
    total_amount: Decimal
    currency: str
    realized_pnl: Decimal
    wac_at_execution: Decimal
    idempotency_key: str
    executed_at: datetime
    created_at: datetime
    notes: str | None


class TransactionFilter(StrictSchema):
    asset_id: uuid.UUID | None = None
    transaction_type: TransactionType | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


class TransactionListResponse(StrictSchema):
    transactions: list[TransactionRead]
    total: int
    limit: int
    offset: int


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
