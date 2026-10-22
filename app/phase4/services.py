"""Phase 4 service layer (CQRS + UoW) for auth, portfolio, trades, and dashboard."""

from __future__ import annotations

import asyncio
import hashlib
import statistics
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

import jdatetime
import jwt
from passlib.context import CryptContext
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import settings
from app.phase4.models import Portfolio, RefreshToken, TradeLedger, TradeSide, User
from app.phase4.repositories import (
    AuthCommandRepository,
    AuthQueryRepository,
    AuthRateLimitRepository,
    GrowthPoint,
    LivePriceRepository,
    PositionAggregate,
    PortfolioCommandRepository,
    PortfolioQueryRepository,
    SnapshotQueryRepository,
    TradeCommandRepository,
    TradeQueryRepository,
)
from app.phase4.schemas import (
    AccessTokenResponse,
    AssetAllocationItem,
    BuyTradeRequest,
    DashboardOverviewResponse,
    GrowthChartPoint,
    GrowthChartResponse,
    PortfolioCreateRequest,
    PortfolioListResponse,
    PortfolioPerformanceMetrics,
    PortfolioRead,
    PortfolioUpdateRequest,
    SellTradeRequest,
    TokenPairResponse,
    TradeListResponse,
    TradeRead,
    UserLoginRequest,
    UserRead,
    UserRegisterRequest,
    bankers_round,
)


SERIALIZABLE = "SERIALIZABLE"
REPEATABLE_READ = "REPEATABLE READ"


class DomainError(Exception):
    pass


class NotFoundError(DomainError):
    pass


class ConflictError(DomainError):
    pass


class AuthenticationError(DomainError):
    pass


class AuthorizationError(DomainError):
    pass


class ValidationError(DomainError):
    pass


class RateLimitError(DomainError):
    pass


@dataclass(frozen=True, slots=True)
class AssetDetailsView:
    symbol: str
    portfolio_id: uuid.UUID | None
    quantity: Decimal
    average_cost: Decimal
    total_cost_basis: Decimal
    current_price: Decimal
    current_value: Decimal
    unrealized_pnl: Decimal
    realized_pnl: Decimal


class SqlAlchemyUnitOfWork:
    """Explicit transaction boundary with configurable isolation."""

    _ALLOWED_LEVELS = {SERIALIZABLE, REPEATABLE_READ, "READ COMMITTED"}

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        isolation_level: str = "READ COMMITTED",
    ) -> None:
        if isolation_level not in self._ALLOWED_LEVELS:
            raise ValueError(f"Unsupported isolation level: {isolation_level}")

        self._session_factory = session_factory
        self._isolation_level = isolation_level
        self.session: AsyncSession | None = None

    async def __aenter__(self) -> "SqlAlchemyUnitOfWork":
        self.session = self._session_factory()
        await self.session.begin()
        await self.session.execute(text(f"SET LOCAL TRANSACTION ISOLATION LEVEL {self._isolation_level}"))
        return self

    async def __aexit__(self, exc_type: Any, exc: Any, tb: Any) -> None:
        if self.session is None:
            return

        try:
            if exc is None:
                await self.session.commit()
            else:
                await self.session.rollback()
        finally:
            await self.session.close()
            self.session = None


class Argon2PasswordHasher:
    """Argon2 password hashing wrapper."""

    def __init__(self) -> None:
        self._context = CryptContext(
            schemes=["argon2"],
            deprecated="auto",
            argon2__rounds=4,
            argon2__memory_cost=102400,
            argon2__parallelism=8,
        )

    def hash(self, raw_password: str) -> str:
        return self._context.hash(raw_password)

    def verify(self, raw_password: str, password_hash: str) -> bool:
        return self._context.verify(raw_password, password_hash)


@dataclass(frozen=True, slots=True)
class IssuedTokenPair:
    access_token: str
    refresh_token: str
    refresh_jti: uuid.UUID
    refresh_expires_at: datetime


class JwtTokenManager:
    """JWT creation/validation used by auth command service."""

    def __init__(self) -> None:
        self._secret_key = settings.SECRET_KEY
        self._algorithm = settings.ALGORITHM
        self._access_ttl = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        self._refresh_ttl = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    def issue_token_pair(self, *, user_id: uuid.UUID) -> IssuedTokenPair:
        now = datetime.now(timezone.utc)
        access_payload = {
            "sub": str(user_id),
            "iat": now,
            "exp": now + self._access_ttl,
            "type": "access",
        }

        refresh_jti = uuid.uuid4()
        refresh_expires_at = now + self._refresh_ttl
        refresh_payload = {
            "sub": str(user_id),
            "jti": str(refresh_jti),
            "iat": now,
            "exp": refresh_expires_at,
            "type": "refresh",
        }

        return IssuedTokenPair(
            access_token=jwt.encode(access_payload, self._secret_key, algorithm=self._algorithm),
            refresh_token=jwt.encode(refresh_payload, self._secret_key, algorithm=self._algorithm),
            refresh_jti=refresh_jti,
            refresh_expires_at=refresh_expires_at,
        )

    def issue_access_token(self, *, user_id: uuid.UUID) -> str:
        now = datetime.now(timezone.utc)
        access_payload = {
            "sub": str(user_id),
            "iat": now,
            "exp": now + self._access_ttl,
            "type": "access",
        }
        return jwt.encode(access_payload, self._secret_key, algorithm=self._algorithm)

    def decode_refresh_token(self, refresh_token: str) -> tuple[uuid.UUID, uuid.UUID]:
        try:
            payload = jwt.decode(
                refresh_token,
                self._secret_key,
                algorithms=[self._algorithm],
                options={"require": ["sub", "jti", "exp", "type"]},
            )
        except jwt.PyJWTError as exc:
            raise AuthenticationError(f"Invalid refresh token: {exc}") from exc

        if payload.get("type") != "refresh":
            raise AuthenticationError("Invalid token type for refresh flow.")

        return uuid.UUID(payload["sub"]), uuid.UUID(payload["jti"])

    @property
    def access_expires_in_seconds(self) -> int:
        return int(self._access_ttl.total_seconds())

    @property
    def refresh_expires_in_seconds(self) -> int:
        return int(self._refresh_ttl.total_seconds())


class AuthCommandService:
    """Auth write-side service: register/login/refresh/logout."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        rate_limiter: AuthRateLimitRepository,
        token_manager: JwtTokenManager | None = None,
        password_hasher: Argon2PasswordHasher | None = None,
    ) -> None:
        self._session_factory = session_factory
        self._rate_limiter = rate_limiter
        self._token_manager = token_manager or JwtTokenManager()
        self._password_hasher = password_hasher or Argon2PasswordHasher()

    async def register(
        self,
        *,
        payload: UserRegisterRequest,
        rate_limit_identity: str,
    ) -> TokenPairResponse:
        allowed = await self._rate_limiter.allow(
            scope="auth:register",
            identity=rate_limit_identity,
            max_hits=10,
            window_seconds=60,
        )
        if not allowed:
            raise RateLimitError("Too many registration attempts. Try again in 60 seconds.")

        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            auth_query = AuthQueryRepository(uow.session)
            auth_command = AuthCommandRepository(uow.session)

            existing_user = await auth_query.get_user_by_email(payload.email)
            if existing_user is not None:
                raise ConflictError("Email is already registered.")

            user = User(
                email=payload.email.lower(),
                hashed_password=self._password_hasher.hash(payload.password),
                full_name=payload.full_name.strip(),
            )
            user = await auth_command.add_user(user)
            issued_tokens = self._token_manager.issue_token_pair(user_id=user.id)

            refresh_token_hash = hashlib.sha256(
                issued_tokens.refresh_token.encode("utf-8")
            ).hexdigest()
            await auth_command.add_refresh_token(
                RefreshToken(
                    user_id=user.id,
                    token_jti=issued_tokens.refresh_jti,
                    token_hash=refresh_token_hash,
                    expires_at=issued_tokens.refresh_expires_at,
                )
            )
            await auth_command.touch_last_login(user.id)

        return TokenPairResponse(
            access_token=issued_tokens.access_token,
            refresh_token=issued_tokens.refresh_token,
            token_type="bearer",
            access_expires_in_seconds=self._token_manager.access_expires_in_seconds,
            refresh_expires_in_seconds=self._token_manager.refresh_expires_in_seconds,
        )

    async def login(
        self,
        *,
        payload: UserLoginRequest,
        rate_limit_identity: str,
    ) -> TokenPairResponse:
        allowed = await self._rate_limiter.allow(
            scope="auth:login",
            identity=rate_limit_identity,
            max_hits=15,
            window_seconds=60,
        )
        if not allowed:
            raise RateLimitError("Too many login attempts. Try again in 60 seconds.")

        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            auth_query = AuthQueryRepository(uow.session)
            auth_command = AuthCommandRepository(uow.session)

            user = await auth_query.get_user_by_email(payload.email)
            if user is None or not self._password_hasher.verify(payload.password, user.hashed_password):
                raise AuthenticationError("Invalid email or password.")
            if not user.is_active:
                raise AuthorizationError("User account is inactive.")

            issued_tokens = self._token_manager.issue_token_pair(user_id=user.id)
            refresh_token_hash = hashlib.sha256(
                issued_tokens.refresh_token.encode("utf-8")
            ).hexdigest()
            await auth_command.add_refresh_token(
                RefreshToken(
                    user_id=user.id,
                    token_jti=issued_tokens.refresh_jti,
                    token_hash=refresh_token_hash,
                    expires_at=issued_tokens.refresh_expires_at,
                )
            )
            await auth_command.touch_last_login(user.id)

        return TokenPairResponse(
            access_token=issued_tokens.access_token,
            refresh_token=issued_tokens.refresh_token,
            token_type="bearer",
            access_expires_in_seconds=self._token_manager.access_expires_in_seconds,
            refresh_expires_in_seconds=self._token_manager.refresh_expires_in_seconds,
        )

    async def refresh_access_token(self, *, refresh_token: str) -> AccessTokenResponse:
        user_id, token_jti = self._token_manager.decode_refresh_token(refresh_token)
        refresh_token_hash = hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()

        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            auth_query = AuthQueryRepository(uow.session)

            stored_token = await auth_query.get_refresh_token(token_jti)
            if stored_token is None:
                raise AuthenticationError("Refresh token session not found.")
            if stored_token.revoked_at is not None:
                raise AuthenticationError("Refresh token has been revoked.")
            expires_at = stored_token.expires_at
            if expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
            if expires_at <= datetime.now(timezone.utc):
                raise AuthenticationError("Refresh token has expired.")
            if stored_token.token_hash != refresh_token_hash:
                raise AuthenticationError("Refresh token integrity check failed.")

            user = await auth_query.get_user_by_id(user_id)
            if user is None or not user.is_active:
                raise AuthenticationError("User is not active.")

        return AccessTokenResponse(
            access_token=self._token_manager.issue_access_token(user_id=user_id),
            token_type="bearer",
            access_expires_in_seconds=self._token_manager.access_expires_in_seconds,
        )

    async def logout(self, *, refresh_token: str) -> None:
        _, token_jti = self._token_manager.decode_refresh_token(refresh_token)
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            auth_command = AuthCommandRepository(uow.session)
            await auth_command.revoke_refresh_token(token_jti)


class AuthQueryService:
    """Auth read-side service used by dependency injection layer."""

    def __init__(self, *, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def get_current_active_user(self, user_id: uuid.UUID) -> UserRead:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            repo = AuthQueryRepository(uow.session)
            user = await repo.get_user_by_id(user_id)

        if user is None:
            raise AuthenticationError("User not found.")
        if not user.is_active:
            raise AuthorizationError("Inactive user.")
        return UserRead.model_validate(user)


class PortfolioCommandService:
    """Portfolio write-side service."""

    def __init__(self, *, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def create_portfolio(self, *, user_id: uuid.UUID, payload: PortfolioCreateRequest) -> PortfolioRead:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            query_repo = PortfolioQueryRepository(uow.session)
            command_repo = PortfolioCommandRepository(uow.session)

            if payload.is_default:
                await command_repo.unset_default_portfolios(user_id)

            portfolio = Portfolio(
                user_id=user_id,
                name=payload.name.strip(),
                description=payload.description,
                base_currency=payload.base_currency,
                is_default=payload.is_default,
            )
            portfolio = await command_repo.add_portfolio(portfolio)
            _ = await query_repo.count_active_portfolios(user_id)

        return PortfolioRead.model_validate(portfolio)

    async def update_portfolio(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        payload: PortfolioUpdateRequest,
    ) -> PortfolioRead:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            query_repo = PortfolioQueryRepository(uow.session)
            command_repo = PortfolioCommandRepository(uow.session)

            portfolio = await query_repo.get_owned_active_portfolio(
                user_id=user_id,
                portfolio_id=portfolio_id,
                for_update=True,
            )
            if portfolio is None:
                raise NotFoundError("Portfolio not found.")

            if payload.name is not None:
                portfolio.name = payload.name.strip()
            if payload.description is not None:
                portfolio.description = payload.description
            if payload.base_currency is not None:
                portfolio.base_currency = payload.base_currency
            if payload.is_default is True:
                await command_repo.unset_default_portfolios(user_id)
                portfolio.is_default = True
            elif payload.is_default is False:
                portfolio.is_default = False

            await uow.session.flush()

        return PortfolioRead.model_validate(portfolio)

    async def soft_delete_portfolio(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> None:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            repo = PortfolioCommandRepository(uow.session)
            deleted = await repo.soft_delete_portfolio(user_id=user_id, portfolio_id=portfolio_id)
            if not deleted:
                raise NotFoundError("Portfolio not found.")


class PortfolioQueryService:
    """Portfolio read-side service with ROI/risk computations."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        live_price_repository: LivePriceRepository,
    ) -> None:
        self._session_factory = session_factory
        self._live_price_repository = live_price_repository

    async def list_portfolios(self, *, user_id: uuid.UUID) -> PortfolioListResponse:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            repo = PortfolioQueryRepository(uow.session)
            portfolios = await repo.list_active_portfolios(user_id)

        return PortfolioListResponse(
            items=[PortfolioRead.model_validate(portfolio) for portfolio in portfolios],
            total=len(portfolios),
        )

    async def get_portfolio_performance(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
    ) -> PortfolioPerformanceMetrics:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            portfolio_repo = PortfolioQueryRepository(uow.session)
            trade_repo = TradeQueryRepository(uow.session)
            snapshot_repo = SnapshotQueryRepository(uow.session)

            portfolio = await portfolio_repo.get_owned_active_portfolio(
                user_id=user_id,
                portfolio_id=portfolio_id,
            )
            if portfolio is None:
                raise NotFoundError("Portfolio not found.")

            latest_snapshot = await snapshot_repo.get_latest_snapshot(portfolio_id)
            if latest_snapshot is not None:
                total_current_value = latest_snapshot.total_value
                total_invested_capital = latest_snapshot.invested_capital
                total_unrealized_pnl = latest_snapshot.total_unrealized_pnl
                total_realized_pnl = latest_snapshot.total_realized_pnl
            else:
                position_state = await self._compute_portfolio_cost_state(
                    trade_repo=trade_repo,
                    portfolio_id=portfolio_id,
                )
                symbol_prices = await self._live_price_repository.fetch_many(position_state.keys())
                total_current_value = sum(
                    (qty * symbol_prices.get(symbol, Decimal("0.0000")) for symbol, (qty, _) in position_state.items()),
                    start=Decimal("0.0000"),
                )
                total_invested_capital = sum((cost for _, (_, cost) in position_state.items()), start=Decimal("0.0000"))
                total_unrealized_pnl = total_current_value - total_invested_capital
                total_realized_pnl = await trade_repo.sum_realized_pnl(
                    user_id=user_id,
                    portfolio_ids=[portfolio_id],
                )

            risk_std, sharpe = await self._approximate_risk_metrics(snapshot_repo, portfolio_id)

        return PortfolioPerformanceMetrics.from_components(
            total_current_value=total_current_value,
            total_invested_capital=total_invested_capital,
            total_unrealized_pnl=total_unrealized_pnl,
            total_realized_pnl=total_realized_pnl,
            risk_std_deviation=risk_std,
            sharpe_ratio=sharpe,
        )

    async def _compute_portfolio_cost_state(
        self,
        *,
        trade_repo: TradeQueryRepository,
        portfolio_id: uuid.UUID,
    ) -> dict[str, tuple[Decimal, Decimal]]:
        symbols = await trade_repo.list_distinct_symbols_for_portfolio(portfolio_id=portfolio_id)

        state_by_symbol: dict[str, tuple[Decimal, Decimal]] = {}
        for symbol in symbols:
            trades = await trade_repo.list_symbol_trades_for_replay(portfolio_id=portfolio_id, symbol=symbol)
            quantity, cost_basis = replay_position_state(trades)
            if quantity > 0:
                state_by_symbol[symbol] = (quantity, cost_basis)
        return state_by_symbol

    async def _approximate_risk_metrics(
        self,
        snapshot_repo: SnapshotQueryRepository,
        portfolio_id: uuid.UUID,
    ) -> tuple[Decimal | None, Decimal | None]:
        start_date = date.today() - timedelta(days=30)
        points = await snapshot_repo.list_growth_points_by_portfolio(
            portfolio_id=portfolio_id,
            start_date=start_date,
        )
        if len(points) < 3:
            return None, None

        returns: list[float] = []
        for prev, cur in zip(points, points[1:]):
            if prev.total_value <= 0:
                continue
            returns.append(float((cur.total_value / prev.total_value) - Decimal("1")))

        if len(returns) < 2:
            return None, None

        std_daily = statistics.pstdev(returns)
        mean_daily = statistics.fmean(returns)
        sharpe = 0.0 if std_daily == 0 else (mean_daily / std_daily)
        return Decimal(str(std_daily * 100)), Decimal(str(sharpe))


class TradeCommandService:
    """Trade write-side service with strict SERIALIZABLE transactions."""

    def __init__(self, *, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def execute_buy(self, *, user_id: uuid.UUID, payload: BuyTradeRequest) -> TradeRead:
        return await self._execute_trade(user_id=user_id, side=TradeSide.BUY, payload=payload)

    async def execute_sell(self, *, user_id: uuid.UUID, payload: SellTradeRequest) -> TradeRead:
        return await self._execute_trade(user_id=user_id, side=TradeSide.SELL, payload=payload)

    async def _execute_trade(
        self,
        *,
        user_id: uuid.UUID,
        side: TradeSide,
        payload: BuyTradeRequest | SellTradeRequest,
    ) -> TradeRead:
        async with SqlAlchemyUnitOfWork(
            session_factory=self._session_factory,
            isolation_level=SERIALIZABLE,
        ) as uow:
            assert uow.session is not None
            trade_command_repo = TradeCommandRepository(uow.session)
            trade_query_repo = TradeQueryRepository(uow.session)

            portfolio = await trade_command_repo.lock_portfolio_for_trade(
                user_id=user_id,
                portfolio_id=payload.portfolio_id,
            )
            if portfolio is None:
                raise NotFoundError("Portfolio not found.")

            existing_trade = await trade_command_repo.get_by_idempotency_key(
                portfolio_id=payload.portfolio_id,
                idempotency_key=payload.idempotency_key,
            )
            if existing_trade is not None:
                return TradeRead.model_validate(existing_trade)

            symbol_trades = await trade_query_repo.list_symbol_trades_for_replay(
                portfolio_id=payload.portfolio_id,
                symbol=payload.symbol,
            )
            current_qty, current_cost_basis = replay_position_state(symbol_trades)

            quantity = bankers_round(payload.quantity)
            price = bankers_round(payload.price)
            fees = bankers_round(payload.fees)
            gross_amount = bankers_round(quantity * price)
            realized_pnl = Decimal("0.0000")

            if side == TradeSide.SELL:
                if current_qty <= 0:
                    raise ValidationError(f"No available inventory for symbol {payload.symbol}.")
                if quantity > current_qty:
                    raise ValidationError(
                        f"Insufficient inventory for {payload.symbol}. Available={current_qty}, requested={quantity}."
                    )

                average_cost = bankers_round(current_cost_basis / current_qty)
                cost_of_sold = bankers_round(average_cost * quantity)
                realized_pnl = bankers_round(gross_amount - cost_of_sold - fees)

            trade = TradeLedger(
                portfolio_id=payload.portfolio_id,
                user_id=user_id,
                side=side,
                symbol=payload.symbol,
                asset_name=payload.asset_name,
                quantity=quantity,
                price=price,
                fees=fees,
                gross_amount=gross_amount,
                realized_pnl=realized_pnl,
                executed_at=payload.executed_at,
                idempotency_key=payload.idempotency_key,
                external_order_id=payload.external_order_id,
                notes=payload.notes,
            )
            trade = await trade_command_repo.add_trade(trade)

        return TradeRead.model_validate(trade)


class TradeQueryService:
    """Trade read-side service."""

    def __init__(self, *, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def list_trades(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None,
        limit: int,
        offset: int,
    ) -> TradeListResponse:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            repo = TradeQueryRepository(uow.session)
            trades = await repo.list_trades(
                user_id=user_id,
                portfolio_id=portfolio_id,
                limit=limit,
                offset=offset,
            )
            total = await repo.count_trades(user_id=user_id, portfolio_id=portfolio_id)

        return TradeListResponse(
            items=[TradeRead.model_validate(trade) for trade in trades],
            total=total,
            limit=limit,
            offset=offset,
        )


class AssetQueryService:
    """Asset read-side service for per-symbol holdings and PnL details."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        live_price_repository: LivePriceRepository,
    ) -> None:
        self._session_factory = session_factory
        self._live_price_repository = live_price_repository

    async def get_asset_details(
        self,
        *,
        user_id: uuid.UUID,
        symbol: str,
        portfolio_id: uuid.UUID | None = None,
    ) -> AssetDetailsView:
        normalized_symbol = symbol.strip().upper()
        if not normalized_symbol:
            raise ValidationError("Symbol must not be empty.")

        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            portfolio_repo = PortfolioQueryRepository(uow.session)
            trade_repo = TradeQueryRepository(uow.session)

            if portfolio_id is not None:
                portfolio = await portfolio_repo.get_owned_active_portfolio(
                    user_id=user_id,
                    portfolio_id=portfolio_id,
                )
                if portfolio is None:
                    raise NotFoundError("Portfolio not found.")
                portfolio_ids = [portfolio.id]
            else:
                portfolios = await portfolio_repo.list_active_portfolios(user_id)
                portfolio_ids = [item.id for item in portfolios]

            total_quantity = Decimal("0.0000")
            total_cost_basis = Decimal("0.0000")
            for selected_portfolio_id in portfolio_ids:
                trades = await trade_repo.list_symbol_trades_for_replay(
                    portfolio_id=selected_portfolio_id,
                    symbol=normalized_symbol,
                )
                quantity, cost_basis = replay_position_state(trades)
                total_quantity += quantity
                total_cost_basis += cost_basis

            realized_pnl = await trade_repo.sum_realized_pnl_for_symbol(
                user_id=user_id,
                symbol=normalized_symbol,
                portfolio_ids=portfolio_ids,
            )

            live_prices = await self._live_price_repository.fetch_many([normalized_symbol])
            current_price = live_prices.get(normalized_symbol, Decimal("0.0000"))

        total_quantity = bankers_round(total_quantity)
        total_cost_basis = bankers_round(total_cost_basis)
        current_price = bankers_round(current_price)
        current_value = bankers_round(total_quantity * current_price)
        unrealized_pnl = bankers_round(current_value - total_cost_basis)
        average_cost = (
            bankers_round(total_cost_basis / total_quantity)
            if total_quantity > 0
            else Decimal("0.0000")
        )

        return AssetDetailsView(
            symbol=normalized_symbol,
            portfolio_id=portfolio_id,
            quantity=total_quantity,
            average_cost=average_cost,
            total_cost_basis=total_cost_basis,
            current_price=current_price,
            current_value=current_value,
            unrealized_pnl=unrealized_pnl,
            realized_pnl=bankers_round(realized_pnl),
        )


class DashboardQueryService:
    """Dashboard read-side service with async gather + Redis read-through."""

    def __init__(
        self,
        *,
        session_factory: async_sessionmaker[AsyncSession],
        live_price_repository: LivePriceRepository,
    ) -> None:
        self._session_factory = session_factory
        self._live_price_repository = live_price_repository

    async def get_overview(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None = None,
    ) -> DashboardOverviewResponse:
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            portfolio_repo = PortfolioQueryRepository(uow.session)
            trade_repo = TradeQueryRepository(uow.session)

            if portfolio_id is not None:
                portfolio = await portfolio_repo.get_owned_active_portfolio(
                    user_id=user_id,
                    portfolio_id=portfolio_id,
                )
                if portfolio is None:
                    raise NotFoundError("Portfolio not found.")
                portfolio_ids = [portfolio.id]
            else:
                portfolios = await portfolio_repo.list_active_portfolios(user_id)
                portfolio_ids = [item.id for item in portfolios]

            positions = await trade_repo.list_open_positions(
                user_id=user_id,
                portfolio_ids=portfolio_ids,
            )
            symbols = [position.symbol for position in positions]

            # Requirement: concurrent I/O with asyncio.gather for low-latency BFF responses.
            prices_task = asyncio.create_task(self._live_price_repository.fetch_many(symbols))
            realized_task = asyncio.create_task(
                trade_repo.sum_realized_pnl(user_id=user_id, portfolio_ids=portfolio_ids)
            )
            live_prices, total_realized_pnl = await asyncio.gather(prices_task, realized_task)

            current_value_by_symbol: dict[str, Decimal] = {}
            total_current_value = Decimal("0.0000")
            for position in positions:
                price = live_prices.get(position.symbol, Decimal("0.0000"))
                position_value = bankers_round(position.quantity * price)
                current_value_by_symbol[position.symbol] = current_value_by_symbol.get(
                    position.symbol,
                    Decimal("0.0000"),
                ) + position_value
                total_current_value += position_value

            total_current_value = bankers_round(total_current_value)
            total_invested_capital = await self._compute_total_invested_capital(
                trade_repo=trade_repo,
                positions=positions,
            )
            total_unrealized_pnl = bankers_round(total_current_value - total_invested_capital)
            if total_invested_capital == 0:
                overall_roi_percent = Decimal("0.00")
            else:
                overall_roi_percent = bankers_round(
                    ((total_unrealized_pnl + total_realized_pnl) / total_invested_capital) * Decimal("100"),
                    Decimal("0.01"),
                )

        allocation: list[AssetAllocationItem] = []
        if total_current_value > 0:
            for symbol, value in sorted(current_value_by_symbol.items()):
                weight_percent = bankers_round((value / total_current_value) * Decimal("100"), Decimal("0.01"))
                allocation.append(
                    AssetAllocationItem(
                        symbol=symbol,
                        value=bankers_round(value),
                        weight_percent=weight_percent,
                    )
                )

        return DashboardOverviewResponse(
            total_current_value=total_current_value,
            overall_roi_percent=overall_roi_percent,
            asset_allocation=allocation,
        )

    async def get_growth_chart(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None = None,
        days: int = 30,
    ) -> GrowthChartResponse:
        start_date = date.today() - timedelta(days=max(days, 1))
        async with SqlAlchemyUnitOfWork(session_factory=self._session_factory) as uow:
            assert uow.session is not None
            portfolio_repo = PortfolioQueryRepository(uow.session)
            snapshot_repo = SnapshotQueryRepository(uow.session)

            if portfolio_id is not None:
                portfolio = await portfolio_repo.get_owned_active_portfolio(
                    user_id=user_id,
                    portfolio_id=portfolio_id,
                )
                if portfolio is None:
                    raise NotFoundError("Portfolio not found.")
                points = await snapshot_repo.list_growth_points_by_portfolio(
                    portfolio_id=portfolio_id,
                    start_date=start_date,
                )
            else:
                points = await snapshot_repo.list_growth_points_by_user(
                    user_id=user_id,
                    start_date=start_date,
                )

        return GrowthChartResponse(
            portfolio_id=portfolio_id,
            points=[_to_growth_point(item) for item in points],
        )

    async def _compute_total_invested_capital(
        self,
        *,
        trade_repo: TradeQueryRepository,
        positions: list[PositionAggregate],
    ) -> Decimal:
        total_cost = Decimal("0.0000")
        for position in positions:
            trades = await trade_repo.list_symbol_trades_for_replay(
                portfolio_id=position.portfolio_id,
                symbol=position.symbol,
            )
            qty, cost = replay_position_state(trades)
            if qty > 0:
                total_cost += cost

        return bankers_round(total_cost)


def replay_position_state(trades: list[TradeLedger]) -> tuple[Decimal, Decimal]:
    """
    Replay ledger rows to reconstruct live quantity/cost-basis.

    This keeps the trade side immutable while still enabling deterministic
    valuation and realized PnL correctness checks during SELL validation.
    """

    quantity = Decimal("0.0000")
    cost_basis = Decimal("0.0000")

    for trade in trades:
        if trade.side == TradeSide.BUY:
            quantity = bankers_round(quantity + trade.quantity)
            cost_basis = bankers_round(cost_basis + trade.gross_amount + trade.fees)
            continue

        if quantity <= 0:
            continue
        average_cost = bankers_round(cost_basis / quantity)
        quantity = bankers_round(quantity - trade.quantity)
        cost_basis = bankers_round(cost_basis - (average_cost * trade.quantity))
        if quantity < 0:
            quantity = Decimal("0.0000")
        if cost_basis < 0:
            cost_basis = Decimal("0.0000")

    return quantity, cost_basis


def _to_growth_point(point: GrowthPoint) -> GrowthChartPoint:
    jalali_date = jdatetime.date.fromgregorian(date=point.snapshot_date)
    label = f"{jalali_date.year:04d}/{jalali_date.month:02d}/{jalali_date.day:02d}"
    return GrowthChartPoint(
        date=label,
        total_value=bankers_round(point.total_value),
    )
