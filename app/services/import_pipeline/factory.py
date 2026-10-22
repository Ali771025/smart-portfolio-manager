"""Factory for resolving broker parser strategies."""

from __future__ import annotations

import pandas as pd

from app.services.import_pipeline.normalization import normalize_dataframe_headers
from app.services.import_pipeline.strategies import (
    AghahLedgerStrategy,
    BaseImportStrategy,
    BoursiranSnapshotStrategy,
    MofidLedgerStrategy,
)


class ImportPipelineError(ValueError):
    """Base error class for broker import parsing pipeline."""


class UnsupportedBrokerFormatError(ImportPipelineError):
    """Raised when no parser strategy can identify the sheet signature."""


class ParserStrategyFactory:
    """Open/Closed strategy resolver; add new brokers without changing callers."""

    def __init__(self, strategies: list[BaseImportStrategy] | None = None) -> None:
        self._strategies = strategies or [
            AghahLedgerStrategy(),
            MofidLedgerStrategy(),
            BoursiranSnapshotStrategy(),
        ]

    def resolve(self, df: pd.DataFrame) -> BaseImportStrategy:
        normalized = normalize_dataframe_headers(df)
        sample_rows = normalized.head(5).to_dict(orient="records")
        columns = set(normalized.columns)
        for strategy in self._strategies:
            if strategy.can_handle(columns, sample_rows):
                return strategy
        raise UnsupportedBrokerFormatError(
            "Unsupported broker format: no matching strategy signature found."
        )
