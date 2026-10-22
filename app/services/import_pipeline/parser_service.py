"""Application service that orchestrates Excel detection and strategy parsing."""

from __future__ import annotations

import io
import logging

import pandas as pd

from app.schemas.import_pipeline import (
    ParseImportResponse,
    PortfolioSnapshotParseResponse,
    PortfolioSnapshotRowResponse,
    TradeLedgerParseResponse,
    TradeLedgerRowResponse,
)
from app.services.import_pipeline.factory import (
    ParserStrategyFactory,
    UnsupportedBrokerFormatError,
)
from app.services.import_pipeline.models import ImportMode, ImportType
from app.services.import_pipeline.normalization import normalize_dataframe_headers

logger = logging.getLogger(__name__)


class EmptyWorkbookError(ValueError):
    """Raised when workbook does not contain parseable rows."""


class UnreadableWorkbookError(ValueError):
    """Raised when uploaded bytes cannot be decoded as an Excel workbook."""


class ExcelImportParserService:
    """Facade over strategy factory and broker-specific parser implementations."""

    def __init__(self, factory: ParserStrategyFactory | None = None) -> None:
        self._factory = factory or ParserStrategyFactory()

    def parse(self, file_bytes: bytes) -> ParseImportResponse:
        df = self._read_excel(file_bytes)
        normalized_df = normalize_dataframe_headers(df)

        strategy = self._factory.resolve(normalized_df)
        result = strategy.parse(normalized_df)
        logger.info(
            "Import parse summary: strategy=%s mode=%s input_rows=%s trade_rows=%s snapshot_rows=%s skipped_rows=%s",
            result.format_name,
            result.import_mode.value,
            len(normalized_df),
            len(result.parsed_trades),
            len(result.parsed_holdings),
            result.skipped_rows,
        )

        if result.import_mode == ImportMode.TRADES:
            return TradeLedgerParseResponse(
                file_type=ImportType.TRADE_LEDGER,
                invalid_rows_count=result.skipped_rows,
                data=[
                    TradeLedgerRowResponse(
                        symbol=row.symbol_normalized,
                        action=row.side,
                        quantity=row.quantity,
                        price=row.unit_price,
                        portfolio_upsert_required=True,
                    )
                    for row in result.parsed_trades
                ],
            )

        return PortfolioSnapshotParseResponse(
            file_type=ImportType.PORTFOLIO_SNAPSHOT,
            invalid_rows_count=result.skipped_rows,
            data=[
                PortfolioSnapshotRowResponse(
                    symbol=row.symbol_normalized,
                    quantity=row.quantity,
                    cost_basis=row.cost_basis,
                    portfolio_upsert_required=True,
                )
                for row in result.parsed_holdings
            ],
        )

    @staticmethod
    def _read_excel(file_bytes: bytes) -> pd.DataFrame:
        try:
            workbook = pd.ExcelFile(io.BytesIO(file_bytes))
        except Exception as ex:  # noqa: BLE001
            raise UnreadableWorkbookError("Workbook is unreadable or corrupted.") from ex
        if not workbook.sheet_names:
            raise EmptyWorkbookError("Workbook has no worksheets.")

        for sheet in workbook.sheet_names:
            df = workbook.parse(sheet_name=sheet, dtype=str)
            if not df.empty:
                return df

        raise EmptyWorkbookError("Workbook has no parseable rows.")


__all__ = [
    "ExcelImportParserService",
    "EmptyWorkbookError",
    "UnreadableWorkbookError",
    "UnsupportedBrokerFormatError",
]
