"""Application service for concurrent portfolio benchmark attribution."""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from collections import OrderedDict
from dataclasses import dataclass
from datetime import UTC, date, datetime, time
from enum import Enum
from typing import Any

from dateutil.relativedelta import relativedelta
from redis.asyncio import Redis

from app.repositories.benchmarking_read import BenchmarkingReadRepository, PortfolioContextRow
from app.schemas.benchmarking import (
    BenchmarkAttributionPoint,
    BenchmarkAttributionResponse,
    BenchmarkWindow,
)
from app.services.advanced_benchmark_engine import AdvancedBenchmarkEngine, BenchmarkEngineInput, InsufficientHistoryError

logger = logging.getLogger(__name__)

PROBLEM_BASE_URL = "https://smartportfolio.local/problems"
BENCHMARK_CACHE_TTL_SECONDS = 15 * 60
PORTFOLIO_CACHE_TTL_SECONDS = 5 * 60
PORTFOLIO_VERSION_TTL_SECONDS = 30 * 24 * 60 * 60
INVALIDATION_CHANNEL = "events:portfolio-cache-invalidate"
PORTFOLIO_VERSION_KEY_PREFIX = "benchmark:portfolio:version"


@dataclass(slots=True, frozen=True)
class ProblemDetails:
    type: str
    title: str
    status: int
    detail: str
    instance: str


class BenchmarkingProblem(Exception):
    """Domain-level exception with RFC 7807 compatible payload."""

    def __init__(
        self,
        *,
        status_code: int,
        title: str,
        detail: str,
        instance: str,
        type_slug: str,
    ) -> None:
        self.status_code = status_code
        self.problem = ProblemDetails(
            type=f"{PROBLEM_BASE_URL}/{type_slug}",
            title=title,
            status=status_code,
            detail=detail,
            instance=instance,
        )
        super().__init__(detail)


class _LocalTTLCache:
    """Small in-process LRU+TTL cache used as hot tier before Redis."""

    def __init__(self, *, maxsize: int = 512, ttl_seconds: int = 300) -> None:
        self.maxsize = maxsize
        self.ttl_seconds = ttl_seconds
        self._store: OrderedDict[str, tuple[float, Any]] = OrderedDict()
        self._lock = asyncio.Lock()

    async def get(self, key: str) -> Any | None:
        async with self._lock:
            item = self._store.get(key)
            if item is None:
                return None
            expires_at, value = item
            if expires_at <= asyncio.get_running_loop().time():
                self._store.pop(key, None)
                return None
            self._store.move_to_end(key)
            return value

    async def set(self, key: str, value: Any) -> None:
        async with self._lock:
            expires_at = asyncio.get_running_loop().time() + self.ttl_seconds
            if key in self._store:
                self._store.move_to_end(key)
            self._store[key] = (expires_at, value)
            if len(self._store) > self.maxsize:
                self._store.popitem(last=False)


def _json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, Enum):
        return value.value
    raise TypeError(f"Object of type {type(value)!r} is not JSON serializable")


async def invalidate_portfolio_benchmark_cache(
    *,
    portfolio_id: uuid.UUID,
    redis_client: Redis | None,
) -> None:
    """Event-driven invalidation entrypoint called by the trade commit path."""

    if redis_client is None:
        return

    version_key = f"{PORTFOLIO_VERSION_KEY_PREFIX}:{portfolio_id}"
    try:
        await redis_client.incr(version_key)
        await redis_client.expire(version_key, PORTFOLIO_VERSION_TTL_SECONDS)
        await redis_client.publish(
            INVALIDATION_CHANNEL,
            json.dumps(
                {
                    "portfolio_id": str(portfolio_id),
                    "event": "trade_committed",
                    "invalidated_at": datetime.now(UTC).isoformat(),
                },
                separators=(",", ":"),
            ),
        )
        logger.info(
            "benchmark_cache_invalidated",
            extra={
                "portfolio_id": str(portfolio_id),
                "version_key": version_key,
                "channel": INVALIDATION_CHANNEL,
            },
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning("Benchmark cache invalidation failed for %s: %s", portfolio_id, exc)


class AdvancedBenchmarkService:
    """Service orchestrating repository, cache tiers, and Polars quant engine."""

    def __init__(
        self,
        *,
        repository: BenchmarkingReadRepository,
        redis_client: Redis | None,
        engine: AdvancedBenchmarkEngine | None = None,
    ) -> None:
        self.repository = repository
        self.redis_client = redis_client
        self.engine = engine or AdvancedBenchmarkEngine()
        self._benchmark_cache = _LocalTTLCache(maxsize=256, ttl_seconds=BENCHMARK_CACHE_TTL_SECONDS)
        self._portfolio_cache = _LocalTTLCache(maxsize=1024, ttl_seconds=PORTFOLIO_CACHE_TTL_SECONDS)

    async def get_benchmark_attribution(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        window: BenchmarkWindow,
        window_start: date | None,
        window_end: date | None,
        instance: str,
    ) -> tuple[BenchmarkAttributionResponse, Any]:
        context = await self.repository.get_portfolio_context(
            portfolio_id=portfolio_id,
            user_id=user_id,
        )
        if context is None:
            raise BenchmarkingProblem(
                status_code=404,
                title="Portfolio Not Found",
                detail="Portfolio does not exist or is not accessible for this user.",
                instance=instance,
                type_slug="portfolio-not-found",
            )

        resolved_window_start, resolved_window_end, resolved_window = await self._resolve_window(
            portfolio_id=portfolio_id,
            requested_window=window,
            window_start=window_start,
            window_end=window_end,
            instance=instance,
        )

        version = await self._get_portfolio_cache_version(portfolio_id=portfolio_id)
        portfolio_cache_key = self._portfolio_cache_key(
            portfolio_id=portfolio_id,
            user_id=user_id,
            window=resolved_window,
            window_start=resolved_window_start,
            window_end=resolved_window_end,
            version=version,
        )
        cached_payload = await self._get_cached_portfolio_payload(portfolio_cache_key)
        if cached_payload is not None:
            return self._deserialize_payload(cached_payload)

        nav_task = self.repository.fetch_portfolio_nav_rows(
            portfolio_id=portfolio_id,
            start_date=resolved_window_start,
            end_date=resolved_window_end,
        )
        cash_flow_task = self.repository.fetch_portfolio_cash_flow_rows(
            portfolio_id=portfolio_id,
            start_date=resolved_window_start,
            end_date=resolved_window_end,
        )
        benchmark_task = self._get_or_build_benchmark_window(
            window=resolved_window,
            window_start=resolved_window_start,
            window_end=resolved_window_end,
        )
        try:
            nav_rows, cash_flow_rows, benchmark_rows = await asyncio.gather(
                nav_task,
                cash_flow_task,
                benchmark_task,
            )
        except InsufficientHistoryError:
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )
        except ValueError:
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )
        except Exception as exc:  # noqa: BLE001
            raise BenchmarkingProblem(
                status_code=500,
                title="Read Model Failure",
                detail=f"Failed to load benchmark attribution inputs: {exc}",
                instance=instance,
                type_slug="benchmark-input-load-failed",
            ) from exc

        if len(nav_rows) < 2:
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )

        calendar_rows = (
            [{"as_of": row["as_of"]} for row in benchmark_rows]
            if benchmark_rows
            else [{"as_of": row["as_of"]} for row in nav_rows]
        )

        try:
            portfolio_frame = await self.engine.compute_aligned_twr(
                BenchmarkEngineInput(
                    portfolio_nav=nav_rows,
                    portfolio_cash_flows=cash_flow_rows,
                    total_index=[],
                    equal_weighted=[],
                    bank_deposit=[],
                    fixed_income=[],
                    trading_calendar=calendar_rows,
                    window_start=resolved_window_start,
                    window_end=resolved_window_end,
                )
            )
        except InsufficientHistoryError:
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )
        except ValueError:
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Benchmark engine compute failed for portfolio %s; returning empty attribution",
                portfolio_id,
                exc_info=exc,
            )
            return self._empty_result(
                context=context,
                window=resolved_window,
                window_start=resolved_window_start,
                window_end=resolved_window_end,
            )

        merged_frame = self._merge_portfolio_and_benchmarks(
            portfolio_frame=portfolio_frame,
            benchmark_rows=benchmark_rows,
        )
        response = self._build_response(
            context=context,
            frame=merged_frame,
            window=resolved_window,
            window_start=resolved_window_start,
            window_end=resolved_window_end,
        )

        payload = self._serialize_payload(response=response, frame=merged_frame)
        await self._cache_portfolio_payload(portfolio_cache_key, payload)
        return response, merged_frame

    async def _resolve_window(
        self,
        *,
        portfolio_id: uuid.UUID,
        requested_window: BenchmarkWindow,
        window_start: date | None,
        window_end: date | None,
        instance: str,
    ) -> tuple[date, date, BenchmarkWindow]:
        if requested_window == BenchmarkWindow.CUSTOM:
            if window_start is None or window_end is None:
                raise BenchmarkingProblem(
                    status_code=422,
                    title="Invalid Benchmark Window",
                    detail="window_start and window_end are required for CUSTOM window.",
                    instance=instance,
                    type_slug="invalid-window",
                )
            if window_end < window_start:
                raise BenchmarkingProblem(
                    status_code=422,
                    title="Invalid Benchmark Window",
                    detail="window_end must be greater than or equal to window_start.",
                    instance=instance,
                    type_slug="invalid-window",
                )
            return window_start, window_end, requested_window

        latest_day = await self.repository.fetch_latest_portfolio_date(portfolio_id=portfolio_id)
        if latest_day is None:
            today = date.today()
            return today, today, requested_window

        end_date = window_end or latest_day
        if requested_window == BenchmarkWindow.ONE_MONTH:
            start_date = end_date - relativedelta(months=1)
        elif requested_window == BenchmarkWindow.THREE_MONTH:
            start_date = end_date - relativedelta(months=3)
        elif requested_window == BenchmarkWindow.ONE_YEAR:
            start_date = end_date - relativedelta(years=1)
        else:  # YTD
            start_date = date(end_date.year, 1, 1)

        return start_date, end_date, requested_window

    async def _get_or_build_benchmark_window(
        self,
        *,
        window: BenchmarkWindow,
        window_start: date,
        window_end: date,
    ) -> list[dict[str, Any]]:
        cache_key = self._benchmark_cache_key(window=window, window_start=window_start, window_end=window_end)
        local_hit = await self._benchmark_cache.get(cache_key)
        if local_hit is not None:
            return local_hit

        redis_hit = await self._redis_get_json(cache_key)
        if isinstance(redis_hit, list):
            await self._benchmark_cache.set(cache_key, redis_hit)
            return redis_hit

        total_task = self.repository.fetch_benchmark_rows(
            benchmark_code="TOTAL_INDEX",
            start_date=window_start,
            end_date=window_end,
        )
        equal_task = self.repository.fetch_benchmark_rows(
            benchmark_code="EQUAL_WEIGHTED",
            start_date=window_start,
            end_date=window_end,
        )
        bank_task = self.repository.fetch_benchmark_rows(
            benchmark_code="BANK_DEPOSIT",
            start_date=window_start,
            end_date=window_end,
        )
        fixed_task = self.repository.fetch_benchmark_rows(
            benchmark_code="FIXED_INCOME",
            start_date=window_start,
            end_date=window_end,
        )
        try:
            total_rows, equal_rows, bank_rows, fixed_rows = await asyncio.gather(
                total_task,
                equal_task,
                bank_task,
                fixed_task,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Benchmark window read failed; falling back to portfolio-only attribution: %s",
                exc,
            )
            return []

        try:
            benchmark_frame = await self.engine.compute_aligned_twr(
                BenchmarkEngineInput(
                    portfolio_nav=[
                        {"as_of": window_start, "nav": 1.0},
                        {"as_of": window_end, "nav": 1.0},
                    ],
                    portfolio_cash_flows=[],
                    total_index=[
                        {"as_of": row["as_of"], "level": row["close_price_level"]}
                        for row in total_rows
                    ],
                    equal_weighted=[
                        {"as_of": row["as_of"], "level": row["close_price_level"]}
                        for row in equal_rows
                    ],
                    bank_deposit=[
                        {"as_of": row["as_of"], "annual_rate": row["close_annual_rate"]}
                        for row in bank_rows
                    ],
                    fixed_income=[
                        {"as_of": row["as_of"], "level": row["close_price_level"]}
                        for row in fixed_rows
                    ],
                    trading_calendar=None,
                    window_start=window_start,
                    window_end=window_end,
                )
            )
        except (InsufficientHistoryError, ValueError):
            return []
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Benchmark engine failed for cached window; returning portfolio-only attribution: %s",
                exc,
            )
            return []

        rows = benchmark_frame.select(
            "as_of",
            "total_index_cumulative",
            "equal_weighted_cumulative",
            "bank_deposit_cumulative",
            "fixed_income_cumulative",
        ).to_dicts()

        await self._benchmark_cache.set(cache_key, rows)
        await self._redis_set_json(cache_key, rows, ttl_seconds=BENCHMARK_CACHE_TTL_SECONDS)
        return rows

    async def _get_portfolio_cache_version(self, *, portfolio_id: uuid.UUID) -> str:
        if self.redis_client is None:
            return "0"

        key = f"{PORTFOLIO_VERSION_KEY_PREFIX}:{portfolio_id}"
        try:
            raw = await self.redis_client.get(key)
            if raw is None:
                return "0"
            return raw.decode("utf-8") if isinstance(raw, bytes) else str(raw)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to read benchmark portfolio cache version %s: %s", portfolio_id, exc)
            return "0"

    async def _get_cached_portfolio_payload(self, cache_key: str) -> dict[str, Any] | None:
        local_hit = await self._portfolio_cache.get(cache_key)
        if isinstance(local_hit, dict):
            return local_hit

        redis_hit = await self._redis_get_json(cache_key)
        if isinstance(redis_hit, dict):
            await self._portfolio_cache.set(cache_key, redis_hit)
            return redis_hit
        return None

    async def _cache_portfolio_payload(self, cache_key: str, payload: dict[str, Any]) -> None:
        await self._portfolio_cache.set(cache_key, payload)
        await self._redis_set_json(cache_key, payload, ttl_seconds=PORTFOLIO_CACHE_TTL_SECONDS)

    async def _redis_get_json(self, key: str) -> Any | None:
        if self.redis_client is None:
            return None
        try:
            raw = await self.redis_client.get(key)
            if raw is None:
                return None
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            return json.loads(str(raw))
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis read failed for %s: %s", key, exc)
            return None

    async def _redis_set_json(self, key: str, payload: Any, *, ttl_seconds: int) -> None:
        if self.redis_client is None:
            return
        try:
            await self.redis_client.setex(
                key,
                ttl_seconds,
                json.dumps(payload, default=_json_default, separators=(",", ":")),
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redis write failed for %s: %s", key, exc)

    @staticmethod
    def _merge_portfolio_and_benchmarks(*, portfolio_frame: Any, benchmark_rows: list[dict[str, Any]]) -> Any:
        import polars as pl

        benchmark_frame = pl.DataFrame(benchmark_rows)
        if benchmark_frame.is_empty():
            return portfolio_frame

        return (
            portfolio_frame.lazy()
            .select(
                "as_of",
                "portfolio_nav",
                "portfolio_cash_flow",
                "portfolio_daily_return",
                "portfolio_twr_cumulative",
            )
            .join(
                benchmark_frame.lazy().with_columns(pl.col("as_of").cast(pl.Date)),
                on="as_of",
                how="left",
            )
            .sort("as_of")
            .collect()
        )

    @staticmethod
    def _build_response(
        *,
        context: PortfolioContextRow,
        frame: Any,
        window: BenchmarkWindow,
        window_start: date,
        window_end: date,
    ) -> BenchmarkAttributionResponse:
        points: list[BenchmarkAttributionPoint] = []
        for row in frame.to_dicts():
            points.append(
                BenchmarkAttributionPoint(
                    as_of=datetime.combine(row["as_of"], time.min, tzinfo=UTC),
                    portfolio_nav=row.get("portfolio_nav"),
                    portfolio_cash_flow=row.get("portfolio_cash_flow") or 0.0,
                    portfolio_daily_return=row.get("portfolio_daily_return"),
                    portfolio_twr_cumulative=row.get("portfolio_twr_cumulative"),
                    total_index_cumulative=row.get("total_index_cumulative"),
                    equal_weighted_cumulative=row.get("equal_weighted_cumulative"),
                    bank_deposit_cumulative=row.get("bank_deposit_cumulative"),
                    fixed_income_cumulative=row.get("fixed_income_cumulative"),
                )
            )

        return BenchmarkAttributionResponse(
            portfolio_id=context.portfolio_id,
            generated_at=datetime.now(UTC),
            window_start=datetime.combine(window_start, time.min, tzinfo=UTC),
            window_end=datetime.combine(window_end, time.min, tzinfo=UTC),
            window=window,
            base_currency=context.base_currency,
            points=points,
        )

    @staticmethod
    def _empty_result(
        *,
        context: PortfolioContextRow,
        window: BenchmarkWindow,
        window_start: date,
        window_end: date,
    ) -> tuple[BenchmarkAttributionResponse, Any]:
        import polars as pl

        response = BenchmarkAttributionResponse(
            portfolio_id=context.portfolio_id,
            generated_at=datetime.now(UTC),
            window_start=datetime.combine(window_start, time.min, tzinfo=UTC),
            window_end=datetime.combine(window_end, time.min, tzinfo=UTC),
            window=window,
            base_currency=context.base_currency,
            points=[],
        )
        return response, pl.DataFrame({"as_of": []})

    @staticmethod
    def _serialize_payload(*, response: BenchmarkAttributionResponse, frame: Any) -> dict[str, Any]:
        return {
            "response": response.model_dump(mode="json"),
            "rows": frame.to_dicts(),
        }

    @staticmethod
    def _deserialize_payload(payload: dict[str, Any]) -> tuple[BenchmarkAttributionResponse, Any]:
        import polars as pl

        response = BenchmarkAttributionResponse.model_validate(payload.get("response") or {})
        rows = payload.get("rows") or []
        frame = pl.DataFrame(rows) if rows else pl.DataFrame({"as_of": []})
        if "as_of" in frame.columns:
            frame = frame.with_columns(pl.col("as_of").cast(pl.Date))
        return response, frame

    @staticmethod
    def _benchmark_cache_key(*, window: BenchmarkWindow, window_start: date, window_end: date) -> str:
        return f"benchmark:window:{window.value}:{window_start.isoformat()}:{window_end.isoformat()}"

    @staticmethod
    def _portfolio_cache_key(
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        window: BenchmarkWindow,
        window_start: date,
        window_end: date,
        version: str,
    ) -> str:
        return (
            "benchmark:portfolio:"
            f"{portfolio_id}:{user_id}:{window.value}:{window_start.isoformat()}:"
            f"{window_end.isoformat()}:v{version}"
        )
