"""Market Watch crawler for normalized TSETMC latest quotes."""

from __future__ import annotations

import logging
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from decimal import Decimal

from app.core import market_cache
from app.repositories.market_data import MarketDataRepository
from app.services.market_provider import (
    MarketDataProvider,
    MarketIndex,
    MarketInstrument,
    MarketOverview,
    MarketQuote,
)
from app.services.market_normalizers import TSETMCNormalizer, normalize_market_symbol

logger = logging.getLogger("market_watch_crawler")
ZERO = Decimal("0")


@dataclass(slots=True)
class MarketWatchCrawlerReport:
    source: str
    started_at: datetime
    finished_at: datetime
    records_received: int
    records_valid: int
    records_inserted: int
    records_updated: int
    errors_count: int
    status: str
    last_success_at: datetime | None = None
    suspicious_reason: str | None = None
    indices_synced: int = 0
    overview_synced: bool = False
    error_message: str | None = None
    instruments_upserted: int = 0


class MarketWatchCrawler:
    def __init__(
        self,
        *,
        provider: MarketDataProvider,
        repository: MarketDataRepository,
        min_expected_records: int = 100,
        suspicious_drop_ratio: float = 0.25,
    ) -> None:
        self._provider = provider
        self._repository = repository
        self._min_expected_records = min_expected_records
        self._suspicious_drop_ratio = Decimal(str(suspicious_drop_ratio))

    async def run(self) -> MarketWatchCrawlerReport:
        started_at = datetime.now(UTC)
        status = "success"
        errors: list[str] = []
        suspicious_reason: str | None = None
        records_inserted = 0
        records_updated = 0
        valid_quotes: list[MarketQuote] = []
        records_received = 0
        indices_synced = 0
        overview_synced = False
        instruments_upserted = 0

        try:
            snapshot = await self._provider.get_market_snapshot()
            records_received = len(snapshot.quotes)
            valid_quotes = self._validate_quotes(snapshot.quotes)

            suspicious_reason = self._suspicious_reason(records_received, len(valid_quotes))
            if suspicious_reason is not None:
                status = "suspicious"
                errors.append(suspicious_reason)
            elif valid_quotes:
                instruments_upserted = await self._repository.upsert_instruments(
                    self._instruments_from_quotes(valid_quotes),
                )
                records_inserted = await self._repository.upsert_market_quotes(valid_quotes)
                records_updated = await self._repository.update_assets_from_market_quotes(
                    valid_quotes,
                )
                await self._repository.commit()
                resolved_quotes = await self._resolve_unlinked_asset_quotes()
                if resolved_quotes:
                    records_received += len(resolved_quotes)
                    valid_quotes.extend(resolved_quotes)
                    instruments_upserted += await self._repository.upsert_instruments(
                        self._instruments_from_quotes(resolved_quotes),
                    )
                    records_inserted += await self._repository.upsert_market_quotes(resolved_quotes)
                    records_updated += await self._repository.update_assets_from_market_quotes(
                        resolved_quotes,
                    )
                    await self._repository.commit()
                await self._safe_refresh_quote_cache(valid_quotes, errors)
                indices = await self._provider.get_indices()
                overview = await self._provider.get_market_overview()
                if indices:
                    indices_synced = await self._repository.upsert_indices(indices)
                    await self._safe_refresh_indices_cache(indices, errors)
                if overview is not None:
                    await self._repository.upsert_market_overview(overview)
                    await self._safe_refresh_overview_cache(overview, errors)
                    overview_synced = True
                await self._repository.commit()
            else:
                status = "empty"
                errors.append("No valid market-watch quotes")
        except Exception as exc:
            status = "error"
            errors.append(str(exc))
            try:
                await self._repository.rollback()
            except Exception:
                pass

        finished_at = datetime.now(UTC)
        last_success_at = finished_at if status == "success" else None
        report = MarketWatchCrawlerReport(
            source="TSETMC",
            started_at=started_at,
            finished_at=finished_at,
            records_received=records_received,
            records_valid=len(valid_quotes),
            records_inserted=records_inserted,
            records_updated=records_updated,
            errors_count=len(errors),
            status=status,
            last_success_at=last_success_at,
            suspicious_reason=suspicious_reason,
            indices_synced=indices_synced,
            overview_synced=overview_synced,
            error_message="; ".join(errors) or None,
            instruments_upserted=instruments_upserted,
        )
        try:
            await self._repository.record_ingestion_run(
                source=report.source,
                provider=self._provider.name,
                run_type="market_watch",
                started_at=report.started_at,
                finished_at=report.finished_at,
                status=report.status,
                records_received=report.records_received,
                records_valid=report.records_valid,
                records_inserted=report.records_inserted,
                records_updated=report.records_updated,
                errors_count=report.errors_count,
                last_success_at=report.last_success_at,
                error_message=report.error_message,
                metadata_json={
                    "suspicious_reason": suspicious_reason,
                    "provider": self._provider.name,
                    "indices_synced": indices_synced,
                    "overview_synced": overview_synced,
                    "instruments_upserted": instruments_upserted,
                },
            )
            await self._repository.commit()
        except Exception as exc:
            logger.warning("market_watch.ingestion_run_record_failed error=%s", exc)

        logger.info(
            "market_watch.complete status=%s received=%d valid=%d instruments=%d inserted=%d asset_updates=%d errors=%d duration_ms=%.1f",
            report.status,
            report.records_received,
            report.records_valid,
            report.instruments_upserted,
            report.records_inserted,
            report.records_updated,
            report.errors_count,
            (report.finished_at - report.started_at).total_seconds() * 1000,
        )
        return report

    async def _safe_refresh_quote_cache(
        self,
        quotes: list[MarketQuote],
        errors: list[str],
    ) -> None:
        try:
            await market_cache.bulk_cache_market_quotes(quotes, publish_stream=True)
            await market_cache.cache_market_watch_snapshot(quotes)
        except Exception as exc:
            logger.warning("market_watch.quote_cache_refresh_failed error=%s", exc)
            errors.append(f"quote_cache_refresh_failed: {exc}")

    async def _safe_refresh_indices_cache(
        self,
        indices: list[MarketIndex],
        errors: list[str],
    ) -> None:
        try:
            await market_cache.cache_market_indices(indices)
        except Exception as exc:
            logger.warning("market_watch.indices_cache_refresh_failed error=%s", exc)
            errors.append(f"indices_cache_refresh_failed: {exc}")

    async def _safe_refresh_overview_cache(
        self,
        overview: MarketOverview,
        errors: list[str],
    ) -> None:
        try:
            await market_cache.cache_normalized_market_overview(overview)
        except Exception as exc:
            logger.warning("market_watch.overview_cache_refresh_failed error=%s", exc)
            errors.append(f"overview_cache_refresh_failed: {exc}")

    def _instruments_from_quotes(self, quotes: list[MarketQuote]) -> list[MarketInstrument]:
        instruments: dict[str, MarketInstrument] = {}
        for quote in quotes:
            instrument_id = quote.instrument_id.strip()
            symbol = normalize_market_symbol(quote.symbol)
            if not instrument_id or not symbol:
                continue
            instruments[instrument_id] = MarketInstrument(
                instrument_id=instrument_id,
                ins_code=instrument_id,
                symbol=symbol,
                market="TSETMC",
                is_active=True,
            )
        return list(instruments.values())

    async def _resolve_unlinked_asset_quotes(self) -> list[MarketQuote]:
        resolver = getattr(self._provider, "resolve_instrument_id", None)
        if not callable(resolver):
            return []
        assets = await self._repository.list_unlinked_active_tsetmc_assets()
        resolved: list[MarketQuote] = []
        for asset in assets:
            symbol = normalize_market_symbol(asset.normalized_symbol or asset.ticker_symbol)
            if not symbol:
                continue
            instrument_id = await resolver(symbol)
            if not instrument_id:
                continue
            snapshot = await self._provider.fetch_live_market_snapshot(instrument_id)
            if snapshot is None or snapshot.close_price <= ZERO:
                continue
            resolved.append(
                replace(
                    TSETMCNormalizer.quote_from_snapshot(snapshot),
                    symbol=symbol,
                    instrument_id=instrument_id,
                )
            )
        return resolved

    def _validate_quotes(self, quotes: list[MarketQuote]) -> list[MarketQuote]:
        valid: list[MarketQuote] = []
        for quote in quotes:
            if not quote.instrument_id or not quote.symbol:
                continue
            if quote.closing_price is None or quote.closing_price < ZERO:
                continue
            if quote.last_price is not None and quote.last_price < ZERO:
                continue
            if quote.last_price is None:
                continue
            if quote.volume < 0 or quote.trade_count < 0:
                continue
            if quote.value is not None and quote.value < ZERO:
                continue
            valid.append(quote)
        return valid

    def _suspicious_reason(self, records_received: int, records_valid: int) -> str | None:
        if records_received < self._min_expected_records:
            return f"record_count_below_minimum received={records_received} minimum={self._min_expected_records}"
        if records_valid == 0:
            return "no_valid_quotes"
        valid_ratio = Decimal(records_valid) / Decimal(records_received)
        if valid_ratio < self._suspicious_drop_ratio:
            return f"valid_ratio_too_low valid={records_valid} received={records_received}"
        return None
