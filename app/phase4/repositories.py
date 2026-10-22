"""Phase 4 repository layer (CQRS-oriented, async SQLAlchemy + Redis)."""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Iterable, Sequence

import redis.asyncio as aioredis
from sqlalchemy import bindparam, case, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.phase4.models import Portfolio, PortfolioDailySnapshot, RefreshToken, TradeLedger, TradeSide, User

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PositionAggregate:
    portfolio_id: uuid.UUID
    symbol: str
    quantity: Decimal


@dataclass(frozen=True, slots=True)
class GrowthPoint:
    snapshot_date: date
    total_value: Decimal


class AuthQueryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_user_by_email(self, email: str) -> User | None:
        stmt = select(User).where(func.lower(User.email) == email.strip().lower())
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_user_by_id(self, user_id: uuid.UUID) -> User | None:
        stmt = select(User).where(User.id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_refresh_token(self, token_jti: uuid.UUID) -> RefreshToken | None:
        stmt = select(RefreshToken).where(RefreshToken.token_jti == token_jti)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()


class AuthCommandRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_user(self, user: User) -> User:
        self._session.add(user)
        await self._session.flush()
        return user

    async def add_refresh_token(self, token: RefreshToken) -> RefreshToken:
        self._session.add(token)
        await self._session.flush()
        return token

    async def revoke_refresh_token(self, token_jti: uuid.UUID) -> bool:
        stmt = (
            update(RefreshToken)
            .where(RefreshToken.token_jti == token_jti, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=datetime.now(timezone.utc))
        )
        result = await self._session.execute(stmt)
        return result.rowcount > 0

    async def revoke_all_user_tokens(self, user_id: uuid.UUID) -> int:
        stmt = (
            update(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=datetime.now(timezone.utc))
        )
        result = await self._session.execute(stmt)
        return int(result.rowcount or 0)

    async def touch_last_login(self, user_id: uuid.UUID) -> None:
        stmt = update(User).where(User.id == user_id).values(last_login_at=datetime.now(timezone.utc))
        await self._session.execute(stmt)


class PortfolioQueryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_owned_active_portfolio(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        for_update: bool = False,
    ) -> Portfolio | None:
        stmt = select(Portfolio).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
            Portfolio.is_deleted.is_(False),
        )
        if for_update:
            stmt = stmt.with_for_update()
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_active_portfolios(self, user_id: uuid.UUID) -> list[Portfolio]:
        stmt = (
            select(Portfolio)
            .where(Portfolio.user_id == user_id, Portfolio.is_deleted.is_(False))
            .order_by(Portfolio.created_at.desc())
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def count_active_portfolios(self, user_id: uuid.UUID) -> int:
        stmt = select(func.count(Portfolio.id)).where(
            Portfolio.user_id == user_id,
            Portfolio.is_deleted.is_(False),
        )
        result = await self._session.execute(stmt)
        return int(result.scalar_one())


class PortfolioCommandRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_portfolio(self, portfolio: Portfolio) -> Portfolio:
        self._session.add(portfolio)
        await self._session.flush()
        return portfolio

    async def unset_default_portfolios(self, user_id: uuid.UUID) -> None:
        stmt = (
            update(Portfolio)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_deleted.is_(False),
                Portfolio.is_default.is_(True),
            )
            .values(is_default=False)
        )
        await self._session.execute(stmt)

    async def soft_delete_portfolio(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> bool:
        stmt = (
            update(Portfolio)
            .where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_deleted.is_(False),
            )
            .values(is_deleted=True, deleted_at=datetime.now(timezone.utc), is_default=False)
        )
        result = await self._session.execute(stmt)
        return result.rowcount > 0


class TradeCommandRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_idempotency_key(
        self,
        *,
        portfolio_id: uuid.UUID,
        idempotency_key: str,
    ) -> TradeLedger | None:
        stmt = select(TradeLedger).where(
            TradeLedger.portfolio_id == portfolio_id,
            TradeLedger.idempotency_key == idempotency_key,
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def lock_portfolio_for_trade(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> Portfolio | None:
        query_repo = PortfolioQueryRepository(self._session)
        return await query_repo.get_owned_active_portfolio(
            user_id=user_id,
            portfolio_id=portfolio_id,
            for_update=True,
        )

    async def add_trade(self, trade: TradeLedger) -> TradeLedger:
        self._session.add(trade)
        await self._session.flush()
        return trade


class TradeQueryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_trades(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID | None,
        limit: int,
        offset: int,
    ) -> list[TradeLedger]:
        stmt = select(TradeLedger).where(TradeLedger.user_id == user_id)
        if portfolio_id is not None:
            stmt = stmt.where(TradeLedger.portfolio_id == portfolio_id)

        stmt = stmt.order_by(TradeLedger.executed_at.desc(), TradeLedger.created_at.desc()).limit(limit).offset(offset)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def count_trades(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID | None) -> int:
        stmt = select(func.count(TradeLedger.id)).where(TradeLedger.user_id == user_id)
        if portfolio_id is not None:
            stmt = stmt.where(TradeLedger.portfolio_id == portfolio_id)
        result = await self._session.execute(stmt)
        return int(result.scalar_one())

    async def list_distinct_symbols(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: Sequence[uuid.UUID] | None = None,
    ) -> list[str]:
        stmt = select(TradeLedger.symbol).where(TradeLedger.user_id == user_id)
        if portfolio_ids:
            stmt = stmt.where(TradeLedger.portfolio_id.in_(portfolio_ids))
        stmt = stmt.group_by(TradeLedger.symbol).order_by(TradeLedger.symbol.asc())
        result = await self._session.execute(stmt)
        return [str(item) for item in result.scalars().all()]

    async def list_distinct_symbols_for_portfolio(self, *, portfolio_id: uuid.UUID) -> list[str]:
        stmt = (
            select(TradeLedger.symbol)
            .where(TradeLedger.portfolio_id == portfolio_id)
            .group_by(TradeLedger.symbol)
            .order_by(TradeLedger.symbol.asc())
        )
        result = await self._session.execute(stmt)
        return [str(item) for item in result.scalars().all()]

    async def list_symbol_trades_for_replay(
        self,
        *,
        portfolio_id: uuid.UUID,
        symbol: str,
    ) -> list[TradeLedger]:
        stmt = (
            select(TradeLedger)
            .where(
                TradeLedger.portfolio_id == portfolio_id,
                TradeLedger.symbol == symbol,
            )
            .order_by(TradeLedger.executed_at.asc(), TradeLedger.created_at.asc())
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def list_open_positions(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: Sequence[uuid.UUID] | None = None,
    ) -> list[PositionAggregate]:
        net_quantity = func.sum(
            case(
                (TradeLedger.side == TradeSide.BUY, TradeLedger.quantity),
                else_=-TradeLedger.quantity,
            )
        )
        stmt = (
            select(TradeLedger.portfolio_id, TradeLedger.symbol, net_quantity.label("quantity"))
            .where(TradeLedger.user_id == user_id)
            .group_by(TradeLedger.portfolio_id, TradeLedger.symbol)
            .having(net_quantity > 0)
        )
        if portfolio_ids:
            stmt = stmt.where(TradeLedger.portfolio_id.in_(portfolio_ids))

        result = await self._session.execute(stmt)
        rows = result.all()
        return [
            PositionAggregate(
                portfolio_id=row.portfolio_id,
                symbol=row.symbol,
                quantity=row.quantity,
            )
            for row in rows
        ]

    async def sum_realized_pnl(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_ids: Sequence[uuid.UUID] | None = None,
    ) -> Decimal:
        stmt = select(func.coalesce(func.sum(TradeLedger.realized_pnl), Decimal("0.0000"))).where(
            TradeLedger.user_id == user_id
        )
        if portfolio_ids:
            stmt = stmt.where(TradeLedger.portfolio_id.in_(portfolio_ids))
        result = await self._session.execute(stmt)
        return Decimal(result.scalar_one())

    async def sum_realized_pnl_for_symbol(
        self,
        *,
        user_id: uuid.UUID,
        symbol: str,
        portfolio_ids: Sequence[uuid.UUID] | None = None,
    ) -> Decimal:
        stmt = select(func.coalesce(func.sum(TradeLedger.realized_pnl), Decimal("0.0000"))).where(
            TradeLedger.user_id == user_id,
            TradeLedger.symbol == symbol,
        )
        if portfolio_ids:
            stmt = stmt.where(TradeLedger.portfolio_id.in_(portfolio_ids))
        result = await self._session.execute(stmt)
        return Decimal(result.scalar_one())


class SnapshotQueryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_latest_snapshot(self, portfolio_id: uuid.UUID) -> PortfolioDailySnapshot | None:
        stmt = (
            select(PortfolioDailySnapshot)
            .where(PortfolioDailySnapshot.portfolio_id == portfolio_id)
            .order_by(PortfolioDailySnapshot.snapshot_date.desc())
            .limit(1)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_growth_points_by_portfolio(
        self,
        *,
        portfolio_id: uuid.UUID,
        start_date: date,
    ) -> list[GrowthPoint]:
        stmt = (
            select(PortfolioDailySnapshot.snapshot_date, PortfolioDailySnapshot.total_value)
            .where(
                PortfolioDailySnapshot.portfolio_id == portfolio_id,
                PortfolioDailySnapshot.snapshot_date >= start_date,
            )
            .order_by(PortfolioDailySnapshot.snapshot_date.asc())
        )
        result = await self._session.execute(stmt)
        return [GrowthPoint(snapshot_date=row.snapshot_date, total_value=row.total_value) for row in result.all()]

    async def list_growth_points_by_user(
        self,
        *,
        user_id: uuid.UUID,
        start_date: date,
    ) -> list[GrowthPoint]:
        stmt = (
            select(
                PortfolioDailySnapshot.snapshot_date,
                func.sum(PortfolioDailySnapshot.total_value).label("total_value"),
            )
            .join(Portfolio, Portfolio.id == PortfolioDailySnapshot.portfolio_id)
            .where(
                Portfolio.user_id == user_id,
                Portfolio.is_deleted.is_(False),
                PortfolioDailySnapshot.snapshot_date >= start_date,
            )
            .group_by(PortfolioDailySnapshot.snapshot_date)
            .order_by(PortfolioDailySnapshot.snapshot_date.asc())
        )
        result = await self._session.execute(stmt)
        return [GrowthPoint(snapshot_date=row.snapshot_date, total_value=row.total_value) for row in result.all()]


class AuthRateLimitRepository:
    """Simple Redis-backed limiter for auth endpoints."""

    def __init__(self, redis: aioredis.Redis | None) -> None:
        self._redis = redis

    async def allow(self, *, scope: str, identity: str, max_hits: int, window_seconds: int) -> bool:
        if self._redis is None:
            return True

        key = f"rate:{scope}:{identity.strip().lower()}"
        try:
            async with self._redis.pipeline(transaction=True) as pipe:
                pipe.incr(key)
                pipe.expire(key, window_seconds)
                response = await pipe.execute()
            current = int(response[0])
            return current <= max_hits
        except Exception:
            logger.exception("Rate limiter Redis error; allowing request by fallback policy.")
            return True


class LivePriceRepository:
    """Live price gateway with Redis read-through and DB fallback."""

    def __init__(
        self,
        *,
        redis: aioredis.Redis | None,
        session_factory: async_sessionmaker[AsyncSession],
        key_prefix: str,
        ttl_seconds: int,
    ) -> None:
        self._redis = redis
        self._session_factory = session_factory
        self._key_prefix = key_prefix
        self._ttl_seconds = ttl_seconds

    def _key_for_symbol(self, symbol: str) -> str:
        return f"{self._key_prefix}{symbol.upper()}"

    async def fetch_many(self, symbols: Iterable[str]) -> dict[str, Decimal]:
        normalized_symbols = sorted({symbol.strip().upper() for symbol in symbols if symbol.strip()})
        if not normalized_symbols:
            return {}

        cached_prices, misses, redis_ok = await self._read_many_from_cache(normalized_symbols)
        if not misses:
            return cached_prices

        db_prices = await self._read_many_from_db(misses)
        if db_prices and redis_ok:
            await self._write_many_to_cache(db_prices)

        merged = dict(cached_prices)
        merged.update(db_prices)
        return merged

    async def invalidate_many(self, symbols: Iterable[str]) -> None:
        if self._redis is None:
            return

        keys = [self._key_for_symbol(symbol) for symbol in symbols if symbol.strip()]
        if not keys:
            return

        try:
            await self._redis.delete(*keys)
        except Exception:
            logger.exception("Redis delete failed while invalidating price cache keys.")

    async def _read_many_from_cache(self, symbols: Sequence[str]) -> tuple[dict[str, Decimal], list[str], bool]:
        if self._redis is None:
            return {}, list(symbols), False

        keys = [self._key_for_symbol(symbol) for symbol in symbols]
        price_by_symbol: dict[str, Decimal] = {}
        misses: list[str] = []

        try:
            # Requirement: Redis pipeline + MGET for low-latency bulk reads.
            async with self._redis.pipeline(transaction=False) as pipe:
                pipe.mget(keys)
                pipeline_result = await pipe.execute()
            values = list(pipeline_result[0])
        except Exception:
            logger.exception("Redis MGET pipeline failed; switching to DB fallback.")
            return {}, list(symbols), False

        for symbol, raw in zip(symbols, values):
            if raw is None:
                misses.append(symbol)
                continue

            try:
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8")
                if raw.startswith("{"):
                    payload = json.loads(raw)
                    price = Decimal(payload["price"])
                else:
                    price = Decimal(raw)
                price_by_symbol[symbol] = price
            except Exception:
                misses.append(symbol)

        return price_by_symbol, misses, True

    async def _read_many_from_db(self, symbols: Sequence[str]) -> dict[str, Decimal]:
        if not symbols:
            return {}

        query = text(
            """
            SELECT UPPER(ticker_symbol) AS symbol, current_price
            FROM assets
            WHERE UPPER(ticker_symbol) IN :symbols
            """
        ).bindparams(bindparam("symbols", expanding=True))

        async with self._session_factory() as session:
            result = await session.execute(query, {"symbols": tuple(symbols)})
            rows = result.all()

        return {str(row.symbol): Decimal(row.current_price) for row in rows}

    async def _write_many_to_cache(self, prices: dict[str, Decimal]) -> None:
        if self._redis is None or not prices:
            return

        try:
            async with self._redis.pipeline(transaction=False) as pipe:
                for symbol, price in prices.items():
                    payload = json.dumps({"price": str(price)})
                    pipe.setex(self._key_for_symbol(symbol), self._ttl_seconds, payload)
                await pipe.execute()
        except Exception:
            logger.exception("Redis cache warm-up failed for live prices.")
