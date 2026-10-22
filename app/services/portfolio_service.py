"""Portfolio read-service layer: summaries, live valuation, and asset ledger details."""

from __future__ import annotations

import logging
import re
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from types import SimpleNamespace

import jdatetime
from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import ReconciliationStatus, TransactionType
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.models.trade_reconciliation import (
    TradeReconciliation,
    TradeReconciliationAllocation,
)
from app.schemas.portfolio import (
    AssetPositionSummary,
    PortfolioSummary,
    PortfolioSummaryResponse,
    PositionWithMarketData,
    ProblemDetails,
    TradeHistoryItem,
    TradeHistoryPaginated,
)
from app.services.market_price_service import MarketPriceService, SelectedMarketPrice

logger = logging.getLogger(__name__)

ZERO = Decimal("0.0000")
HUNDRED = Decimal("100")
FOUR_PLACES = Decimal("0.0001")
PROBLEM_BASE_URL = "https://smartportfolio.local/problems"
ARABIC_TO_PERSIAN_TICKER_MAP = str.maketrans(
    {
        "ي": "ی",
        "ى": "ی",
        "ك": "ک",
    }
)
TICKER_MARKS_RE = re.compile(r"[\u200c\u200d\u200e\u200f\ufeff\s]+")
ASCII_SYMBOL_RE = re.compile(r"[^A-Z0-9]+")
LOOKUP_TOKEN_SPLIT_RE = re.compile(r"[\s\-_./()]+")
TRAILING_DIGITS_RE = re.compile(r"\d+$")
PERSIAN_TO_LATIN_TICKER_MAP: dict[str, str] = {
    "ا": "A",
    "آ": "A",
    "ب": "B",
    "پ": "P",
    "ت": "T",
    "ث": "S",
    "ج": "J",
    "چ": "CH",
    "ح": "H",
    "خ": "KH",
    "د": "D",
    "ذ": "Z",
    "ر": "R",
    "ز": "Z",
    "ژ": "ZH",
    "س": "S",
    "ش": "SH",
    "ص": "S",
    "ض": "Z",
    "ط": "T",
    "ظ": "Z",
    "ع": "A",
    "غ": "GH",
    "ف": "F",
    "ق": "GH",
    "ک": "K",
    "گ": "G",
    "ل": "L",
    "م": "M",
    "ن": "N",
    "و": "O",
    "ه": "H",
    "ی": "I",
}


@dataclass(slots=True, frozen=True)
class PortfolioPositionRow:
    portfolio_id: uuid.UUID
    asset_id: uuid.UUID
    quantity: Decimal
    average_buy_price: Decimal
    total_cost_basis: Decimal
    db_price: Decimal | None
    closing_price: Decimal | None
    previous_close_price: Decimal
    last_market_update: datetime | None


@dataclass(slots=True, frozen=True)
class AssetLedgerContext:
    asset_id: uuid.UUID
    ticker: str
    db_price: Decimal


def quantize4(value: Decimal) -> Decimal:
    """Normalize decimals to NUMERIC(18,4) precision."""

    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


def safe_percent(numerator: Decimal, denominator: Decimal) -> Decimal:
    """Return percentage with zero-division protection."""

    if denominator <= ZERO:
        return ZERO
    try:
        return quantize4((numerator / denominator) * HUNDRED)
    except (InvalidOperation, ZeroDivisionError):
        return ZERO


def _merge_quality(current: str, incoming: str) -> str:
    order = {
        "unknown": 0,
        "current": 1,
        "fallback": 2,
        "stale": 3,
        "missing": 4,
    }
    return incoming if order.get(incoming, 0) > order.get(current, 0) else current


def raise_problem(
    *,
    status_code: int,
    title: str,
    detail: str,
    instance: str,
    type_slug: str,
) -> None:
    """Raise RFC 7807 problem details as HTTPException detail payload."""

    problem = ProblemDetails(
        type=f"{PROBLEM_BASE_URL}/{type_slug}",
        title=title,
        status=status_code,
        detail=detail,
        instance=instance,
    )
    raise HTTPException(status_code=status_code, detail=problem.model_dump())


def _normalize_ticker(ticker: str, *, instance: str) -> str:
    normalized = ticker.strip().upper()
    if not normalized:
        raise_problem(
            status_code=status.HTTP_400_BAD_REQUEST,
            title="Invalid Ticker",
            detail="Ticker must not be empty.",
            instance=instance,
            type_slug="invalid-ticker",
        )
    return normalized


def _normalize_ticker_for_lookup(value: str) -> str:
    """Canonicalize Persian/Arabic ticker variants and remove hidden marks/spaces."""

    normalized = value.translate(ARABIC_TO_PERSIAN_TICKER_MAP)
    normalized = TICKER_MARKS_RE.sub("", normalized)
    return normalized


def _normalize_ascii_symbol(value: str) -> str:
    normalized = TICKER_MARKS_RE.sub("", value.upper())
    return ASCII_SYMBOL_RE.sub("", normalized)


def _normalize_lookup_key(value: str) -> str:
    ascii_key = _normalize_ascii_symbol(value)
    if ascii_key:
        return ascii_key
    return _romanize_ticker_for_lookup(value)


def _romanize_ticker_for_lookup(value: str) -> str:
    """Convert Persian ticker/name variants into an uppercase latin lookup key."""

    normalized = _normalize_ticker_for_lookup(value)
    parts: list[str] = []
    for char in normalized:
        mapped = PERSIAN_TO_LATIN_TICKER_MAP.get(char)
        if mapped is not None:
            parts.append(mapped)
            continue
        if "A" <= char <= "Z" or "0" <= char <= "9":
            parts.append(char)
            continue
        if "a" <= char <= "z":
            parts.append(char.upper())
    return _normalize_ascii_symbol("".join(parts))


def _latin_consonant_key(value: str) -> str:
    normalized = _normalize_ascii_symbol(value)
    return "".join(char for char in normalized if char not in {"A", "E", "I", "O", "U"})


def _add_lookup_key_variants(keys: set[str], value: str) -> None:
    normalized_ascii = _normalize_ascii_symbol(value)
    if normalized_ascii:
        keys.add(normalized_ascii)
        without_suffix = TRAILING_DIGITS_RE.sub("", normalized_ascii)
        if without_suffix:
            keys.add(without_suffix)

    romanized = _romanize_ticker_for_lookup(value)
    if romanized:
        keys.add(romanized)
        without_suffix = TRAILING_DIGITS_RE.sub("", romanized)
        if without_suffix:
            keys.add(without_suffix)


def _candidate_lookup_keys(*values: str | None) -> set[str]:
    keys: set[str] = set()
    for value in values:
        if not value:
            continue
        _add_lookup_key_variants(keys, value)
        tokens = [
            token
            for token in LOOKUP_TOKEN_SPLIT_RE.split(_normalize_ticker_for_lookup(value))
            if token
        ]
        for token in tokens:
            _add_lookup_key_variants(keys, token)
    return keys


def _lookup_key_matches_candidate(candidate_keys: set[str], lookup_key: str) -> bool:
    if lookup_key in candidate_keys:
        return True

    if len(lookup_key) >= 4 and any(
        candidate_key.startswith(lookup_key) for candidate_key in candidate_keys
    ):
        return True

    lookup_consonants = _latin_consonant_key(lookup_key)
    if len(lookup_consonants) < 3:
        return False

    candidate_consonants = {
        _latin_consonant_key(candidate_key)
        for candidate_key in candidate_keys
        if candidate_key
    }
    if lookup_consonants in candidate_consonants:
        return True

    return any(
        candidate_consonants_key.startswith(lookup_consonants)
        for candidate_consonants_key in candidate_consonants
    )


def _sql_normalize_ticker_for_lookup(column):
    """
    Build SQL expression mirroring `_normalize_ticker_for_lookup`.

    Using REPLACE keeps this portable across SQLite and Postgres.
    """

    normalized = func.replace(column, "ي", "ی")
    normalized = func.replace(normalized, "ى", "ی")
    normalized = func.replace(normalized, "ك", "ک")
    normalized = func.replace(normalized, " ", "")
    normalized = func.replace(normalized, "\u200c", "")
    normalized = func.replace(normalized, "\u200d", "")
    normalized = func.replace(normalized, "\u200e", "")
    normalized = func.replace(normalized, "\u200f", "")
    normalized = func.replace(normalized, "\ufeff", "")
    return func.upper(normalized)


async def list_portfolio_summaries(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> list[PortfolioSummary]:
    """
    Return all active portfolios with live-value summary.

    Performance profile:
      - Query #1: active portfolios
      - Query #2: all open positions for those portfolios (single set-based join)
      - Redis: one MGET pipeline for all held assets
    """

    portfolios_result = await db.execute(
        select(Portfolio)
        .where(
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
        .order_by(Portfolio.created_at.desc())
    )
    portfolios = list(portfolios_result.scalars().all())
    if not portfolios:
        return []

    portfolio_ids = [portfolio.id for portfolio in portfolios]

    positions_result = await db.execute(
        select(
            AssetPosition.portfolio_id,
            AssetPosition.asset_id,
            AssetPosition.total_quantity,
            AssetPosition.weighted_avg_cost,
            AssetPosition.total_cost_basis,
            Asset.ticker_symbol,
            Asset.tsetmc_id,
            Asset.last_trade_price,
            Asset.closing_price,
            Asset.previous_close_price,
            Asset.price_updated_at,
            Asset.is_tradeable,
        )
        .join(Asset, Asset.id == AssetPosition.asset_id)
        .where(
            AssetPosition.portfolio_id.in_(portfolio_ids),
            AssetPosition.total_quantity > ZERO,
        )
    )

    position_rows = [
        PortfolioPositionRow(
            portfolio_id=row.portfolio_id,
            asset_id=row.asset_id,
            quantity=quantize4(row.total_quantity or ZERO),
            average_buy_price=quantize4(row.weighted_avg_cost or ZERO),
            total_cost_basis=quantize4(
                (row.weighted_avg_cost or ZERO) * (row.total_quantity or ZERO)
            ),
            db_price=row.last_trade_price,
            closing_price=row.closing_price,
            previous_close_price=quantize4(row.previous_close_price or ZERO),
            last_market_update=row.price_updated_at,
        )
        for row in positions_result.all()
    ]

    invested_by_portfolio: dict[uuid.UUID, Decimal] = {
        portfolio_id: ZERO for portfolio_id in portfolio_ids
    }
    current_value_by_portfolio: dict[uuid.UUID, Decimal] = {
        portfolio_id: ZERO for portfolio_id in portfolio_ids
    }
    closing_value_by_portfolio: dict[uuid.UUID, Decimal] = {
        portfolio_id: ZERO for portfolio_id in portfolio_ids
    }
    daily_pnl_by_portfolio: dict[uuid.UUID, Decimal] = {
        portfolio_id: ZERO for portfolio_id in portfolio_ids
    }
    unrealized_by_portfolio: dict[uuid.UUID, Decimal] = {
        portfolio_id: ZERO for portfolio_id in portfolio_ids
    }
    last_market_update_by_portfolio: dict[uuid.UUID, datetime | None] = {
        portfolio_id: None for portfolio_id in portfolio_ids
    }
    missing_price_count_by_portfolio: dict[uuid.UUID, int] = {
        portfolio_id: 0 for portfolio_id in portfolio_ids
    }
    stale_price_count_by_portfolio: dict[uuid.UUID, int] = {
        portfolio_id: 0 for portfolio_id in portfolio_ids
    }
    market_status_by_portfolio: dict[uuid.UUID, str] = {
        portfolio_id: "unknown" for portfolio_id in portfolio_ids
    }
    data_quality_by_portfolio: dict[uuid.UUID, str] = {
        portfolio_id: "unknown" for portfolio_id in portfolio_ids
    }

    price_service = MarketPriceService()
    for row in position_rows:
        selected = price_service.select(
            asset_id=row.asset_id,
            symbol="",
            instrument_id=None,
            last_price=row.db_price,
            closing_price=row.closing_price,
            yesterday_price=row.previous_close_price,
            price_as_of=row.last_market_update,
            use_case="live",
        )
        live_value = (
            quantize4(row.quantity * selected.selected_valuation_price)
            if selected.selected_valuation_price is not None
            else ZERO
        )
        closing_value = (
            quantize4(row.quantity * selected.closing_price)
            if selected.closing_price is not None
            else ZERO
        )
        daily_pnl = (
            quantize4(row.quantity * (selected.selected_valuation_price - row.previous_close_price))
            if selected.selected_valuation_price is not None and row.previous_close_price > ZERO
            else ZERO
        )

        invested_by_portfolio[row.portfolio_id] = quantize4(
            invested_by_portfolio[row.portfolio_id] + row.total_cost_basis
        )
        current_value_by_portfolio[row.portfolio_id] = quantize4(
            current_value_by_portfolio[row.portfolio_id] + live_value
        )
        closing_value_by_portfolio[row.portfolio_id] = quantize4(
            closing_value_by_portfolio[row.portfolio_id] + closing_value
        )
        daily_pnl_by_portfolio[row.portfolio_id] = quantize4(
            daily_pnl_by_portfolio[row.portfolio_id] + daily_pnl
        )
        if selected.selected_valuation_price is not None:
            unrealized_by_portfolio[row.portfolio_id] = quantize4(
                unrealized_by_portfolio[row.portfolio_id] + (live_value - row.total_cost_basis)
            )
        if row.last_market_update is not None:
            current_last_update = last_market_update_by_portfolio[row.portfolio_id]
            if current_last_update is None or row.last_market_update > current_last_update:
                last_market_update_by_portfolio[row.portfolio_id] = row.last_market_update
        if selected.selected_valuation_price is None:
            missing_price_count_by_portfolio[row.portfolio_id] += 1
        if selected.is_stale and selected.selected_valuation_price is not None:
            stale_price_count_by_portfolio[row.portfolio_id] += 1
        market_status_by_portfolio[row.portfolio_id] = selected.market_status
        data_quality_by_portfolio[row.portfolio_id] = _merge_quality(
            data_quality_by_portfolio[row.portfolio_id],
            selected.data_quality_status,
        )

    summaries: list[PortfolioSummary] = []
    for portfolio in portfolios:
        invested_capital = invested_by_portfolio.get(portfolio.id, ZERO)
        current_value = current_value_by_portfolio.get(portfolio.id, ZERO)
        unrealized_pnl = unrealized_by_portfolio.get(portfolio.id, ZERO)
        roi_percent = safe_percent(unrealized_pnl, invested_capital)

        summaries.append(
            PortfolioSummary(
                id=portfolio.id,
                name=portfolio.name,
                portfolio_id=portfolio.id,
                portfolio_name=portfolio.name,
                base_currency=portfolio.base_currency,
                total_invested_capital=invested_capital,
                total_current_value=current_value,
                current_price=current_value,
                closing_price=closing_value_by_portfolio.get(portfolio.id, ZERO),
                daily_pnl=daily_pnl_by_portfolio.get(portfolio.id, ZERO),
                total_unrealized_pnl=unrealized_pnl,
                last_market_update=last_market_update_by_portfolio.get(portfolio.id),
                roi_percent=roi_percent,
                missing_price_count=missing_price_count_by_portfolio.get(portfolio.id, 0),
                stale_price_count=stale_price_count_by_portfolio.get(portfolio.id, 0),
                market_status=market_status_by_portfolio.get(portfolio.id, "unknown"),
                data_quality_status=data_quality_by_portfolio.get(portfolio.id, "unknown"),
            )
        )

    return summaries


async def delete_portfolio(
    db: AsyncSession,
    user_id: uuid.UUID,
    portfolio_id: uuid.UUID,
) -> None:
    """Soft-delete an active portfolio owned by the user."""

    result = await db.execute(
        update(Portfolio)
        .where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
        .values(is_active=False)
    )
    if result.rowcount == 0:
        raise_problem(
            status_code=status.HTTP_404_NOT_FOUND,
            title="Portfolio Not Found",
            detail="Portfolio not found.",
            instance=f"/api/v1/portfolios/{portfolio_id}",
            type_slug="portfolio-not-found",
        )

    await db.commit()


async def get_asset_ledger_details(
    db: AsyncSession,
    user_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    ticker: str,
    *,
    limit: int,
    offset: int,
) -> TradeHistoryPaginated:
    """Return asset position summary + paginated ledger for one ticker."""

    instance = f"/api/v1/portfolios/{portfolio_id}/assets/{ticker}"
    normalized_ticker = _normalize_ticker(ticker, instance=instance)

    portfolio_result = await db.execute(
        select(Portfolio.id).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
    )
    if portfolio_result.scalar_one_or_none() is None:
        raise_problem(
            status_code=status.HTTP_404_NOT_FOUND,
            title="Portfolio Not Found",
            detail="Portfolio not found.",
            instance=instance,
            type_slug="portfolio-not-found",
        )

    async def _resolve_portfolio_candidate_by_ascii_lookup(
        lookup_key: str,
        *,
        exclude_asset_id: uuid.UUID | None = None,
    ):
        transaction_candidates_result = await db.execute(
            select(
                Asset.id.label("asset_id"),
                Asset.ticker_symbol.label("ticker"),
                Asset.name_fa.label("name_fa"),
                Asset.name_en.label("name_en"),
                Asset.last_trade_price.label("db_price"),
            )
            .join(Transaction, Transaction.asset_id == Asset.id)
            .where(Transaction.portfolio_id == portfolio_id)
            .group_by(
                Asset.id,
                Asset.ticker_symbol,
                Asset.name_fa,
                Asset.name_en,
                Asset.last_trade_price,
            )
            .order_by(func.count(Transaction.id).desc(), Asset.ticker_symbol.asc())
        )
        for candidate in transaction_candidates_result:
            if exclude_asset_id is not None and candidate.asset_id == exclude_asset_id:
                continue
            candidate_keys = _candidate_lookup_keys(
                candidate.ticker,
                candidate.name_fa,
                candidate.name_en,
            )
            if _lookup_key_matches_candidate(candidate_keys, lookup_key):
                return candidate

        position_candidates_result = await db.execute(
            select(
                Asset.id.label("asset_id"),
                Asset.ticker_symbol.label("ticker"),
                Asset.name_fa.label("name_fa"),
                Asset.name_en.label("name_en"),
                Asset.last_trade_price.label("db_price"),
            )
            .join(AssetPosition, AssetPosition.asset_id == Asset.id)
            .where(AssetPosition.portfolio_id == portfolio_id)
            .group_by(
                Asset.id,
                Asset.ticker_symbol,
                Asset.name_fa,
                Asset.name_en,
                Asset.last_trade_price,
            )
            .order_by(
                func.sum(AssetPosition.total_quantity).desc(),
                Asset.ticker_symbol.asc(),
            )
        )
        for candidate in position_candidates_result:
            if exclude_asset_id is not None and candidate.asset_id == exclude_asset_id:
                continue
            candidate_keys = _candidate_lookup_keys(
                candidate.ticker,
                candidate.name_fa,
                candidate.name_en,
            )
            if _lookup_key_matches_candidate(candidate_keys, lookup_key):
                return candidate

        return None

    asset_lookup_stmt = select(
        Asset.id.label("asset_id"),
        Asset.ticker_symbol.label("ticker"),
        Asset.last_trade_price.label("db_price"),
    ).limit(1)

    asset_result = await db.execute(
        asset_lookup_stmt.where(func.upper(Asset.ticker_symbol) == normalized_ticker)
    )
    asset_row = asset_result.first()
    if asset_row is None:
        normalized_lookup_ticker = _normalize_ticker_for_lookup(normalized_ticker)
        relaxed_result = await db.execute(
            asset_lookup_stmt.where(
                _sql_normalize_ticker_for_lookup(Asset.ticker_symbol)
                == normalized_lookup_ticker
            )
        )
        asset_row = relaxed_result.first()
    normalized_lookup_key = _normalize_lookup_key(normalized_ticker)
    if asset_row is None and normalized_lookup_key:
        asset_row = await _resolve_portfolio_candidate_by_ascii_lookup(
            normalized_lookup_key
        )
    if asset_row is None:
        if normalized_lookup_key:
            global_candidates_result = await db.execute(
                select(
                    Asset.id.label("asset_id"),
                    Asset.ticker_symbol.label("ticker"),
                    Asset.name_fa.label("name_fa"),
                    Asset.name_en.label("name_en"),
                    Asset.last_trade_price.label("db_price"),
                ).order_by(Asset.ticker_symbol.asc())
            )
            for candidate in global_candidates_result:
                candidate_keys = _candidate_lookup_keys(
                    candidate.ticker,
                    candidate.name_fa,
                    candidate.name_en,
                )
                if _lookup_key_matches_candidate(candidate_keys, normalized_lookup_key):
                    asset_row = candidate
                    break
    if asset_row is None:
        return TradeHistoryPaginated(
            asset_summary=AssetPositionSummary(
                portfolio_id=portfolio_id,
                ticker=normalized_ticker,
                current_quantity=ZERO,
                average_buy_price=ZERO,
                current_live_price=ZERO,
                asset_pnl=ZERO,
            ),
            transactions=[],
            total=0,
            limit=limit,
            offset=offset,
        )

    asset_ctx = AssetLedgerContext(
        asset_id=asset_row.asset_id,
        ticker=asset_row.ticker,
        db_price=quantize4(asset_row.db_price or ZERO),
    )

    count_result = await db.execute(
        select(func.count(Transaction.id)).where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.asset_id == asset_ctx.asset_id,
        )
    )
    total = int(count_result.scalar_one() or 0)

    async def _load_position_snapshot(asset_id: uuid.UUID):
        position_result = await db.execute(
            select(
                AssetPosition.total_quantity,
                AssetPosition.weighted_avg_cost,
                AssetPosition.total_cost_basis,
            ).where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset_id,
            )
        )
        return position_result.one_or_none()

    position_row = await _load_position_snapshot(asset_ctx.asset_id)

    if total == 0:
        # If duplicate ticker variants exist, prefer the asset that actually has
        # trades in this portfolio.
        normalized_lookup_ticker = _normalize_ticker_for_lookup(normalized_ticker)
        preferred_asset_result = await db.execute(
            select(
                Asset.id.label("asset_id"),
                Asset.ticker_symbol.label("ticker"),
                Asset.last_trade_price.label("db_price"),
            )
            .join(Transaction, Transaction.asset_id == Asset.id)
            .where(
                Transaction.portfolio_id == portfolio_id,
                _sql_normalize_ticker_for_lookup(Asset.ticker_symbol)
                == normalized_lookup_ticker,
            )
            .group_by(Asset.id, Asset.ticker_symbol, Asset.last_trade_price)
            .order_by(func.count(Transaction.id).desc())
            .limit(1)
        )
        preferred_asset_row = preferred_asset_result.first()
        if preferred_asset_row is not None and preferred_asset_row.asset_id != asset_ctx.asset_id:
            asset_ctx = AssetLedgerContext(
                asset_id=preferred_asset_row.asset_id,
                ticker=preferred_asset_row.ticker,
                db_price=quantize4(preferred_asset_row.db_price or ZERO),
            )
            total_result = await db.execute(
                select(func.count(Transaction.id)).where(
                    Transaction.portfolio_id == portfolio_id,
                    Transaction.asset_id == asset_ctx.asset_id,
                )
            )
            total = int(total_result.scalar_one() or 0)
            position_row = await _load_position_snapshot(asset_ctx.asset_id)

    if total == 0 and position_row is None and normalized_lookup_key:
        fallback_row = await _resolve_portfolio_candidate_by_ascii_lookup(
            normalized_lookup_key,
            exclude_asset_id=asset_ctx.asset_id,
        )
        if fallback_row is not None:
            asset_ctx = AssetLedgerContext(
                asset_id=fallback_row.asset_id,
                ticker=fallback_row.ticker,
                db_price=quantize4(fallback_row.db_price or ZERO),
            )
            fallback_total_result = await db.execute(
                select(func.count(Transaction.id)).where(
                    Transaction.portfolio_id == portfolio_id,
                    Transaction.asset_id == asset_ctx.asset_id,
                )
            )
            total = int(fallback_total_result.scalar_one() or 0)
            position_row = await _load_position_snapshot(asset_ctx.asset_id)

    current_live_price = asset_ctx.db_price

    current_quantity = quantize4(position_row.total_quantity if position_row else ZERO)
    average_buy_price = quantize4(position_row.weighted_avg_cost if position_row else ZERO)

    asset_pnl = quantize4((current_live_price - average_buy_price) * current_quantity)

    trades_result = await db.execute(
        select(Transaction)
        .where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.asset_id == asset_ctx.asset_id,
        )
        .order_by(Transaction.executed_at.desc(), Transaction.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    trades = list(trades_result.scalars().all())

    transactions = [
        TradeHistoryItem(
            date_jalali=jdatetime.datetime.fromgregorian(
                datetime=trade.executed_at
            ).strftime("%Y/%m/%d"),
            trade_type=trade.transaction_type,
            quantity=quantize4(trade.quantity),
            unit_price=quantize4(trade.price_per_unit),
            total_trade_value=quantize4(trade.total_amount),
        )
        for trade in trades
    ]

    return TradeHistoryPaginated(
        asset_summary=AssetPositionSummary(
            portfolio_id=portfolio_id,
            ticker=asset_ctx.ticker,
            current_quantity=current_quantity,
            average_buy_price=average_buy_price,
            current_live_price=current_live_price,
            asset_pnl=asset_pnl,
        ),
        transactions=transactions,
        total=total,
        limit=limit,
        offset=offset,
    )


async def get_portfolio_summary(
    db: AsyncSession,
    portfolio_id: uuid.UUID,
    user_id: uuid.UUID,
) -> PortfolioSummaryResponse:
    """Fetch live macro-level portfolio valuation and PnL metrics.

    Uses MarketPersistenceService for freshness-aware price resolution:
      - Redis cache for fast reads
      - DB fallback when cache unavailable
      - Freshness metadata for staleness detection
    """
    instance = f"/api/v1/portfolios/{portfolio_id}/summary"

    portfolio_result = await db.execute(
        select(Portfolio).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise_problem(
            status_code=status.HTTP_404_NOT_FOUND,
            title="Portfolio Not Found",
            detail="Portfolio not found.",
            instance=instance,
            type_slug="portfolio-not-found",
        )

    positions_result = await db.execute(
        select(
            AssetPosition,
            Asset,
        )
        .join(Asset, Asset.id == AssetPosition.asset_id)
        .where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.total_quantity > ZERO,
        )
        .order_by(AssetPosition.total_cost_basis.desc())
    )
    active_rows = positions_result.all()

    total_invested_value = ZERO
    total_current_value = ZERO
    total_daily_pnl = ZERO
    total_unrealized_known = ZERO
    active_positions: list[PositionWithMarketData] = []
    missing_price_assets: list[str] = []
    stale_price_assets: list[str] = []
    suspended_assets: list[str] = []
    oldest_price_time: datetime | None = None
    latest_market_update: datetime | None = None
    market_status = "unknown"
    data_quality_status = "current"
    price_service = MarketPriceService()

    for row in active_rows:
        position: AssetPosition = row[0]
        asset: Asset = row[1]
        ticker_symbol = asset.ticker_symbol
        asset_name = asset.name_fa
        previous_close = quantize4(asset.previous_close_price or ZERO)
        selected = price_service.select_from_asset(asset, use_case="live")
        current_price = selected.selected_valuation_price
        last_updated = selected.price_as_of
        market_status = selected.market_status
        data_quality_status = _merge_quality(data_quality_status, selected.data_quality_status)
        price_change = (
            quantize4(current_price - previous_close)
            if current_price is not None and previous_close > ZERO
            else None
        )
        price_change_percent = (
            safe_percent(price_change, previous_close)
            if price_change is not None and previous_close > ZERO
            else None
        )

        # Track freshness per position
        if current_price is None:
            missing_price_assets.append(ticker_symbol)
        elif selected.is_stale:
            stale_price_assets.append(ticker_symbol)

        if not asset.is_tradeable:
            suspended_assets.append(ticker_symbol)

        # Track oldest price for portfolio-level freshness
        if last_updated is not None:
            if oldest_price_time is None or last_updated < oldest_price_time:
                oldest_price_time = last_updated
            if latest_market_update is None or last_updated > latest_market_update:
                latest_market_update = last_updated

        position_invested_value = quantize4(
            position.weighted_avg_cost * position.total_quantity
        )
        current_market_value = (
            quantize4(position.total_quantity * current_price)
            if current_price is not None
            else ZERO
        )
        daily_pnl = (
            quantize4(price_change * position.total_quantity)
            if price_change is not None
            else ZERO
        )
        unrealized_pnl = (
            quantize4(current_market_value - position_invested_value)
            if current_price is not None
            else ZERO
        )
        unrealized_pnl_pct = safe_percent(unrealized_pnl, position_invested_value)

        total_invested_value = quantize4(total_invested_value + position_invested_value)
        total_current_value = quantize4(total_current_value + current_market_value)
        total_daily_pnl = quantize4(total_daily_pnl + daily_pnl)
        total_unrealized_known = quantize4(total_unrealized_known + unrealized_pnl)

        # Calculate freshness seconds
        data_freshness_seconds = None
        if last_updated is not None:
            now_utc = datetime.now(UTC)
            if last_updated.tzinfo is None:
                last_updated = last_updated.replace(tzinfo=UTC)
            data_freshness_seconds = int((now_utc - last_updated).total_seconds())

        active_positions.append(
            PositionWithMarketData(
                id=position.id,
                asset_id=position.asset_id,
                portfolio_id=position.portfolio_id,
                total_quantity=position.total_quantity,
                weighted_avg_cost=position.weighted_avg_cost,
                total_cost_basis=position.total_cost_basis,
                cumulative_realized_pnl=position.cumulative_realized_pnl,
                trade_count=position.trade_count,
                last_updated=position.last_updated,
                ticker_symbol=ticker_symbol,
                asset_name=asset_name,
                current_price=current_price or ZERO,
                quantity=position.total_quantity,
                average_cost=position.weighted_avg_cost,
                total_cost=position_invested_value,
                last_price=selected.last_price,
                closing_price=selected.closing_price,
                price_change=price_change,
                price_change_percent=price_change_percent,
                last_updated_at=last_updated,
                current_market_value=current_market_value,
                selected_valuation_price=selected.selected_valuation_price,
                selected_price_source=selected.selected_price_source,
                market_value=current_market_value if current_price is not None else None,
                daily_pnl=daily_pnl,
                unrealized_pnl=unrealized_pnl,
                unrealized_pnl_pct=unrealized_pnl_pct,
                weight_pct=ZERO,
                price_timestamp=last_updated,
                is_price_fresh=not selected.is_stale and selected.selected_valuation_price is not None,
                data_freshness_seconds=data_freshness_seconds,
                is_tradeable=asset.is_tradeable,
                price_as_of=selected.price_as_of,
                is_stale=selected.is_stale,
                is_current_session=selected.is_current_session,
                status=selected.status,
            )
        )

    total_unrealized_pnl = total_unrealized_known
    total_unrealized_pnl_pct = safe_percent(total_unrealized_pnl, total_invested_value)

    realized_result = await db.execute(
        select(func.coalesce(func.sum(Transaction.realized_pnl), ZERO)).where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.transaction_type == TransactionType.SELL,
        )
    )
    reconciliation_realized_result = await db.execute(
        select(
            func.coalesce(func.sum(TradeReconciliationAllocation.realized_pnl), ZERO)
        )
        .join(
            TradeReconciliation,
            TradeReconciliation.id == TradeReconciliationAllocation.reconciliation_id,
        )
        .where(
            TradeReconciliation.destination_portfolio_id == portfolio_id,
            TradeReconciliation.status == ReconciliationStatus.CONFIRMED,
        )
    )
    total_realized_pnl = quantize4(
        Decimal(realized_result.scalar_one() or ZERO)
        + Decimal(reconciliation_realized_result.scalar_one() or ZERO)
    )
    total_pnl = quantize4(total_realized_pnl + total_unrealized_pnl)
    roi_pct = safe_percent(total_pnl, total_invested_value)

    trades_result = await db.execute(
        select(func.coalesce(func.sum(AssetPosition.trade_count), 0)).where(
            AssetPosition.portfolio_id == portfolio_id
        )
    )
    total_trades_count = int(trades_result.scalar_one() or 0)

    weighted_positions: list[PositionWithMarketData] = []
    for position in active_positions:
        position_weight = safe_percent(position.current_market_value, total_current_value)
        weighted_positions.append(
            position.model_copy(update={"weight_pct": position_weight})
        )

    # Calculate portfolio-level freshness
    data_freshness_seconds = None
    if oldest_price_time is not None:
        now_utc = datetime.now(UTC)
        if oldest_price_time.tzinfo is None:
            oldest_price_time = oldest_price_time.replace(tzinfo=UTC)
        data_freshness_seconds = int((now_utc - oldest_price_time).total_seconds())

    is_valuation_partial = bool(missing_price_assets or stale_price_assets)

    return PortfolioSummaryResponse(
        portfolio_id=portfolio.id,
        portfolio_name=portfolio.name,
        base_currency=portfolio.base_currency,
        total_current_value=total_current_value,
        total_market_value=total_current_value,
        total_invested_value=total_invested_value,
        total_cost_basis=total_invested_value,
        total_unrealized_pnl=total_unrealized_pnl,
        daily_pnl=total_daily_pnl,
        total_unrealized_pnl_pct=total_unrealized_pnl_pct,
        total_realized_pnl=total_realized_pnl,
        total_pnl=total_pnl,
        roi_pct=roi_pct,
        active_positions_count=len(weighted_positions),
        holdings_count=len(weighted_positions),
        missing_price_count=len(set(missing_price_assets)),
        stale_price_count=len(set(stale_price_assets)),
        total_trades_count=total_trades_count,
        positions=weighted_positions,
        # Freshness metadata
        is_valuation_partial=is_valuation_partial,
        missing_price_assets=sorted(set(missing_price_assets)),
        stale_price_assets=sorted(set(stale_price_assets)),
        suspended_assets=sorted(set(suspended_assets)),
        data_freshness_seconds=data_freshness_seconds,
        last_price_update_at=latest_market_update,
        last_market_update=latest_market_update,
        valuation_as_of=datetime.now(UTC),
        as_of=datetime.now(UTC),
        market_status=market_status,
        data_quality_status=(
            "missing" if missing_price_assets and len(missing_price_assets) == len(weighted_positions)
            else "partial" if missing_price_assets
            else data_quality_status
        ),
    )
