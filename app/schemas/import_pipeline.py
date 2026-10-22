"""Typed request/response schemas for strategy-driven Excel parsing API."""

from __future__ import annotations

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.services.import_pipeline.models import ImportType, TradeAction


class TradeLedgerRowResponse(BaseModel):
    """Serialized trade row for frontend ingestion."""

    model_config = ConfigDict(extra="forbid")

    symbol: str = Field(min_length=1)
    action: TradeAction
    quantity: Decimal = Field(gt=0)
    price: Decimal = Field(gt=0)
    portfolio_upsert_required: bool = True


class PortfolioSnapshotRowResponse(BaseModel):
    """Serialized portfolio snapshot row for frontend ingestion."""

    model_config = ConfigDict(extra="forbid")

    symbol: str = Field(min_length=1)
    quantity: Decimal = Field(gt=0)
    cost_basis: Decimal = Field(ge=0)
    portfolio_upsert_required: bool = True


class TradeLedgerParseResponse(BaseModel):
    """Success payload for TRADE_LEDGER file types."""

    model_config = ConfigDict(extra="forbid")

    status: Literal["success"] = "success"
    file_type: Literal[ImportType.TRADE_LEDGER] = ImportType.TRADE_LEDGER
    data: list[TradeLedgerRowResponse]
    invalid_rows_count: int = Field(default=0, ge=0)


class PortfolioSnapshotParseResponse(BaseModel):
    """Success payload for PORTFOLIO_SNAPSHOT file types."""

    model_config = ConfigDict(extra="forbid")

    status: Literal["success"] = "success"
    file_type: Literal[ImportType.PORTFOLIO_SNAPSHOT] = ImportType.PORTFOLIO_SNAPSHOT
    data: list[PortfolioSnapshotRowResponse]
    invalid_rows_count: int = Field(default=0, ge=0)


ParseImportResponse = TradeLedgerParseResponse | PortfolioSnapshotParseResponse
