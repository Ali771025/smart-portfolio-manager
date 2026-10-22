"""Phase 4 FastAPI routers for Auth, Portfolios, Trades, Assets, and Dashboard."""

from __future__ import annotations

import logging
import uuid
from decimal import Decimal
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, FastAPI, HTTPException, Query, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.redis import get_redis
from app.phase4.repositories import AuthRateLimitRepository, LivePriceRepository
from app.phase4.schemas import (
    AccessTokenResponse,
    BuyTradeRequest,
    DashboardOverviewResponse,
    GrowthChartResponse,
    PortfolioCreateRequest,
    PortfolioListResponse,
    PortfolioPerformanceMetrics,
    PortfolioRead,
    PortfolioUpdateRequest,
    ProblemDetails,
    RefreshTokenRequest,
    SellTradeRequest,
    TokenPairResponse,
    TradeListResponse,
    TradeRead,
    UserLoginRequest,
    UserRead,
    UserRegisterRequest,
)
from app.phase4.services import (
    AssetDetailsView,
    AssetQueryService,
    AuthCommandService,
    AuthQueryService,
    AuthenticationError,
    AuthorizationError,
    ConflictError,
    DashboardQueryService,
    DomainError,
    NotFoundError,
    PortfolioCommandService,
    PortfolioQueryService,
    RateLimitError,
    TradeCommandService,
    TradeQueryService,
    ValidationError,
)

logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


class AssetDetailsResponse(BaseModel):
    """Read model for `/assets/{symbol}` endpoint."""

    model_config = ConfigDict(extra="forbid")

    symbol: str
    portfolio_id: uuid.UUID | None
    quantity: Decimal = Field(max_digits=18, decimal_places=4)
    average_cost: Decimal = Field(max_digits=18, decimal_places=4)
    total_cost_basis: Decimal = Field(max_digits=18, decimal_places=4)
    current_price: Decimal = Field(max_digits=18, decimal_places=4)
    current_value: Decimal = Field(max_digits=18, decimal_places=4)
    unrealized_pnl: Decimal = Field(max_digits=18, decimal_places=4)
    realized_pnl: Decimal = Field(max_digits=18, decimal_places=4)

    @classmethod
    def from_view(cls, view: AssetDetailsView) -> "AssetDetailsResponse":
        return cls(
            symbol=view.symbol,
            portfolio_id=view.portfolio_id,
            quantity=view.quantity,
            average_cost=view.average_cost,
            total_cost_basis=view.total_cost_basis,
            current_price=view.current_price,
            current_value=view.current_value,
            unrealized_pnl=view.unrealized_pnl,
            realized_pnl=view.realized_pnl,
        )


def _build_problem_details(
    *,
    request: Request,
    title: str,
    detail: str,
    status_code: int,
    type_: str = "about:blank",
) -> ProblemDetails:
    return ProblemDetails(
        type=type_,
        title=title,
        status=status_code,
        detail=detail,
        instance=str(request.url.path),
    )


def _problem_json(problem: ProblemDetails, *, status_code: int, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse(
        content=problem.model_dump(),
        status_code=status_code,
        headers=headers,
        media_type="application/problem+json",
    )


def register_phase4_exception_handlers(app: FastAPI) -> None:
    """Register RFC 7807-compliant exception handlers."""

    @app.exception_handler(DomainError)
    async def _handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
        if isinstance(exc, AuthenticationError):
            status_code = status.HTTP_401_UNAUTHORIZED
            title = "Authentication Failed"
            headers = {"WWW-Authenticate": "Bearer"}
        elif isinstance(exc, AuthorizationError):
            status_code = status.HTTP_403_FORBIDDEN
            title = "Authorization Failed"
            headers = None
        elif isinstance(exc, NotFoundError):
            status_code = status.HTTP_404_NOT_FOUND
            title = "Resource Not Found"
            headers = None
        elif isinstance(exc, ConflictError):
            status_code = status.HTTP_409_CONFLICT
            title = "Conflict"
            headers = None
        elif isinstance(exc, RateLimitError):
            status_code = status.HTTP_429_TOO_MANY_REQUESTS
            title = "Too Many Requests"
            headers = None
        elif isinstance(exc, ValidationError):
            status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
            title = "Validation Error"
            headers = None
        else:
            status_code = status.HTTP_400_BAD_REQUEST
            title = "Domain Error"
            headers = None

        problem = _build_problem_details(
            request=request,
            title=title,
            detail=str(exc),
            status_code=status_code,
        )
        return _problem_json(problem, status_code=status_code, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def _handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
        formatted_errors = []
        for item in exc.errors():
            location = ".".join(str(part) for part in item.get("loc", []))
            message = item.get("msg", "Invalid value.")
            formatted_errors.append(f"{location}: {message}")
        detail = "; ".join(formatted_errors[:5]) or "Invalid request payload."

        problem = _build_problem_details(
            request=request,
            title="Request Validation Failed",
            detail=detail,
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            type_="https://datatracker.ietf.org/doc/html/rfc7807",
        )
        return _problem_json(problem, status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)

    @app.exception_handler(StarletteHTTPException)
    async def _handle_http_exception(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        detail = str(exc.detail) if exc.detail else "HTTP error."
        problem = _build_problem_details(
            request=request,
            title="HTTP Error",
            detail=detail,
            status_code=exc.status_code,
        )
        return _problem_json(problem, status_code=exc.status_code, headers=exc.headers)

    @app.exception_handler(Exception)
    async def _handle_unexpected_exception(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception for request path=%s", request.url.path, exc_info=exc)
        problem = _build_problem_details(
            request=request,
            title="Internal Server Error",
            detail="An unexpected error occurred.",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
        return _problem_json(problem, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _decode_access_token(token: str) -> uuid.UUID:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
            options={"require": ["sub", "exp", "type"]},
        )
    except jwt.PyJWTError as exc:
        raise credentials_exception from exc

    if payload.get("type") != "access":
        raise credentials_exception
    subject = payload.get("sub")
    if not isinstance(subject, str):
        raise credentials_exception

    try:
        return uuid.UUID(subject)
    except ValueError as exc:
        raise credentials_exception from exc


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    return async_session_factory


def get_live_price_repository(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
) -> LivePriceRepository:
    return LivePriceRepository(
        redis=get_redis(),
        session_factory=session_factory,
        key_prefix=settings.REDIS_PRICE_PREFIX,
        ttl_seconds=settings.REDIS_LIVE_PRICE_TTL_SECONDS,
    )


def get_auth_rate_limiter() -> AuthRateLimitRepository:
    return AuthRateLimitRepository(redis=get_redis())


def get_auth_command_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
    rate_limiter: Annotated[AuthRateLimitRepository, Depends(get_auth_rate_limiter)],
) -> AuthCommandService:
    return AuthCommandService(session_factory=session_factory, rate_limiter=rate_limiter)


def get_auth_query_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
) -> AuthQueryService:
    return AuthQueryService(session_factory=session_factory)


def get_portfolio_command_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
) -> PortfolioCommandService:
    return PortfolioCommandService(session_factory=session_factory)


def get_portfolio_query_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
    live_prices: Annotated[LivePriceRepository, Depends(get_live_price_repository)],
) -> PortfolioQueryService:
    return PortfolioQueryService(session_factory=session_factory, live_price_repository=live_prices)


def get_trade_command_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
) -> TradeCommandService:
    return TradeCommandService(session_factory=session_factory)


def get_trade_query_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
) -> TradeQueryService:
    return TradeQueryService(session_factory=session_factory)


def get_asset_query_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
    live_prices: Annotated[LivePriceRepository, Depends(get_live_price_repository)],
) -> AssetQueryService:
    return AssetQueryService(session_factory=session_factory, live_price_repository=live_prices)


def get_dashboard_query_service(
    session_factory: Annotated[async_sessionmaker[AsyncSession], Depends(get_session_factory)],
    live_prices: Annotated[LivePriceRepository, Depends(get_live_price_repository)],
) -> DashboardQueryService:
    return DashboardQueryService(session_factory=session_factory, live_price_repository=live_prices)


async def get_current_active_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    auth_query_service: Annotated[AuthQueryService, Depends(get_auth_query_service)],
) -> UserRead:
    user_id = _decode_access_token(token)
    return await auth_query_service.get_current_active_user(user_id)


CurrentActiveUser = Annotated[UserRead, Depends(get_current_active_user)]


auth_router = APIRouter(prefix="/auth", tags=["Authentication"])
portfolios_router = APIRouter(prefix="/portfolios", tags=["Portfolios"])
trades_router = APIRouter(prefix="/trades", tags=["Trades"])
assets_router = APIRouter(prefix="/assets", tags=["Assets"])
dashboard_router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@auth_router.post(
    "/register",
    response_model=TokenPairResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_user(
    payload: UserRegisterRequest,
    request: Request,
    auth_service: Annotated[AuthCommandService, Depends(get_auth_command_service)],
) -> TokenPairResponse:
    client_ip = request.client.host if request.client else "unknown"
    rate_identity = f"{client_ip}:{payload.email.lower()}"
    return await auth_service.register(payload=payload, rate_limit_identity=rate_identity)


@auth_router.post("/login", response_model=TokenPairResponse)
async def login_user(
    payload: UserLoginRequest,
    request: Request,
    auth_service: Annotated[AuthCommandService, Depends(get_auth_command_service)],
) -> TokenPairResponse:
    client_ip = request.client.host if request.client else "unknown"
    rate_identity = f"{client_ip}:{payload.email.lower()}"
    return await auth_service.login(payload=payload, rate_limit_identity=rate_identity)


@auth_router.post("/refresh", response_model=AccessTokenResponse)
async def refresh_access_token(
    payload: RefreshTokenRequest,
    auth_service: Annotated[AuthCommandService, Depends(get_auth_command_service)],
) -> AccessTokenResponse:
    return await auth_service.refresh_access_token(refresh_token=payload.refresh_token)


@auth_router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout_user(
    payload: RefreshTokenRequest,
    auth_service: Annotated[AuthCommandService, Depends(get_auth_command_service)],
) -> Response:
    await auth_service.logout(refresh_token=payload.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@auth_router.get("/me", response_model=UserRead)
async def get_current_user_profile(current_user: CurrentActiveUser) -> UserRead:
    return current_user


@portfolios_router.post("", response_model=PortfolioRead, status_code=status.HTTP_201_CREATED)
async def create_portfolio(
    payload: PortfolioCreateRequest,
    current_user: CurrentActiveUser,
    service: Annotated[PortfolioCommandService, Depends(get_portfolio_command_service)],
) -> PortfolioRead:
    return await service.create_portfolio(user_id=current_user.id, payload=payload)


@portfolios_router.get("", response_model=PortfolioListResponse)
async def list_portfolios(
    current_user: CurrentActiveUser,
    service: Annotated[PortfolioQueryService, Depends(get_portfolio_query_service)],
) -> PortfolioListResponse:
    return await service.list_portfolios(user_id=current_user.id)


@portfolios_router.patch("/{portfolio_id}", response_model=PortfolioRead)
async def update_portfolio(
    portfolio_id: uuid.UUID,
    payload: PortfolioUpdateRequest,
    current_user: CurrentActiveUser,
    service: Annotated[PortfolioCommandService, Depends(get_portfolio_command_service)],
) -> PortfolioRead:
    return await service.update_portfolio(
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        payload=payload,
    )


@portfolios_router.delete("/{portfolio_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_portfolio(
    portfolio_id: uuid.UUID,
    current_user: CurrentActiveUser,
    service: Annotated[PortfolioCommandService, Depends(get_portfolio_command_service)],
) -> Response:
    await service.soft_delete_portfolio(user_id=current_user.id, portfolio_id=portfolio_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@portfolios_router.get("/{portfolio_id}/performance", response_model=PortfolioPerformanceMetrics)
async def get_portfolio_performance(
    portfolio_id: uuid.UUID,
    current_user: CurrentActiveUser,
    service: Annotated[PortfolioQueryService, Depends(get_portfolio_query_service)],
) -> PortfolioPerformanceMetrics:
    return await service.get_portfolio_performance(
        user_id=current_user.id,
        portfolio_id=portfolio_id,
    )


@trades_router.post("/buy", response_model=TradeRead, status_code=status.HTTP_201_CREATED)
async def create_buy_trade(
    payload: BuyTradeRequest,
    current_user: CurrentActiveUser,
    service: Annotated[TradeCommandService, Depends(get_trade_command_service)],
) -> TradeRead:
    return await service.execute_buy(user_id=current_user.id, payload=payload)


@trades_router.post("/sell", response_model=TradeRead, status_code=status.HTTP_201_CREATED)
async def create_sell_trade(
    payload: SellTradeRequest,
    current_user: CurrentActiveUser,
    service: Annotated[TradeCommandService, Depends(get_trade_command_service)],
) -> TradeRead:
    return await service.execute_sell(user_id=current_user.id, payload=payload)


@trades_router.get("", response_model=TradeListResponse)
async def list_trades(
    current_user: CurrentActiveUser,
    service: Annotated[TradeQueryService, Depends(get_trade_query_service)],
    portfolio_id: uuid.UUID | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> TradeListResponse:
    return await service.list_trades(
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        limit=limit,
        offset=offset,
    )


@assets_router.get("/{symbol}", response_model=AssetDetailsResponse)
async def get_asset_details(
    symbol: str,
    current_user: CurrentActiveUser,
    service: Annotated[AssetQueryService, Depends(get_asset_query_service)],
    portfolio_id: uuid.UUID | None = Query(default=None),
) -> AssetDetailsResponse:
    view = await service.get_asset_details(
        user_id=current_user.id,
        symbol=symbol,
        portfolio_id=portfolio_id,
    )
    return AssetDetailsResponse.from_view(view)


@dashboard_router.get("/overview", response_model=DashboardOverviewResponse)
async def get_dashboard_overview(
    current_user: CurrentActiveUser,
    service: Annotated[DashboardQueryService, Depends(get_dashboard_query_service)],
    portfolio_id: uuid.UUID | None = Query(default=None),
) -> DashboardOverviewResponse:
    return await service.get_overview(user_id=current_user.id, portfolio_id=portfolio_id)


@dashboard_router.get("/growth-chart", response_model=GrowthChartResponse)
async def get_growth_chart(
    current_user: CurrentActiveUser,
    service: Annotated[DashboardQueryService, Depends(get_dashboard_query_service)],
    portfolio_id: uuid.UUID | None = Query(default=None),
    days: int = Query(default=30, ge=1, le=365),
) -> GrowthChartResponse:
    return await service.get_growth_chart(
        user_id=current_user.id,
        portfolio_id=portfolio_id,
        days=days,
    )


phase4_api_router = APIRouter()
phase4_api_router.include_router(auth_router)
phase4_api_router.include_router(portfolios_router)
phase4_api_router.include_router(trades_router)
phase4_api_router.include_router(assets_router)
phase4_api_router.include_router(dashboard_router)
