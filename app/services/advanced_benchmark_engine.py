"""Polars Lazy quant engine for ultra-low-latency benchmark attribution."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from typing import Any

from starlette.concurrency import run_in_threadpool

try:  # pragma: no cover - optional dependency guard
    import polars as pl
except Exception:  # pragma: no cover - optional dependency guard
    pl = None


class InsufficientHistoryError(ValueError):
    """Raised when there are not enough observations to compute linked returns."""


@dataclass(slots=True, frozen=True)
class BenchmarkEngineInput:
    """Input payload of raw daily or sparse benchmark observations."""

    portfolio_nav: pl.DataFrame | list[dict[str, Any]]
    portfolio_cash_flows: pl.DataFrame | list[dict[str, Any]]
    total_index: pl.DataFrame | list[dict[str, Any]]
    equal_weighted: pl.DataFrame | list[dict[str, Any]]
    bank_deposit: pl.DataFrame | list[dict[str, Any]]
    fixed_income: pl.DataFrame | list[dict[str, Any]]
    trading_calendar: pl.DataFrame | list[dict[str, Any]] | None = None
    window_start: date | datetime | None = None
    window_end: date | datetime | None = None


class AdvancedBenchmarkEngine:
    """Vectorized TWR engine based on Polars LazyFrame execution graphs."""

    def __init__(self, *, day_count_base: int = 365, min_required_points: int = 2) -> None:
        if pl is None:
            raise RuntimeError(
                "polars is required for AdvancedBenchmarkEngine. Install polars to enable this module."
            )
        if day_count_base <= 0:
            raise ValueError("day_count_base must be positive")
        if min_required_points < 2:
            raise ValueError("min_required_points must be >= 2")

        self.day_count_base = day_count_base
        self.min_required_points = min_required_points

    async def compute_aligned_twr(self, payload: BenchmarkEngineInput) -> pl.DataFrame:
        """Collect the lazy attribution graph on a worker thread."""

        return await run_in_threadpool(self.compute_aligned_twr_sync, payload)

    def compute_aligned_twr_sync(self, payload: BenchmarkEngineInput) -> pl.DataFrame:
        """Synchronous collection helper for non-async call sites."""

        graph = self.build_alignment_graph(payload)
        frame = graph.collect()
        if frame.height < self.min_required_points:
            raise InsufficientHistoryError(
                f"Need at least {self.min_required_points} aligned points, got {frame.height}."
            )
        return frame

    def build_alignment_graph(self, payload: BenchmarkEngineInput) -> pl.LazyFrame:
        """Build one lazy graph that computes true-TWR and aligned benchmark series."""

        calendar_lf = self._calendar_lazyframe(payload)

        portfolio_lf = self._build_portfolio_series(
            calendar_lf=calendar_lf,
            nav_lf=self._to_series_lf(payload.portfolio_nav, value_col="nav"),
            cash_flow_lf=self._to_series_lf(payload.portfolio_cash_flows, value_col="cash_flow"),
        )
        total_index_lf = self._build_price_benchmark_series(
            calendar_lf=calendar_lf,
            benchmark_lf=self._to_series_lf(payload.total_index, value_col="level"),
            output_col="total_index_cumulative",
        )
        equal_weighted_lf = self._build_price_benchmark_series(
            calendar_lf=calendar_lf,
            benchmark_lf=self._to_series_lf(payload.equal_weighted, value_col="level"),
            output_col="equal_weighted_cumulative",
        )
        fixed_income_lf = self._build_price_benchmark_series(
            calendar_lf=calendar_lf,
            benchmark_lf=self._to_series_lf(payload.fixed_income, value_col="level"),
            output_col="fixed_income_cumulative",
        )
        bank_deposit_lf = self._build_bank_deposit_series(
            calendar_lf=calendar_lf,
            bank_rate_lf=self._to_series_lf(payload.bank_deposit, value_col="annual_rate"),
            output_col="bank_deposit_cumulative",
        )

        return (
            portfolio_lf.join(total_index_lf, on="as_of", how="left")
            .join(equal_weighted_lf, on="as_of", how="left")
            .join(bank_deposit_lf, on="as_of", how="left")
            .join(fixed_income_lf, on="as_of", how="left")
            .sort("as_of")
        )

    def _calendar_lazyframe(self, payload: BenchmarkEngineInput) -> pl.LazyFrame:
        if payload.trading_calendar is not None:
            return self._to_calendar_lf(payload.trading_calendar)

        start, end = self._resolve_window_bounds(payload)
        return pl.LazyFrame(
            {
                "as_of": pl.date_range(
                    start=start,
                    end=end,
                    interval="1d",
                    eager=True,
                )
            }
        )

    def _resolve_window_bounds(self, payload: BenchmarkEngineInput) -> tuple[date, date]:
        if payload.window_start is not None and payload.window_end is not None:
            start = self._coerce_date(payload.window_start)
            end = self._coerce_date(payload.window_end)
            if end < start:
                raise ValueError("window_end must be greater than or equal to window_start")
            return start, end

        bounds_frame = (
            pl.concat(
                [
                    self._to_series_lf(payload.portfolio_nav, value_col="nav").select(
                        pl.min("as_of").alias("window_start"),
                        pl.max("as_of").alias("window_end"),
                    ),
                    self._to_series_lf(payload.total_index, value_col="level").select(
                        pl.min("as_of").alias("window_start"),
                        pl.max("as_of").alias("window_end"),
                    ),
                    self._to_series_lf(payload.equal_weighted, value_col="level").select(
                        pl.min("as_of").alias("window_start"),
                        pl.max("as_of").alias("window_end"),
                    ),
                    self._to_series_lf(payload.bank_deposit, value_col="annual_rate").select(
                        pl.min("as_of").alias("window_start"),
                        pl.max("as_of").alias("window_end"),
                    ),
                    self._to_series_lf(payload.fixed_income, value_col="level").select(
                        pl.min("as_of").alias("window_start"),
                        pl.max("as_of").alias("window_end"),
                    ),
                ],
                how="vertical_relaxed",
            )
            .select(
                pl.col("window_start").min().alias("resolved_start"),
                pl.col("window_end").max().alias("resolved_end"),
            )
            .collect()
        )

        start = bounds_frame["resolved_start"][0]
        end = bounds_frame["resolved_end"][0]
        if start is None or end is None:
            raise InsufficientHistoryError("No timestamps found for benchmark alignment.")
        return start, end

    def _build_portfolio_series(
        self,
        *,
        calendar_lf: pl.LazyFrame,
        nav_lf: pl.LazyFrame,
        cash_flow_lf: pl.LazyFrame,
    ) -> pl.LazyFrame:
        nav_col = pl.col("portfolio_nav")
        cash_flow_col = pl.col("portfolio_cash_flow")
        prev_nav_col = nav_col.shift(1)
        denominator = prev_nav_col + (cash_flow_col * 0.5)
        numerator = nav_col - prev_nav_col - cash_flow_col

        raw_daily_return = (
            pl.when(
                nav_col.is_null()
                | prev_nav_col.is_null()
                | denominator.is_null()
                | (denominator.abs() < 1e-12)
            )
            .then(None)
            .otherwise(numerator / denominator)
            .alias("portfolio_daily_return")
        )

        return (
            calendar_lf.sort("as_of")
            .join(nav_lf.sort("as_of"), on="as_of", how="left")
            .join(cash_flow_lf.sort("as_of"), on="as_of", how="left")
            .with_columns(
                # _to_series_lf emits canonical value columns named "nav"/"cash_flow".
                # Normalize them here before downstream return/TWR math.
                pl.col("nav").forward_fill().alias("portfolio_nav"),
                pl.col("cash_flow").fill_null(0.0).alias("portfolio_cash_flow"),
            )
            .with_columns(raw_daily_return)
            .with_columns(
                (
                    (pl.col("portfolio_daily_return").fill_null(0.0) + 1.0).cum_prod() - 1.0
                ).alias("_portfolio_twr_cumulative_raw"),
                pl.col("portfolio_nav").is_not_null().cum_max().alias("_has_portfolio_state"),
            )
            .with_columns(
                pl.when(pl.col("_has_portfolio_state"))
                .then(pl.col("_portfolio_twr_cumulative_raw"))
                .otherwise(None)
                .alias("portfolio_twr_cumulative")
            )
            .select(
                "as_of",
                "portfolio_nav",
                "portfolio_cash_flow",
                "portfolio_daily_return",
                "portfolio_twr_cumulative",
            )
        )

    def _build_price_benchmark_series(
        self,
        *,
        calendar_lf: pl.LazyFrame,
        benchmark_lf: pl.LazyFrame,
        output_col: str,
    ) -> pl.LazyFrame:
        aligned_level = pl.col("level").forward_fill().alias("level")
        prev_level = pl.col("level").shift(1)
        raw_daily_return = (
            pl.when(
                pl.col("level").is_null() | prev_level.is_null() | (prev_level <= 0)
            )
            .then(None)
            .otherwise((pl.col("level") / prev_level) - 1.0)
            .alias("_daily_return")
        )

        return (
            calendar_lf.sort("as_of")
            .join_asof(
                benchmark_lf.sort("as_of"),
                on="as_of",
                strategy="backward",
            )
            .with_columns(aligned_level)
            .with_columns(raw_daily_return)
            .with_columns(
                ((pl.col("_daily_return").fill_null(0.0) + 1.0).cum_prod() - 1.0).alias("_cum_raw"),
                pl.col("level").is_not_null().cum_max().alias("_has_level"),
            )
            .with_columns(
                pl.when(pl.col("_has_level")).then(pl.col("_cum_raw")).otherwise(None).alias(output_col)
            )
            .select("as_of", output_col)
        )

    def _build_bank_deposit_series(
        self,
        *,
        calendar_lf: pl.LazyFrame,
        bank_rate_lf: pl.LazyFrame,
        output_col: str,
    ) -> pl.LazyFrame:
        day_count = float(self.day_count_base)
        rate_col = pl.col("annual_rate")
        elapsed_days = (
            pl.col("as_of")
            .cast(pl.Datetime("us"))
            .diff()
            .dt.total_days()
            .fill_null(1)
            .clip(lower_bound=1)
            .cast(pl.Float64)
            .alias("_elapsed_days")
        )

        raw_daily_return = (
            pl.when(rate_col.is_null())
            .then(None)
            .otherwise(((rate_col + 1.0).pow(pl.col("_elapsed_days") / day_count)) - 1.0)
            .alias("_daily_return")
        )

        return (
            calendar_lf.sort("as_of")
            .join_asof(
                bank_rate_lf.sort("as_of"),
                on="as_of",
                strategy="backward",
            )
            .with_columns(pl.col("annual_rate").forward_fill().alias("annual_rate"))
            .with_columns(elapsed_days)
            .with_columns(raw_daily_return)
            .with_columns(
                ((pl.col("_daily_return").fill_null(0.0) + 1.0).cum_prod() - 1.0).alias("_cum_raw"),
                pl.col("annual_rate").is_not_null().cum_max().alias("_has_rate"),
            )
            .with_columns(
                pl.when(pl.col("_has_rate")).then(pl.col("_cum_raw")).otherwise(None).alias(output_col)
            )
            .select("as_of", output_col)
        )

    @staticmethod
    def _to_series_lf(
        data: pl.DataFrame | list[dict[str, Any]],
        *,
        value_col: str,
    ) -> pl.LazyFrame:
        if isinstance(data, pl.DataFrame):
            frame = data
        else:
            frame = (
                pl.DataFrame(data)
                if data
                else pl.DataFrame(schema={"as_of": pl.Date, value_col: pl.Float64})
            )

        if "as_of" not in frame.columns:
            raise ValueError("Input series must include an 'as_of' column.")
        if value_col not in frame.columns:
            raise ValueError(f"Input series must include a '{value_col}' column.")

        return (
            frame.lazy()
            .select(
                pl.col("as_of").cast(pl.Date).alias("as_of"),
                pl.col(value_col).cast(pl.Float64).alias(value_col),
            )
            .drop_nulls(subset=["as_of"])
            .group_by("as_of")
            .agg(pl.col(value_col).last().alias(value_col))
            .sort("as_of")
        )

    @staticmethod
    def _coerce_date(value: date | datetime) -> date:
        if isinstance(value, datetime):
            return value.date()
        return value

    @staticmethod
    def _to_calendar_lf(data: pl.DataFrame | list[dict[str, Any]]) -> pl.LazyFrame:
        if isinstance(data, pl.DataFrame):
            frame = data
        else:
            frame = pl.DataFrame(data) if data else pl.DataFrame(schema={"as_of": pl.Date})

        if "as_of" not in frame.columns:
            raise ValueError("Trading calendar must include an 'as_of' column.")

        return (
            frame.lazy()
            .select(pl.col("as_of").cast(pl.Date).alias("as_of"))
            .drop_nulls(subset=["as_of"])
            .unique(subset=["as_of"])
            .sort("as_of")
        )
