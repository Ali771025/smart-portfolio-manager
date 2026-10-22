"""API v1 router aggregator."""

from fastapi import APIRouter

from app.core.config import settings

from app.api.v1 import (
    analytics,
    analytics_engine,
    assets,
    auth_router,
    benchmark_comparison,
    benchmarking,
    charts,
    corporate_actions,
    dashboard,
    disclosures,
    factors,
    funds,
    imports,
    market,
    market_data,
    market_integration,
    multi_portfolio_imports,
    manual_transactions,
    monitoring,
    pnl,
    portfolios,
    reports,
    returns,
    symbols,
    symbol_analytics,
    trades,
    trade_reconciliations,
    transactions,
    users,
    watchlist,
)

api_router = APIRouter()

api_router.include_router(
    auth_router.router,
    prefix="/auth",
    tags=["Authentication"],
)
api_router.include_router(
    analytics.router,
)
api_router.include_router(
    analytics_engine.router,
)
api_router.include_router(
    benchmarking.router,
)
api_router.include_router(
    benchmark_comparison.router,
)
api_router.include_router(
    factors.router,
)
api_router.include_router(
    watchlist.router,
)
api_router.include_router(
    reports.router,
)
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["Users"],
)
api_router.include_router(
    imports.router,
    tags=["Imports"],
)
api_router.include_router(
    multi_portfolio_imports.router,
    tags=["Multi Portfolio Imports"],
)
api_router.include_router(
    dashboard.router,
    tags=["Dashboard BFF"],
)
api_router.include_router(
    charts.router,
    tags=["Charts"],
)
api_router.include_router(
    symbol_analytics.router,
    tags=["Symbol Analytics"],
)
api_router.include_router(
    portfolios.router,
    prefix="/portfolios",
    tags=["Portfolios"],
)
api_router.include_router(
    assets.router,
    tags=["Assets"],
)
api_router.include_router(
    trades.router,
    tags=["Trades"],
)
api_router.include_router(trade_reconciliations.router)
api_router.include_router(
    transactions.router,
    tags=["Transactions"],
)
api_router.include_router(
    manual_transactions.router,
    tags=["Manual Transactions"],
)
api_router.include_router(
    market.router,
    prefix="/market",
    tags=["Market Data (Frontend)"],
)
api_router.include_router(symbols.router)
api_router.include_router(
    market_data.router,
    prefix="/market-data",
    tags=["Market Data (Legacy)"],
)
api_router.include_router(
    market_integration.router,
    prefix="/market-integration",
    tags=["Market Integration"],
)
api_router.include_router(
    returns.router,
)
api_router.include_router(
    pnl.router,
    tags=["PnL Engine"],
)
api_router.include_router(
    corporate_actions.router,
    tags=["Corporate Actions"],
)
api_router.include_router(
    monitoring.router,
)
api_router.include_router(disclosures.router)
api_router.include_router(funds.router)

# Keep valuation internals absent from the production routing table and OpenAPI.
if settings.ENVIRONMENT.strip().lower() in {"development", "dev", "local"}:
    from app.api.v1 import debug

    api_router.include_router(debug.router)
