"""CLI helper for full TSETMC market-watch ingestion.

Use this instead of app.services.market_sync.run_full_sync when the goal is
to fetch the whole exchange snapshot. run_full_sync only syncs assets that
already exist locally and already have a tsetmc_id.

Windows example:

    .myenv\\Scripts\\python.exe -m app.services.full_market_sync --pretty
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory
from app.models.asset import Asset
from app.models.market_data import Instrument, MarketQuote
from app.repositories.market_data import MarketDataRepository
from app.services.market_provider import MarketProviderConfig
from app.services.market_watch_crawler import MarketWatchCrawler, MarketWatchCrawlerReport
from app.services.tsetmc_provider import TSETMCProvider


DEFAULT_MIN_EXPECTED_RECORDS = 500
IRAN_TZ = timezone(timedelta(hours=3, minutes=30), "Asia/Tehran")


def _provider_config() -> MarketProviderConfig:
    return MarketProviderConfig(
        base_url=settings.TSETMC_BASE_URL,
        request_timeout=settings.TSETMC_REQUEST_TIMEOUT,
        connect_timeout=settings.TSETMC_CONNECT_TIMEOUT,
        max_concurrent=settings.TSETMC_MAX_CONCURRENT,
        retry_attempts=settings.TSETMC_RETRY_ATTEMPTS,
        retry_base_delay=settings.TSETMC_RETRY_BASE_DELAY,
        retry_max_delay=settings.TSETMC_RETRY_MAX_DELAY,
        retry_backoff_multiplier=settings.TSETMC_RETRY_BACKOFF_MULTIPLIER,
        circuit_breaker_failure_threshold=settings.TSETMC_CIRCUIT_BREAKER_FAILURE_THRESHOLD,
        circuit_breaker_reset_seconds=settings.TSETMC_CIRCUIT_BREAKER_RESET_SECONDS,
    )


async def _count(db: AsyncSession, statement: Any) -> int:
    return int(await db.scalar(statement) or 0)


async def _unlinked_asset_symbols(db: AsyncSession, *, limit: int = 50) -> list[str]:
    rows = await db.execute(
        select(Asset.ticker_symbol)
        .where(
            Asset.is_active.is_(True),
            Asset.exchange == "TSETMC",
            Asset.tsetmc_id.is_(None),
        )
        .order_by(Asset.ticker_symbol.asc())
        .limit(limit)
    )
    return [str(item).strip() for item in rows.scalars().all() if str(item).strip()]


async def _assets_missing_market_price_symbols(
    db: AsyncSession,
    *,
    limit: int = 50,
) -> list[str]:
    rows = await db.execute(
        select(Asset.ticker_symbol)
        .where(
            Asset.is_active.is_(True),
            Asset.exchange == "TSETMC",
            or_(
                Asset.price_updated_at.is_(None),
                Asset.last_trade_price <= 0,
                Asset.closing_price <= 0,
            ),
        )
        .order_by(Asset.ticker_symbol.asc())
        .limit(limit)
    )
    return [str(item).strip() for item in rows.scalars().all() if str(item).strip()]


async def _diagnostics(db: AsyncSession) -> dict[str, Any]:
    return {
        "active_tsetmc_assets": await _count(
            db,
            select(func.count())
            .select_from(Asset)
            .where(Asset.is_active.is_(True), Asset.exchange == "TSETMC"),
        ),
        "linked_tsetmc_assets": await _count(
            db,
            select(func.count())
            .select_from(Asset)
            .where(
                Asset.is_active.is_(True),
                Asset.exchange == "TSETMC",
                Asset.tsetmc_id.isnot(None),
            ),
        ),
        "unlinked_tsetmc_assets": await _count(
            db,
            select(func.count())
            .select_from(Asset)
            .where(
                Asset.is_active.is_(True),
                Asset.exchange == "TSETMC",
                Asset.tsetmc_id.is_(None),
            ),
        ),
        "stored_active_instruments": await _count(
            db,
            select(func.count())
            .select_from(Instrument)
            .where(Instrument.is_active.is_(True)),
        ),
        "stored_quote_instruments": await _count(
            db,
            select(func.count(func.distinct(MarketQuote.instrument_id))),
        ),
        "unlinked_tsetmc_asset_symbols": await _unlinked_asset_symbols(db),
        "assets_missing_market_price_symbols": await _assets_missing_market_price_symbols(db),
    }


def _report_payload(
    report: MarketWatchCrawlerReport,
    diagnostics: dict[str, Any],
) -> dict[str, Any]:
    return {
        "status": report.status,
        "source": report.source,
        "started_at": report.started_at,
        "finished_at": report.finished_at,
        "records_received": report.records_received,
        "records_valid": report.records_valid,
        "quotes_upserted": report.records_inserted,
        "assets_updated": report.records_updated,
        "instruments_upserted": report.instruments_upserted,
        "indices_synced": report.indices_synced,
        "overview_synced": report.overview_synced,
        "errors_count": report.errors_count,
        "suspicious_reason": report.suspicious_reason,
        "error_message": report.error_message,
        **diagnostics,
    }


def _json_default(value: Any) -> str | int | float | None:
    if isinstance(value, datetime):
        return value.astimezone(IRAN_TZ).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return str(value) if value is not None else None


async def run_full_market_sync(
    *,
    min_expected_records: int = DEFAULT_MIN_EXPECTED_RECORDS,
    suspicious_drop_ratio: float = 0.25,
) -> dict[str, Any]:
    async with async_session_factory() as db:
        repository = MarketDataRepository(db)
        async with TSETMCProvider(_provider_config()) as provider:
            crawler = MarketWatchCrawler(
                provider=provider,
                repository=repository,
                min_expected_records=min_expected_records,
                suspicious_drop_ratio=suspicious_drop_ratio,
            )
            report = await crawler.run()
        diagnostics = await _diagnostics(db)
    return _report_payload(report, diagnostics)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fetch and persist the full TSETMC market-watch snapshot, "
            "derived instruments, indices, overview, and asset prices."
        )
    )
    parser.add_argument(
        "--min-expected-records",
        type=int,
        default=DEFAULT_MIN_EXPECTED_RECORDS,
        help=(
            "Reject persistence as suspicious if TSETMC returns fewer records "
            f"than this value. Default: {DEFAULT_MIN_EXPECTED_RECORDS}."
        ),
    )
    parser.add_argument(
        "--suspicious-drop-ratio",
        type=float,
        default=0.25,
        help="Reject persistence when valid/received ratio is below this value.",
    )
    parser.add_argument(
        "--allow-suspicious",
        action="store_true",
        help="Return exit code 0 for suspicious runs after printing the report.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(list(argv or []))
    payload = asyncio.run(
        run_full_market_sync(
            min_expected_records=args.min_expected_records,
            suspicious_drop_ratio=args.suspicious_drop_ratio,
        )
    )
    print(
        json.dumps(
            payload,
            ensure_ascii=False,
            default=_json_default,
            indent=2 if args.pretty else None,
            sort_keys=True,
        )
    )
    if payload["status"] == "error":
        return 1
    if payload["status"] == "suspicious" and not args.allow_suspicious:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
