"""Ledger, valuation, positions, and TWR endpoints with RFC 7807 errors."""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Any, Annotated, cast

from fastapi import APIRouter, Body, Depends, Header, Query, Request, status
from fastapi.responses import JSONResponse
from pydantic import TypeAdapter, ValidationError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import ReconciliationStatus, TransactionType
from app.models.market_data import DailyPrice
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.models.trade_reconciliation import (
    TradeReconciliation,
    TradeReconciliationAllocation,
)
from app.schemas.ledger_api import (
    AssetLedgerResponse,
    AssetPositionResponse,
    AssetValuationPoint,
    AssetValuationSeriesResponse,
    BreakEvenPriceUpdate,
    LedgerEntryRead,
    PaginationQuery,
    PortfolioPositionItem,
    PortfolioPositionsResponse,
    PortfolioTWRResponse,
    ProblemDetails,
    TWRPoint,
)
from app.schemas.transaction import (
    LedgerTransactionCreateRequest,
    LedgerTransactionPayload,
    TransactionRead,
)
from app.services.ledger_domain import LedgerDomainError, problem_type
from app.services.ledger_valuation_service import LedgerValuationService, apply_financial_rule, q8

router = APIRouter()
_payload_adapter: TypeAdapter[LedgerTransactionPayload] = TypeAdapter(LedgerTransactionCreateRequest)
ZERO = Decimal("0.00000000")
ONE = Decimal("1")


def _resolve_break_even_prices(
    *,
    manual_break_even_price: Decimal | None,
    weighted_avg_cost: Decimal,
) -> tuple[Decimal | None, Decimal, Decimal]:
    computed = q8(weighted_avg_cost)
    manual = q8(manual_break_even_price) if manual_break_even_price is not None else None
    effective = manual if manual is not None else computed
    return manual, computed, effective


def _problem_response(problem: ProblemDetails) -> JSONResponse:
    return JSONResponse(
        status_code=problem.status,
        content=problem.model_dump(mode="json"),
        media_type="application/problem+json",
    )


def _validation_problem(request: Request, exc: ValidationError, detail: str) -> JSONResponse:
    errors = []
    for entry in exc.errors():
        field = ".".join(str(token) for token in entry.get("loc", ()) if token not in {"body", "payload"}) or "body"
        errors.append({"field": field, "message": entry.get("msg", "Invalid input")})

    return _problem_response(
        ProblemDetails(
            type=problem_type("validation-error"),
            title="Validation failed",
            status=422,
            detail=detail,
            instance=str(request.url.path),
            errors=errors,
        )
    )


async def _owned_portfolio_or_problem(
    *,
    db: AsyncSession,
    user_id: uuid.UUID,
    portfolio_id: uuid.UUID,
    request: Request,
) -> Portfolio | JSONResponse:
    result = await db.execute(
        select(Portfolio).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_active.is_(True),
        )
    )
    portfolio = result.scalar_one_or_none()
    if portfolio is None:
        return _problem_response(
            ProblemDetails(
                type=problem_type("portfolio-not-found"),
                title="Portfolio not found",
                status=404,
                detail="Portfolio not found.",
                instance=str(request.url.path),
            )
        )
    return portfolio


@router.post(
    "/portfolios/{portfolio_id}/transactions/",
    response_model=TransactionRead,
    status_code=status.HTTP_201_CREATED,
    responses={
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        409: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        422: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def create_transaction(
    portfolio_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key", min_length=8, max_length=128)],
    payload: dict[str, Any] = Body(...),
) -> TransactionRead | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    try:
        command = cast(LedgerTransactionPayload, _payload_adapter.validate_python(payload))
    except ValidationError as exc:
        return _validation_problem(request, exc, "Transaction payload is invalid.")

    service = LedgerValuationService(db)
    try:
        transaction = await service.apply_transaction(
            portfolio_id=portfolio_id,
            payload=command,
            idempotency_key=idempotency_key,
        )
    except LedgerDomainError as exc:
        return _problem_response(
            ProblemDetails(
                type=exc.type,
                title=exc.title,
                status=exc.status,
                detail=exc.detail,
                instance=str(request.url.path),
                errors=exc.errors,
            )
        )

    return TransactionRead.model_validate(transaction)


@router.get(
    "/portfolios/{portfolio_id}/transactions/",
    response_model=AssetLedgerResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def list_transactions(
    portfolio_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    paging: Annotated[PaginationQuery, Depends()],
    asset_id: uuid.UUID | None = Query(default=None),
) -> AssetLedgerResponse | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    base_query = select(Transaction).where(Transaction.portfolio_id == portfolio_id)
    if asset_id is not None:
        base_query = base_query.where(Transaction.asset_id == asset_id)

    total_result = await db.execute(select(func.count()).select_from(base_query.subquery()))
    total = int(total_result.scalar_one())

    rows_query = (
        select(
            Transaction,
            Asset.ticker_symbol,
            Asset.name_fa,
            Asset.name_en,
            Asset.asset_type,
        )
        .join(Asset, Asset.id == Transaction.asset_id)
        .where(Transaction.portfolio_id == portfolio_id)
    )
    if asset_id is not None:
        rows_query = rows_query.where(Transaction.asset_id == asset_id)
    rows_result = await db.execute(
        rows_query
        .order_by(Transaction.executed_at.desc(), Transaction.created_at.desc())
        .limit(paging.limit)
        .offset(paging.offset)
    )
    rows = list(rows_result.all())

    return AssetLedgerResponse(
        items=[
            _to_ledger_entry(
                txn=row[0],
                asset_symbol=row[1],
                asset_name=row[2] or row[3],
                asset_type=row[4].value if row[4] is not None else None,
            )
            for row in rows
        ],
        total=total,
        limit=paging.limit,
        offset=paging.offset,
    )


@router.get(
    "/portfolios/{portfolio_id}/assets/{asset_id}/ledger",
    response_model=AssetLedgerResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def get_asset_ledger(
    portfolio_id: uuid.UUID,
    asset_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    paging: Annotated[PaginationQuery, Depends()],
) -> AssetLedgerResponse | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    base_query = select(Transaction).where(
        Transaction.portfolio_id == portfolio_id,
        Transaction.asset_id == asset_id,
    )
    total_result = await db.execute(select(func.count()).select_from(base_query.subquery()))
    total = int(total_result.scalar_one())

    rows_result = await db.execute(
        select(
            Transaction,
            Asset.ticker_symbol,
            Asset.name_fa,
            Asset.name_en,
            Asset.asset_type,
        )
        .join(Asset, Asset.id == Transaction.asset_id)
        .where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.asset_id == asset_id,
        )
        .order_by(Transaction.executed_at.desc(), Transaction.created_at.desc())
        .limit(paging.limit)
        .offset(paging.offset)
    )
    rows = list(rows_result.all())

    return AssetLedgerResponse(
        items=[
            _to_ledger_entry(
                txn=row[0],
                asset_symbol=row[1],
                asset_name=row[2] or row[3],
                asset_type=row[4].value if row[4] is not None else None,
            )
            for row in rows
        ],
        total=total,
        limit=paging.limit,
        offset=paging.offset,
    )


@router.get(
    "/portfolios/{portfolio_id}/assets/{asset_id}/position",
    response_model=AssetPositionResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def get_asset_position(
    portfolio_id: uuid.UUID,
    asset_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AssetPositionResponse | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    asset_result = await db.execute(
        select(
            Asset.ticker_symbol,
            Asset.name_fa,
            Asset.name_en,
            Asset.asset_type,
        ).where(Asset.id == asset_id)
    )
    asset_row = asset_result.one_or_none()
    if asset_row is None:
        return _problem_response(
            ProblemDetails(
                type=problem_type("asset-not-found"),
                title="Asset not found",
                status=404,
                detail="Asset does not exist.",
                instance=str(request.url.path),
            )
        )

    service = LedgerValuationService(db)
    try:
        valuation = await service.compute_position_valuation(
            portfolio_id=portfolio_id,
            asset_id=asset_id,
        )
    except LedgerDomainError as exc:
        return _problem_response(
            ProblemDetails(
                type=exc.type,
                title=exc.title,
                status=exc.status,
                detail=exc.detail,
                instance=str(request.url.path),
                errors=exc.errors,
            )
        )

    total_pnl = (
        q8(valuation.realized_pnl + valuation.unrealized_pnl)
        if valuation.unrealized_pnl is not None
        else None
    )
    roi = (
        _safe_ratio(numerator=total_pnl, denominator=valuation.total_cost_basis)
        if total_pnl is not None
        else None
    )
    position_result = await db.execute(
        select(AssetPosition.manual_break_even_price).where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.asset_id == asset_id,
        )
    )
    manual_break_even_price = position_result.scalar_one_or_none()
    manual_break_even, computed_break_even, break_even = _resolve_break_even_prices(
        manual_break_even_price=manual_break_even_price,
        weighted_avg_cost=valuation.weighted_avg_cost,
    )
    return AssetPositionResponse(
        portfolio_id=portfolio_id,
        asset_id=asset_id,
        symbol=asset_row[0],
        name=asset_row[1] or asset_row[2],
        asset_type=asset_row[3].value if asset_row[3] is not None else None,
        quantity=valuation.quantity,
        weighted_avg_cost=valuation.weighted_avg_cost,
        total_cost_basis=valuation.total_cost_basis,
        manual_break_even_price=manual_break_even,
        computed_break_even_price=computed_break_even,
        break_even_price=break_even,
        latest_price=valuation.latest_price,
        market_value=valuation.market_value,
        unrealized_pnl=valuation.unrealized_pnl,
        unrealized_pnl_percent=valuation.unrealized_pnl_percent,
        realized_pnl=valuation.realized_pnl,
        total_pnl=total_pnl,
        roi=roi,
        currency=portfolio.base_currency.value,
        last_price_timestamp=valuation.price_date,
        has_market_price=valuation.has_market_price,
        price_source=valuation.price_source,
        price_date=valuation.price_date,
        data_status=valuation.data_status,
        warnings=valuation.warnings,
    )


@router.put(
    "/portfolios/{portfolio_id}/assets/{asset_id}/break-even-price",
    response_model=AssetPositionResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def update_asset_break_even_price(
    portfolio_id: uuid.UUID,
    asset_id: uuid.UUID,
    payload: BreakEvenPriceUpdate,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AssetPositionResponse | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    position_result = await db.execute(
        select(AssetPosition).where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.asset_id == asset_id,
        )
    )
    position = position_result.scalar_one_or_none()
    if position is None:
        return _problem_response(
            ProblemDetails(
                type=problem_type("position-not-found"),
                title="Position not found",
                status=404,
                detail="Asset position does not exist in this portfolio.",
                instance=str(request.url.path),
            )
        )

    position.manual_break_even_price = (
        q8(payload.manual_break_even_price)
        if payload.manual_break_even_price is not None
        else None
    )
    position.last_updated = datetime.now(UTC)
    await db.commit()

    return await get_asset_position(
        portfolio_id=portfolio_id,
        asset_id=asset_id,
        request=request,
        current_user=current_user,
        db=db,
    )


@router.get(
    "/portfolios/{portfolio_id}/assets/{asset_id}/valuation-series",
    response_model=AssetValuationSeriesResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def get_asset_valuation_series(
    portfolio_id: uuid.UUID,
    asset_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: date = Query(...),
    end_date: date = Query(...),
    adjusted_prices: bool = Query(default=True),
) -> AssetValuationSeriesResponse | JSONResponse:
    if end_date < start_date:
        return _problem_response(
            ProblemDetails(
                type=problem_type("invalid-date-range"),
                title="Invalid date range",
                status=422,
                detail="end_date must be greater than or equal to start_date.",
                instance=str(request.url.path),
            )
        )

    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    transaction_rows = await db.execute(
        select(Transaction)
        .where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.asset_id == asset_id,
            Transaction.executed_at <= datetime.combine(end_date, time.max, tzinfo=UTC),
        )
        .order_by(Transaction.executed_at.asc(), Transaction.created_at.asc())
    )
    transactions = list(transaction_rows.scalars().all())

    price_rows_result = await db.execute(
        select(DailyPrice)
        .where(
            DailyPrice.asset_id == asset_id,
            DailyPrice.date <= end_date,
        )
        .order_by(DailyPrice.date.asc())
    )
    price_rows = list(price_rows_result.scalars().all())

    prices_by_day: dict[date, Decimal] = {}
    price_source = "daily_price.adjusted_close" if adjusted_prices else "daily_price.close_price"
    for row in price_rows:
        raw_price = row.adjusted_close if adjusted_prices else row.close_price
        if raw_price is not None and raw_price > ZERO:
            prices_by_day[row.date] = q8(raw_price)

    quantity = ZERO
    total_cost = ZERO
    wac = ZERO
    realized = ZERO
    by_day: dict[date, list[Transaction]] = defaultdict(list)

    for txn in transactions:
        txn_day = txn.executed_at.date()
        by_day[txn_day].append(txn)

    last_price: Decimal | None = None
    last_price_date: date | None = None
    points: list[AssetValuationPoint] = []
    current_day = start_date

    while current_day <= end_date:
        day_events = by_day.get(current_day, [])
        for event in day_events:
            try:
                payload = _payload_from_transaction(event)
                computed = apply_financial_rule(
                    quantity_before=quantity,
                    wac_before=wac,
                    cost_before=total_cost,
                    payload=payload,
                )
            except LedgerDomainError as exc:
                return _problem_response(
                    ProblemDetails(
                        type=exc.type,
                        title=exc.title,
                        status=exc.status,
                        detail=exc.detail,
                        instance=str(request.url.path),
                        errors=exc.errors,
                    )
                )
            quantity = computed.new_quantity
            total_cost = computed.new_total_cost_basis
            wac = computed.new_weighted_avg_cost
            realized = q8(realized + computed.realized_pnl)

        if current_day in prices_by_day:
            last_price = prices_by_day[current_day]
            last_price_date = current_day

        valuation_price = last_price
        market_value = q8(quantity * valuation_price) if valuation_price is not None else None
        unrealized = q8(market_value - total_cost) if market_value is not None else None
        has_market_price = valuation_price is not None

        points.append(
            AssetValuationPoint(
                timestamp=datetime.combine(current_day, time.min, tzinfo=UTC),
                date=current_day,
                quantity=quantity,
                weighted_avg_cost=wac,
                total_cost_basis=total_cost,
                price=valuation_price,
                market_value=market_value,
                unrealized_pnl=unrealized,
                realized_pnl=realized,
                benchmark_value=None,
                has_market_price=has_market_price,
                price_source=price_source if has_market_price else "missing",
                price_date=last_price_date,
                data_status="ok" if has_market_price else "missing_market_price",
                warnings=[] if has_market_price else ["missing_market_price"],
            )
        )
        current_day += timedelta(days=1)

    return AssetValuationSeriesResponse(
        portfolio_id=portfolio_id,
        asset_id=asset_id,
        adjusted_prices=adjusted_prices,
        points=points,
    )


@router.get(
    "/portfolios/{portfolio_id}/positions",
    response_model=PortfolioPositionsResponse,
    responses={
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        409: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_portfolio_positions(
    portfolio_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    as_of_date: date | None = Query(default=None),
) -> PortfolioPositionsResponse | JSONResponse:
    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    portfolio_currency = portfolio.base_currency.value

    rows_result = await db.execute(
        select(
            AssetPosition.asset_id,
            AssetPosition.total_quantity,
            AssetPosition.weighted_avg_cost,
            AssetPosition.total_cost_basis,
            AssetPosition.cumulative_realized_pnl,
            AssetPosition.manual_break_even_price,
            Asset.ticker_symbol,
            Asset.name_fa,
            Asset.name_en,
            Asset.asset_type,
        )
        .join(Asset, Asset.id == AssetPosition.asset_id)
        .where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.total_quantity > ZERO,
        )
        .order_by(AssetPosition.total_cost_basis.desc())
    )
    rows = list(rows_result.all())

    service = LedgerValuationService(db)
    items: list[PortfolioPositionItem] = []
    total_market_value = ZERO
    total_cost_basis = ZERO
    total_unrealized = ZERO
    total_realized = ZERO
    missing_market_price_count = 0
    response_warnings: set[str] = set()

    for row in rows:
        asset_id_row = row[0]
        quantity_raw = row[1]
        weighted_avg_cost_raw = row[2]
        total_cost_basis_raw = row[3]
        cumulative_realized_raw = row[4]
        manual_break_even_raw = row[5]
        symbol = row[6]
        name = row[7] or row[8]
        asset_type = row[9]

        try:
            resolved_price = await service.resolve_position_price(
                asset_id=asset_id_row,
                as_of_date=as_of_date,
            )
        except LedgerDomainError as exc:
            return _problem_response(
                ProblemDetails(
                    type=exc.type,
                    title=exc.title,
                    status=exc.status,
                    detail=exc.detail,
                    instance=str(request.url.path),
                    errors=exc.errors,
                )
            )
        quantity = q8(quantity_raw)
        cost_basis = q8(total_cost_basis_raw)
        realized = q8(cumulative_realized_raw)
        if resolved_price.price is None:
            market_value = None
            unrealized = None
            unrealized_pnl_percent = None
            total_pnl = None
            roi = None
            missing_market_price_count += 1
            response_warnings.update(resolved_price.warnings)
        else:
            market_value = q8(quantity * resolved_price.price)
            unrealized = q8(market_value - cost_basis)
            unrealized_pnl_percent = _safe_ratio(
                numerator=unrealized,
                denominator=cost_basis,
            )
            total_pnl = q8(realized + unrealized)
            roi = _safe_ratio(numerator=total_pnl, denominator=cost_basis)
        manual_break_even, computed_break_even, break_even = _resolve_break_even_prices(
            manual_break_even_price=manual_break_even_raw,
            weighted_avg_cost=weighted_avg_cost_raw,
        )

        if market_value is not None:
            total_market_value = q8(total_market_value + market_value)
        total_cost_basis = q8(total_cost_basis + cost_basis)
        if unrealized is not None:
            total_unrealized = q8(total_unrealized + unrealized)
        total_realized = q8(total_realized + realized)

        items.append(
            PortfolioPositionItem(
                asset_id=asset_id_row,
                ticker_symbol=symbol,
                symbol=symbol,
                name=name,
                asset_type=asset_type.value if asset_type is not None else None,
                quantity=quantity,
                weighted_avg_cost=q8(weighted_avg_cost_raw),
                total_cost_basis=cost_basis,
                manual_break_even_price=manual_break_even,
                computed_break_even_price=computed_break_even,
                break_even_price=break_even,
                latest_price=resolved_price.price,
                market_value=market_value,
                unrealized_pnl=unrealized,
                unrealized_pnl_percent=unrealized_pnl_percent,
                realized_pnl=realized,
                total_pnl=total_pnl,
                roi=roi,
                currency=portfolio_currency,
                last_price_timestamp=resolved_price.price_date,
                has_market_price=resolved_price.has_market_price,
                price_source=resolved_price.source,
                price_date=resolved_price.price_date,
                data_status=("ok" if resolved_price.has_market_price else "missing_market_price"),
                warnings=list(resolved_price.warnings),
            )
        )

    raw_realized_result = await db.execute(
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
    total_realized = q8(
        Decimal(raw_realized_result.scalar_one() or ZERO)
        + Decimal(reconciliation_realized_result.scalar_one() or ZERO)
    )

    valuation_is_partial = missing_market_price_count > 0
    response_total_market_value = None if valuation_is_partial else total_market_value
    response_total_unrealized = None if valuation_is_partial else total_unrealized
    total_pnl = None if valuation_is_partial else q8(total_realized + total_unrealized)
    total_roi = (
        None
        if total_pnl is None
        else _safe_ratio(numerator=total_pnl, denominator=total_cost_basis)
    )

    if missing_market_price_count == len(items) and items:
        portfolio_data_status = "missing_market_price"
    elif valuation_is_partial:
        portfolio_data_status = "partial"
    else:
        portfolio_data_status = "ok"

    return PortfolioPositionsResponse(
        portfolio_id=portfolio_id,
        total_market_value=response_total_market_value,
        total_cost_basis=total_cost_basis,
        total_pnl=total_pnl,
        total_roi=total_roi,
        asset_count=len(items),
        total_unrealized_pnl=response_total_unrealized,
        total_realized_pnl=total_realized,
        missing_market_price_count=missing_market_price_count,
        data_status=portfolio_data_status,
        warnings=sorted(response_warnings),
        items=items,
    )


@router.get(
    "/portfolios/{portfolio_id}/twr",
    response_model=PortfolioTWRResponse,
    responses={404: {"model": ProblemDetails, "content": {"application/problem+json": {}}}},
)
async def get_portfolio_twr(
    portfolio_id: uuid.UUID,
    request: Request,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    start_date: date = Query(...),
    end_date: date = Query(...),
) -> PortfolioTWRResponse | JSONResponse:
    if end_date < start_date:
        return _problem_response(
            ProblemDetails(
                type=problem_type("invalid-date-range"),
                title="Invalid date range",
                status=422,
                detail="end_date must be greater than or equal to start_date.",
                instance=str(request.url.path),
            )
        )

    portfolio = await _owned_portfolio_or_problem(
        db=db,
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        request=request,
    )
    if isinstance(portfolio, JSONResponse):
        return portfolio

    txn_result = await db.execute(
        select(Transaction)
        .where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.executed_at <= datetime.combine(end_date, time.max, tzinfo=UTC),
        )
        .order_by(Transaction.executed_at.asc(), Transaction.created_at.asc())
    )
    transactions = list(txn_result.scalars().all())

    asset_ids = list({txn.asset_id for txn in transactions})
    price_rows: list[DailyPrice] = []
    if asset_ids:
        prices_result = await db.execute(
            select(DailyPrice)
            .where(
                DailyPrice.asset_id.in_(asset_ids),
                DailyPrice.date <= end_date,
            )
            .order_by(DailyPrice.asset_id.asc(), DailyPrice.date.asc())
        )
        price_rows = list(prices_result.scalars().all())

    price_by_asset_day: dict[uuid.UUID, dict[date, Decimal]] = defaultdict(dict)
    for row in price_rows:
        price_by_asset_day[row.asset_id][row.date] = q8(row.adjusted_close)

    events_by_day: dict[date, list[Transaction]] = defaultdict(list)
    for txn in transactions:
        events_by_day[txn.executed_at.date()].append(txn)

    quantity_by_asset: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
    cost_by_asset: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
    wac_by_asset: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)
    cash_flow_by_day: dict[date, Decimal] = defaultdict(lambda: ZERO)
    last_price_by_asset: dict[uuid.UUID, Decimal] = defaultdict(lambda: ZERO)

    cumulative_twr = ONE
    prev_value = ZERO
    points: list[TWRPoint] = []

    day = start_date
    while day <= end_date:
        day_events = events_by_day.get(day, [])
        net_flow = ZERO

        for event in day_events:
            try:
                payload = _payload_from_transaction(event)
                computed = apply_financial_rule(
                    quantity_before=quantity_by_asset[event.asset_id],
                    wac_before=wac_by_asset[event.asset_id],
                    cost_before=cost_by_asset[event.asset_id],
                    payload=payload,
                )
            except LedgerDomainError as exc:
                return _problem_response(
                    ProblemDetails(
                        type=exc.type,
                        title=exc.title,
                        status=exc.status,
                        detail=exc.detail,
                        instance=str(request.url.path),
                        errors=exc.errors,
                    )
                )
            quantity_by_asset[event.asset_id] = computed.new_quantity
            cost_by_asset[event.asset_id] = computed.new_total_cost_basis
            wac_by_asset[event.asset_id] = computed.new_weighted_avg_cost

            if event.transaction_type in {
                TransactionType.BUY,
                TransactionType.PRE_EMPTIVE_RIGHTS,
            }:
                net_flow = q8(net_flow + computed.total_amount)
            elif event.transaction_type == TransactionType.SELL:
                net_flow = q8(net_flow - computed.total_amount)

        cash_flow_by_day[day] = net_flow

        portfolio_value = ZERO
        for asset_id, qty in quantity_by_asset.items():
            if day in price_by_asset_day.get(asset_id, {}):
                last_price_by_asset[asset_id] = price_by_asset_day[asset_id][day]
            price = last_price_by_asset[asset_id]
            portfolio_value = q8(portfolio_value + q8(qty * price))

        denominator = q8(prev_value + net_flow)
        if denominator > ZERO:
            period_return = q8((portfolio_value - denominator) / denominator)
            cumulative_twr = q8(cumulative_twr * (ONE + period_return))
        else:
            period_return = ZERO

        points.append(
            TWRPoint(
                date=day,
                portfolio_value=portfolio_value,
                net_cash_flow=net_flow,
                period_return=period_return,
                cumulative_twr=q8(cumulative_twr - ONE),
            )
        )

        prev_value = portfolio_value
        day += timedelta(days=1)

    return PortfolioTWRResponse(
        portfolio_id=portfolio_id,
        start_date=start_date,
        end_date=end_date,
        points=points,
    )


def _payload_from_transaction(txn: Transaction) -> LedgerTransactionPayload:
    executed_at = txn.executed_at
    notes = txn.notes

    if txn.transaction_type == TransactionType.BUY:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "BUY",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "price_per_unit": str(txn.price_per_unit),
                "fees": str(txn.fees),
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    if txn.transaction_type == TransactionType.SELL:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "SELL",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "price_per_unit": str(txn.price_per_unit),
                "fees": str(txn.fees),
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    if txn.transaction_type == TransactionType.CASH_DIVIDEND:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "CASH_DIVIDEND",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "dividend_per_unit": str(txn.price_per_unit),
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    if txn.transaction_type == TransactionType.CAPITAL_INCREASE_BONUS:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "CAPITAL_INCREASE_BONUS",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "bonus_ratio": "1",
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    if txn.transaction_type == TransactionType.STOCK_SPLIT:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "CAPITAL_INCREASE_BONUS",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "bonus_ratio": "1",
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    if txn.transaction_type == TransactionType.PRE_EMPTIVE_RIGHTS:
        return _payload_adapter.validate_python(
            {
                "transaction_type": "PRE_EMPTIVE_RIGHTS",
                "asset_id": str(txn.asset_id),
                "quantity": str(txn.quantity),
                "rights_ratio": "1",
                "subscription_price": str(txn.price_per_unit),
                "fees": str(txn.fees),
                "executed_at": executed_at.isoformat(),
                "notes": notes,
            }
        )

    raise LedgerDomainError(
        type=problem_type("unsupported-transaction-type"),
        title="Unsupported transaction",
        status=422,
        detail=f"Unsupported transaction_type={txn.transaction_type.value}",
    )


def _to_ledger_entry(
    *,
    txn: Transaction,
    asset_symbol: str,
    asset_name: str | None,
    asset_type: str | None,
) -> LedgerEntryRead:
    commission = q8(txn.fees)
    tax = ZERO
    net_amount = q8(txn.total_amount)
    cash_flow = _transaction_cash_flow(txn=txn, net_amount=net_amount)
    return LedgerEntryRead(
        id=txn.id,
        portfolio_id=txn.portfolio_id,
        asset_id=txn.asset_id,
        asset_symbol=asset_symbol,
        asset_name=asset_name,
        asset_type=asset_type,
        transaction_type=txn.transaction_type,
        quantity=q8(txn.quantity),
        price_per_unit=q8(txn.price_per_unit),
        commission=commission,
        fees=q8(txn.fees),
        tax=tax,
        total_amount=q8(txn.total_amount),
        net_amount=net_amount,
        cash_flow=cash_flow,
        realized_pnl=q8(txn.realized_pnl),
        wac_at_execution=q8(txn.wac_at_execution),
        currency=txn.currency,
        executed_at=txn.executed_at,
        notes=txn.notes,
    )


def _transaction_cash_flow(*, txn: Transaction, net_amount: Decimal) -> Decimal:
    if txn.transaction_type in {
        TransactionType.BUY,
        TransactionType.PRE_EMPTIVE_RIGHTS,
    }:
        return q8(-net_amount)
    if txn.transaction_type in {
        TransactionType.SELL,
        TransactionType.CASH_DIVIDEND,
    }:
        return net_amount
    return ZERO


def _safe_ratio(*, numerator: Decimal, denominator: Decimal) -> Decimal:
    if denominator <= ZERO:
        return ZERO
    return q8(numerator / denominator)
