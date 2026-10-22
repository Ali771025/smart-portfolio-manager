"""Portfolio CRUD, summary, and position endpoints."""

import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import JSONResponse, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import CurrentUser, get_pnl_calculator_service
from app.models.portfolio import Portfolio
from app.schemas.pnl import AssetPnLBreakdown, PortfolioPnLSummaryResponse
from app.schemas.portfolio import (
    PortfolioCreate,
    PortfolioRead,
    PortfolioSummary,
    PortfolioSummaryResponse,
    PositionWithMarketData,
    ProblemDetails,
    TradeHistoryPaginated,
)
from app.schemas.portfolio_api import (
    PortfolioHoldingApiItem,
    PortfolioHoldingsApiResponse,
    PortfolioSummaryApiResponse,
)
from app.schemas.imports import ImportRefreshStatusResponse
from app.services.pnl_calculator import PnLCalculatorService
from app.services.portfolio_service import (
    delete_portfolio as delete_portfolio_service,
    get_asset_ledger_details,
    list_portfolio_summaries,
    quantize4,
)
from app.api.v1.imports import get_portfolio_refresh_status as get_import_refresh_status

router = APIRouter()
ZERO = Decimal("0")


def _nullable_percent(numerator: Decimal, denominator: Decimal) -> Decimal | None:
    if denominator == ZERO:
        return None
    return (numerator / denominator) * Decimal("100")


def _holding_price_source(asset: AssetPnLBreakdown) -> str | None:
    if asset.current_price is None:
        return None
    source = (asset.selected_price_source or "").lower()
    if source == "last_price":
        return "asset.last_trade_price"
    if source in {"closing_price", "fallback"}:
        return "asset.closing_price"
    if source == "final_price":
        return "asset.current_price"
    return asset.current_price_source if asset.current_price_source not in {"", "MISSING"} else source or None


def _holding_api_item(
    asset: AssetPnLBreakdown,
    *,
    currency,
) -> PortfolioHoldingApiItem:
    warnings = list(asset.warnings)
    if asset.data_status == "missing_market_price" and "missing_market_price" not in warnings:
        warnings.append("missing_market_price")
    elif asset.data_status == "stale_market_price" and "outdated_market_price" not in warnings:
        warnings.append("outdated_market_price")

    has_market_price = asset.current_price is not None and asset.market_value is not None
    average_cost = asset.average_cost if asset.average_cost is not None else asset.weighted_avg_cost
    cost_basis = asset.remaining_cost_basis if asset.remaining_cost_basis is not None else asset.total_cost
    total_pnl = asset.total_pnl if has_market_price else None
    total_pnl_percent = _nullable_percent(total_pnl, cost_basis) if total_pnl is not None else None

    return PortfolioHoldingApiItem(
        asset_id=asset.asset_id,
        symbol=asset.symbol or asset.ticker_symbol,
        name=asset.name,
        quantity=asset.quantity,
        average_cost=average_cost,
        weighted_avg_cost=asset.weighted_avg_cost,
        cost_basis=cost_basis,
        current_price=asset.current_price,
        latest_price=asset.current_price,
        market_value=asset.market_value,
        unrealized_pnl=asset.unrealized_pnl if has_market_price else None,
        unrealized_pnl_percent=asset.unrealized_pnl_percent if has_market_price and cost_basis != ZERO else None,
        realized_pnl=asset.realized_pnl,
        total_pnl=total_pnl,
        total_pnl_percent=total_pnl_percent,
        roi=total_pnl_percent,
        price_date=asset.current_price_date or asset.price_as_of,
        price_source=_holding_price_source(asset),
        has_market_price=has_market_price,
        is_price_stale=asset.is_stale if has_market_price else None,
        calculation_status=("complete" if has_market_price else "missing_market_price"),
        data_status=asset.data_status,
        warnings=warnings,
        currency=currency,
    )


def _summary_api_response(summary: PortfolioPnLSummaryResponse) -> PortfolioSummaryApiResponse:
    warnings = sorted({warning for asset in summary.assets for warning in asset.warnings} | set(summary.sanity_flags))
    missing_symbols = sorted(set(summary.missing_price_assets))
    has_missing = bool(missing_symbols)
    if has_missing and "missing_market_prices" not in warnings:
        warnings.append("missing_market_prices")
        warnings.sort()
    holdings_count = summary.holdings_count
    priced_holdings_count = max(holdings_count - len(missing_symbols), 0)
    total_cost_basis = summary.total_cost_basis if summary.total_cost_basis is not None else summary.total_invested
    total_market_value = (
        summary.total_market_value
        if summary.total_market_value is not None
        else summary.total_current_value
    )
    total_pnl = summary.total_realized_pnl + summary.total_unrealized_pnl
    total_pnl_percent = _nullable_percent(total_pnl, total_cost_basis)
    return PortfolioSummaryApiResponse(
        portfolio_id=summary.portfolio_id,
        currency=summary.base_currency,
        total_cost_basis=total_cost_basis,
        total_market_value=total_market_value,
        total_unrealized_pnl=summary.total_unrealized_pnl,
        total_unrealized_pnl_percent=(
            _nullable_percent(summary.total_unrealized_pnl, total_cost_basis)
            if total_cost_basis != ZERO
            else None
        ),
        total_realized_pnl=summary.total_realized_pnl,
        realized_pnl=summary.total_realized_pnl,
        unrealized_pnl=summary.total_unrealized_pnl,
        total_pnl=total_pnl,
        total_pnl_percent=total_pnl_percent,
        roi=total_pnl_percent,
        total_portfolio_value=summary.total_portfolio_value,
        cash_balance=summary.total_cash_balance,
        holdings_count=holdings_count,
        missing_market_price_count=summary.missing_market_price_count,
        priced_holdings_count=priced_holdings_count,
        missing_price_count=len(missing_symbols),
        missing_price_symbols=missing_symbols,
        has_missing_market_prices=has_missing,
        calculation_status="partial" if has_missing else "complete",
        warnings=warnings,
    )


def _position_from_asset_pnl(
    asset: AssetPnLBreakdown,
    *,
    portfolio_id,
) -> PositionWithMarketData:
    market_value = asset.market_value or asset.current_value
    return PositionWithMarketData(
        id=asset.asset_id,
        asset_id=asset.asset_id,
        portfolio_id=portfolio_id,
        total_quantity=asset.quantity,
        weighted_avg_cost=asset.average_cost or asset.weighted_avg_cost,
        total_cost_basis=asset.remaining_cost_basis or asset.total_cost,
        cumulative_realized_pnl=asset.realized_pnl,
        trade_count=0,
        last_updated=asset.current_price_date or asset.price_as_of or datetime.now(UTC),
        ticker_symbol=asset.symbol or asset.ticker_symbol,
        asset_name=asset.symbol or asset.ticker_symbol,
        current_price=asset.current_price or asset.live_price,
        quantity=asset.quantity,
        average_cost=asset.average_cost or asset.weighted_avg_cost,
        total_cost=asset.remaining_cost_basis or asset.total_cost,
        last_price=asset.last_price,
        closing_price=asset.closing_price,
        price_change=asset.daily_change,
        price_change_percent=asset.daily_change_percent,
        last_updated_at=asset.current_price_date or asset.price_as_of,
        current_market_value=market_value or 0,
        selected_valuation_price=asset.selected_valuation_price,
        selected_price_source=asset.current_price_source or asset.selected_price_source,
        market_value=asset.market_value,
        daily_pnl=asset.daily_change or 0,
        unrealized_pnl=asset.unrealized_pnl,
        unrealized_pnl_pct=asset.unrealized_pnl_percent,
        weight_pct=asset.weight,
        price_timestamp=asset.price_timestamp,
        is_price_fresh=asset.is_price_fresh,
        data_freshness_seconds=asset.data_freshness_seconds,
        is_tradeable=asset.is_tradeable,
        price_as_of=asset.price_as_of,
        is_stale=asset.is_stale,
        is_current_session=asset.is_current_session,
        status=asset.status,
    )


def _legacy_summary_response(summary: PortfolioPnLSummaryResponse) -> PortfolioSummaryResponse:
    positions = [
        _position_from_asset_pnl(asset, portfolio_id=summary.portfolio_id)
        for asset in summary.assets
    ]
    return PortfolioSummaryResponse(
        portfolio_id=summary.portfolio_id,
        portfolio_name=summary.portfolio_name or "",
        base_currency=summary.base_currency,
        total_current_value=summary.total_market_value or summary.total_current_value,
        total_market_value=summary.total_market_value or summary.total_current_value,
        total_invested_value=summary.total_cost_basis or summary.total_invested,
        total_cost_basis=summary.total_cost_basis or summary.total_invested,
        total_unrealized_pnl=summary.total_unrealized_pnl,
        daily_pnl=0,
        total_unrealized_pnl_pct=summary.unrealized_pnl_percent,
        total_realized_pnl=summary.total_realized_pnl,
        total_pnl=summary.total_pnl,
        roi_pct=summary.roi_percent,
        active_positions_count=summary.holdings_count,
        holdings_count=summary.holdings_count,
        missing_price_count=summary.missing_market_price_count,
        stale_price_count=summary.stale_price_count,
        total_trades_count=0,
        positions=positions,
        is_valuation_partial=summary.valuation_is_partial,
        missing_price_assets=summary.missing_price_assets,
        stale_price_assets=summary.stale_price_assets,
        suspended_assets=[],
        data_freshness_seconds=None,
        last_price_update_at=summary.as_of,
        last_market_update=summary.as_of,
        valuation_as_of=summary.as_of_timestamp,
        as_of=summary.as_of or summary.as_of_timestamp,
        market_status=summary.market_status,
        data_quality_status=summary.data_quality_status,
    )


def _problem_response(exc: HTTPException, instance: str) -> JSONResponse:
    """Convert HTTPException detail into RFC 7807 response."""

    detail = exc.detail
    if isinstance(detail, dict):
        required_keys = {"type", "title", "status", "detail", "instance"}
        if required_keys.issubset(set(detail.keys())):
            problem = detail
        else:
            problem = ProblemDetails(
                title="HTTP Error",
                status=exc.status_code,
                detail=str(detail),
                instance=instance,
            ).model_dump()
    else:
        problem = ProblemDetails(
            title="HTTP Error",
            status=exc.status_code,
            detail=str(detail),
            instance=instance,
        ).model_dump()

    return JSONResponse(
        status_code=exc.status_code,
        content=problem,
        media_type="application/problem+json",
    )


@router.post(
    "",
    response_model=PortfolioRead,
    status_code=status.HTTP_201_CREATED,
)
@router.post(
    "/",
    response_model=PortfolioRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_portfolio(
    payload: PortfolioCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PortfolioRead:
    """Create a new portfolio for the authenticated user."""

    portfolio = Portfolio(
        user_id=current_user.id,
        name=payload.name,
        description=payload.description,
        base_currency=payload.base_currency,
        manager_type=payload.manager_type,
    )
    db.add(portfolio)
    await db.commit()
    await db.refresh(portfolio)
    return PortfolioRead.model_validate(portfolio)


@router.get(
    "",
    response_model=list[PortfolioSummary],
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
@router.get(
    "/",
    response_model=list[PortfolioSummary],
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def list_portfolios(
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[PortfolioSummary] | JSONResponse:
    """List all active portfolios with live-valued summary metrics."""

    try:
        return await list_portfolio_summaries(db=db, user_id=current_user.id)
    except HTTPException as exc:
        return _problem_response(exc, instance="/api/v1/portfolios")


@router.get(
    "/{portfolio_id}",
    response_model=PortfolioRead,
)
async def get_portfolio(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PortfolioRead | JSONResponse:
    """Fetch a single portfolio by ID."""

    result = await db.execute(
        select(Portfolio).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == current_user.id,
            Portfolio.is_active.is_(True),
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        return _problem_response(
            HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Portfolio not found",
            ),
            instance=f"/api/v1/portfolios/{portfolio_id}",
        )
    return PortfolioRead.model_validate(portfolio)


@router.delete(
    "/{portfolio_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    responses={
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def delete_portfolio(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Soft-delete a portfolio owned by the authenticated user."""

    try:
        await delete_portfolio_service(
            db=db,
            user_id=current_user.id,
            portfolio_id=portfolio_id,
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except HTTPException as exc:
        raise exc


@router.get(
    "/{portfolio_id}/summary",
    response_model=PortfolioSummaryResponse,
)
async def portfolio_summary(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[PnLCalculatorService, Depends(get_pnl_calculator_service)],
) -> PortfolioSummaryResponse | JSONResponse:
    """
    Fetch live macro-level portfolio valuation and PnL metrics.
    """

    try:
        summary = await service.calculate_realtime_summary(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
        )
        return _legacy_summary_response(summary)
    except HTTPException as exc:
        return _problem_response(
            exc,
            instance=f"/api/v1/portfolios/{portfolio_id}/summary",
        )


@router.get(
    "/{portfolio_id}/holdings",
    response_model=PortfolioHoldingsApiResponse,
)
async def portfolio_holdings(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[PnLCalculatorService, Depends(get_pnl_calculator_service)],
) -> PortfolioHoldingsApiResponse | JSONResponse:
    """Return display-ready holdings whose financial values are computed by backend."""

    try:
        summary = await service.calculate_realtime_summary(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
        )
        holdings = [
            _holding_api_item(asset, currency=summary.base_currency)
            for asset in summary.assets
        ]
        warnings = sorted({warning for holding in holdings for warning in holding.warnings})
        missing_price_symbols = sorted(
            holding.symbol for holding in holdings if not holding.has_market_price
        )
        has_missing = bool(missing_price_symbols)
        if has_missing and "missing_market_prices" not in warnings:
            warnings.append("missing_market_prices")
            warnings.sort()
        return PortfolioHoldingsApiResponse(
            portfolio_id=summary.portfolio_id,
            currency=summary.base_currency,
            holdings=holdings,
            priced_holdings_count=len(holdings) - len(missing_price_symbols),
            missing_price_count=len(missing_price_symbols),
            missing_price_symbols=missing_price_symbols,
            has_missing_market_prices=has_missing,
            calculation_status="partial" if has_missing else "complete",
            warnings=warnings,
        )
    except HTTPException as exc:
        return _problem_response(
            exc,
            instance=f"/api/v1/portfolios/{portfolio_id}/holdings",
        )


@router.get(
    "/{portfolio_id}/summary/frontend",
    response_model=PortfolioSummaryApiResponse,
)
async def portfolio_frontend_summary(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    service: Annotated[PnLCalculatorService, Depends(get_pnl_calculator_service)],
) -> PortfolioSummaryApiResponse | JSONResponse:
    """Return the compact camelCase summary contract for frontend display."""

    try:
        summary = await service.calculate_realtime_summary(
            portfolio_id=portfolio_id,
            user_id=current_user.id,
        )
        return _summary_api_response(summary)
    except HTTPException as exc:
        return _problem_response(
            exc,
            instance=f"/api/v1/portfolios/{portfolio_id}/summary/frontend",
        )


@router.get(
    "/{portfolio_id}/assets/{ticker}",
    response_model=TradeHistoryPaginated,
    responses={
        400: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        401: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        404: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
        500: {"model": ProblemDetails, "content": {"application/problem+json": {}}},
    },
)
async def get_asset_details_and_ledger(
    portfolio_id: uuid.UUID,
    ticker: str,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> TradeHistoryPaginated | JSONResponse:
    """Return current asset position header + paginated trade ledger."""

    try:
        return await get_asset_ledger_details(
            db=db,
            user_id=current_user.id,
            portfolio_id=portfolio_id,
            ticker=ticker,
            limit=limit,
            offset=offset,
        )
    except HTTPException as exc:
        return _problem_response(
            exc,
            instance=f"/api/v1/portfolios/{portfolio_id}/assets/{ticker}",
        )


@router.get(
    "/{portfolio_id}/refresh-status",
    response_model=ImportRefreshStatusResponse,
)
async def get_portfolio_refresh_status_alias(
    portfolio_id: uuid.UUID,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ImportRefreshStatusResponse:
    """Alias refresh diagnostics endpoint under the portfolios namespace."""

    return await get_import_refresh_status(
        portfolio_id=portfolio_id,
        current_user=current_user,
        db=db,
    )
