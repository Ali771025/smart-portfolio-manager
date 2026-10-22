"""
Shared FastAPI dependencies.

`get_current_user` is the security gate for every protected endpoint.
It extracts the Bearer token, validates it, and loads the user from DB.
"""

import uuid
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import noload

from app.core.database import async_session_factory, get_db
from app.core.security import decode_access_token, TokenError
from app.models.user import User
from app.repositories.analytics_repository import AnalyticsRepository
from app.repositories.corporate_actions import CorporateActionRepository
from app.repositories.market_data import MarketDataRepository
from app.repositories.pnl import PnLRepository
from app.core.redis import get_redis
from app.cqrs.read_handlers import (
    GetAnalyticsReportHandler,
    GetAssetOhlcvHandler,
    LocalMetadataLRU,
    ReadHandlerBundle,
)
from app.repositories.benchmarking_read import BenchmarkingReadRepository
from app.repositories.returns_read import ReturnsReadRepository
from app.services.analytics_service import build_analytics_service, AnalyticsService
from app.services.advanced_benchmark_service import AdvancedBenchmarkService
from app.services.benchmark_comparison_service import BenchmarkComparisonService
from app.services.corporate_actions import CorporateActionsService
from app.services.factor_service import FactorService
from app.services.market_integration import MarketIntegrationService
from app.services.market_read_service import MarketReadService
from app.services.market_provider import MarketProviderConfig, MarketDataProvider
from app.services.tsetmc_provider import TSETMCProvider
from app.services.pnl_calculator import PnLCalculatorService
from app.services.returns_service import ReturnsService
from app.core.config import settings

# The `tokenUrl` tells Swagger UI where to POST for a token.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
_read_handler_bundle: ReadHandlerBundle | None = None
_advanced_benchmark_service: AdvancedBenchmarkService | None = None
_market_provider: MarketDataProvider | None = None


def get_market_provider() -> MarketDataProvider:
    """Dependency injector for the market data provider singleton.

    Returns a lazily-initialized TSETMCProvider with full resilience config.
    The provider is reused across requests to maintain connection pooling
    and circuit breaker state.
    """
    global _market_provider
    if _market_provider is None:
        config = MarketProviderConfig(
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
            health_check_interval=settings.TSETMC_HEALTH_CHECK_INTERVAL_SECONDS,
        )
        _market_provider = TSETMCProvider(config)
    return _market_provider


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    """
    Validate the JWT and return the associated User ORM instance.

    Raises:
        HTTPException 401: If the token is invalid, expired, or the
                           user no longer exists / is deactivated.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # ── 1. Decode the token ──────────────────────────
    try:
        payload = decode_access_token(token)
    except TokenError:
        raise credentials_exception

    # ── 2. Extract the user ID ───────────────────────
    user_id_str: str | None = payload.get("sub")
    if user_id_str is None:
        raise credentials_exception

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        raise credentials_exception

    # ── 3. Load the user from the database ───────────
    result = await db.execute(
        select(User)
        .options(noload("*"))
        .where(User.id == user_id)
    )
    user: User | None = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated",
        )

    return user


async def get_current_superuser(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Gate for admin-only endpoints."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient privileges",
        )
    return current_user


def get_market_integration_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> MarketIntegrationService:
    """Dependency injector for market integration service.

    The service is created with the provider dependency injected,
    allowing the provider to be swapped or mocked in tests.
    """
    provider = get_market_provider()
    return MarketIntegrationService(
        repository=MarketDataRepository(db),
        provider=provider,
    )


def get_market_read_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> MarketReadService:
    """Dependency injector for read-only Flutter market endpoints."""

    return MarketReadService(repository=MarketDataRepository(db))


def get_pnl_calculator_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PnLCalculatorService:
    """Dependency injector for advanced PnL quant engine service.

    Now includes MarketPersistenceService for:
      - Redis-first price resolution
      - Freshness-aware valuation
      - Graceful degradation when live data is unavailable
    """
    from app.services.market_persistence import MarketPersistenceService

    return PnLCalculatorService(
        pnl_repo=PnLRepository(db),
        market_repo=MarketDataRepository(db),
        market_persistence=MarketPersistenceService(db),
    )


def get_corporate_actions_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> CorporateActionsService:
    """Dependency injector for corporate action accounting service."""

    return CorporateActionsService(
        repository=CorporateActionRepository(db),
        pnl_repo=PnLRepository(db),
    )


def get_analytics_service(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AnalyticsService:
    """Dependency injector for analytics and performance service."""

    return build_analytics_service(db=db, redis_client=get_redis())


def get_read_handler_bundle() -> ReadHandlerBundle:
    """Dependency injector for CQRS read handlers with layered cache setup."""

    global _read_handler_bundle
    redis_client = get_redis()

    if (
        _read_handler_bundle is None
        or _read_handler_bundle.redis_client is not redis_client
    ):
        metadata_cache = LocalMetadataLRU(maxsize=4096)
        _read_handler_bundle = ReadHandlerBundle(
            analytics_report=GetAnalyticsReportHandler(
                session_factory=async_session_factory,
                redis_client=redis_client,
                metadata_cache=metadata_cache,
            ),
            asset_ohlcv=GetAssetOhlcvHandler(
                session_factory=async_session_factory,
                redis_client=redis_client,
                metadata_cache=metadata_cache,
            ),
            redis_client=redis_client,
        )

    return _read_handler_bundle


def get_advanced_benchmark_service() -> AdvancedBenchmarkService:
    """Dependency injector for benchmark attribution service with two-tier cache."""

    global _advanced_benchmark_service
    redis_client = get_redis()

    if (
        _advanced_benchmark_service is None
        or _advanced_benchmark_service.redis_client is not redis_client
    ):
        _advanced_benchmark_service = AdvancedBenchmarkService(
            repository=BenchmarkingReadRepository(session_factory=async_session_factory),
            redis_client=redis_client,
        )

    return _advanced_benchmark_service


# ── Reusable type aliases for clean endpoint signatures ──
CurrentUser = Annotated[User, Depends(get_current_user)]
CurrentSuperuser = Annotated[User, Depends(get_current_superuser)]
DBSession = Annotated[AsyncSession, Depends(get_db)]


# ═══════════════════════════════════════════════════════════════
# Phase 2 Analytics Services
# ═══════════════════════════════════════════════════════════════


def get_analytics_repository(
    db: AsyncSession = Depends(get_db),
) -> AnalyticsRepository:
    """Dependency injector for shared analytics repository."""
    return AnalyticsRepository(db)


def get_returns_service(
    db: AsyncSession = Depends(get_db),
) -> ReturnsService:
    """Dependency injector for returns computation service."""
    repository = ReturnsReadRepository(db)
    return ReturnsService(repository)


def get_benchmark_comparison_service(
    db: AsyncSession = Depends(get_db),
) -> BenchmarkComparisonService:
    """Dependency injector for benchmark comparison service."""
    repository = ReturnsReadRepository(db)
    return BenchmarkComparisonService(repository)


def get_factor_service(
    db: AsyncSession = Depends(get_db),
) -> FactorService:
    """Dependency injector for factor summary service."""
    repository = ReturnsReadRepository(db)
    return FactorService(repository)
