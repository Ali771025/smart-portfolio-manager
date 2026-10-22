"""High-throughput quantitative engine for analytics and PnL replay.

Design goals:
- Keep monetary values in Decimal semantics (no float drift for prices/PnL).
- Use vectorized Pandas/NumPy operations where mathematically possible.
- Keep inventory replay (WAC/FIFO) linear-time and cache-friendly for millions
  of rows by processing each asset stream once.
"""

from __future__ import annotations

import math
from collections import deque
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_EVEN
from typing import Any, Iterable, Mapping

import numpy as np
import pandas as pd

try:
    import polars as pl
except Exception:  # pragma: no cover - optional dependency
    pl = None

TRADING_DAYS_PER_YEAR = 252
VAR_TAIL_PROBABILITIES = np.array([0.05, 0.01], dtype=np.float64)
# Standard normal left-tail z-scores for 95% and 99% one-sided VaR.
VAR_Z_SCORES = np.array([-1.6448536269514722, -2.3263478740408408], dtype=np.float64)

MONEY_QUANT = Decimal("0.00000001")
QTY_QUANT = Decimal("0.0000000001")
RATIO_QUANT = Decimal("0.0000000001")
MONEY_SCALE = 10**8
QTY_SCALE = 10**10

BUY_MARKERS = {"BUY", "B", "1", 1}
SELL_MARKERS = {"SELL", "S", "-1", -1}


@dataclass(slots=True)
class _ReplayState:
    """Mutable inventory state for one (portfolio, asset) stream."""

    open_qty: int = 0
    open_cost: int = 0
    realized_pnl: int = 0


def _finite_or_none(value: float) -> float | None:
    return float(value) if math.isfinite(float(value)) else None


def _prepare_series(values: pd.Series, column_name: str) -> pd.Series:
    series = pd.Series(values, copy=True)
    series.index = pd.to_datetime(series.index)
    series = pd.to_numeric(series, errors="coerce")
    series = series[~series.index.duplicated(keep="last")]
    series = series.sort_index()
    series.name = column_name
    return series


def _to_decimal(value: Any, quant: Decimal) -> Decimal:
    if value is None or (not isinstance(value, Decimal) and pd.isna(value)):
        return Decimal("0").quantize(quant)
    if isinstance(value, Decimal):
        return value.quantize(quant, rounding=ROUND_HALF_EVEN)
    if isinstance(value, (np.integer, int)):
        return Decimal(int(value)).quantize(quant, rounding=ROUND_HALF_EVEN)
    if isinstance(value, (np.floating, float)):
        return Decimal(str(value)).quantize(quant, rounding=ROUND_HALF_EVEN)
    return Decimal(str(value)).quantize(quant, rounding=ROUND_HALF_EVEN)


def _money_to_int(value: Any) -> int:
    dec = _to_decimal(value, MONEY_QUANT)
    return int((dec * MONEY_SCALE).to_integral_value(rounding=ROUND_HALF_EVEN))


def _qty_to_int(value: Any) -> int:
    dec = _to_decimal(value, QTY_QUANT)
    return int((dec * QTY_SCALE).to_integral_value(rounding=ROUND_HALF_EVEN))


def _int_to_money(value: int) -> Decimal:
    return (Decimal(value) / Decimal(MONEY_SCALE)).quantize(MONEY_QUANT, rounding=ROUND_HALF_EVEN)


def _int_to_qty(value: int) -> Decimal:
    return (Decimal(value) / Decimal(QTY_SCALE)).quantize(QTY_QUANT, rounding=ROUND_HALF_EVEN)


def _normalize_side(value: Any) -> str:
    if isinstance(value, str):
        candidate = value.strip().upper()
    else:
        candidate = value

    if candidate in BUY_MARKERS:
        return "BUY"
    if candidate in SELL_MARKERS:
        return "SELL"
    raise ValueError(f"Unsupported trade side: {value!r}")


def _to_pandas_frame(frame: pd.DataFrame | Any) -> pd.DataFrame:
    if isinstance(frame, pd.DataFrame):
        return frame
    if pl is not None and isinstance(frame, pl.DataFrame):
        return frame.to_pandas()
    raise TypeError("Expected a pandas.DataFrame or polars.DataFrame")


def calculate_vwap_by_asset(
    trades: pd.DataFrame | Any,
    *,
    group_cols: tuple[str, ...] = ("portfolio_id", "asset_id"),
    side_col: str = "side",
    quantity_col: str = "quantity",
    price_col: str = "price",
    corporate_action_factor_col: str = "corporate_action_factor",
) -> pd.DataFrame:
    """Compute split/dividend-aware VWAP using exact Decimal arithmetic.

    Corporate actions are applied via `corporate_action_factor` where each row's
    factor represents cumulative quantity multiplier to current share basis.

    VWAP = sum(price * quantity) / sum(quantity * corporate_action_factor)
    """

    if pl is not None and isinstance(trades, pl.DataFrame):
        missing = [
            column
            for column in (*group_cols, side_col, quantity_col, price_col)
            if column not in trades.columns
        ]
        if missing:
            raise ValueError(f"Missing required VWAP columns: {missing}")

        factor_expr = (
            pl.col(corporate_action_factor_col)
            if corporate_action_factor_col in trades.columns
            else pl.lit(Decimal("1"))
        )

        return (
            trades.lazy()
            .with_columns(
                pl.col(side_col).cast(pl.Utf8).str.to_uppercase().alias("_side"),
                (pl.col(quantity_col) * factor_expr).alias("_adj_qty"),
                (pl.col(price_col) * pl.col(quantity_col)).alias("_notional"),
            )
            .filter(pl.col("_side").is_in(["BUY", "B", "1"]))
            .group_by(list(group_cols))
            .agg(
                pl.sum("_adj_qty").alias("total_adjusted_quantity"),
                pl.sum("_notional").alias("total_notional"),
            )
            .with_columns(
                (pl.col("total_notional") / pl.col("total_adjusted_quantity")).alias("vwap")
            )
            .select([*group_cols, "total_adjusted_quantity", "total_notional", "vwap"])
            .collect()
            .to_pandas()
        )

    frame = _to_pandas_frame(trades).copy()
    required = [*group_cols, side_col, quantity_col, price_col]
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise ValueError(f"Missing required VWAP columns: {missing}")

    if corporate_action_factor_col not in frame.columns:
        frame[corporate_action_factor_col] = Decimal("1")

    side = frame[side_col].map(_normalize_side)
    buys = frame.loc[side == "BUY"].copy()

    buys["_adj_qty"] = buys[quantity_col] * buys[corporate_action_factor_col]
    buys["_notional"] = buys[quantity_col] * buys[price_col]

    aggregated = (
        buys.groupby(list(group_cols), dropna=False, sort=False)
        .agg(
            total_adjusted_quantity=("_adj_qty", "sum"),
            total_notional=("_notional", "sum"),
        )
        .reset_index()
    )

    aggregated["vwap"] = aggregated["total_notional"] / aggregated["total_adjusted_quantity"]
    return aggregated


def _replay_wac(
    rows: Iterable[tuple[str, int, int, int]],
    *,
    strict_inventory: bool,
) -> _ReplayState:
    state = _ReplayState()

    for side, qty, notional, fees in rows:
        if qty <= 0:
            raise ValueError("Trade quantity must be positive after corporate-action adjustments")

        if side == "BUY":
            total_cost = notional + fees
            state.open_cost += total_cost
            state.open_qty += qty
            continue

        if state.open_qty <= 0:
            if strict_inventory:
                raise ValueError("SELL encountered with empty inventory")
            continue

        sell_qty = min(qty, state.open_qty)
        if strict_inventory and sell_qty != qty:
            raise ValueError("SELL quantity exceeds current inventory")

        # WAC per adjusted share in MONEY_SCALE precision.
        wac_unit_price = (state.open_cost * QTY_SCALE) // state.open_qty
        cost_of_sold = (wac_unit_price * sell_qty) // QTY_SCALE
        proceeds = notional - fees

        state.realized_pnl += proceeds - cost_of_sold
        state.open_cost -= cost_of_sold
        state.open_qty -= sell_qty

        if state.open_qty == 0:
            state.open_cost = 0

    return state


def _replay_fifo(
    rows: Iterable[tuple[str, int, int, int]],
    *,
    strict_inventory: bool,
) -> _ReplayState:
    state = _ReplayState()
    lots: deque[tuple[int, int]] = deque()  # (qty, unit_cost_in_money_scale)

    for side, qty, notional, fees in rows:
        if qty <= 0:
            raise ValueError("Trade quantity must be positive after corporate-action adjustments")

        if side == "BUY":
            total_cost = notional + fees
            unit_cost = (total_cost * QTY_SCALE) // qty
            lots.append((qty, unit_cost))
            state.open_qty += qty
            state.open_cost += total_cost
            continue

        if state.open_qty <= 0:
            if strict_inventory:
                raise ValueError("SELL encountered with empty inventory")
            continue

        sell_qty_requested = qty
        sell_qty = min(sell_qty_requested, state.open_qty)
        if strict_inventory and sell_qty != sell_qty_requested:
            raise ValueError("SELL quantity exceeds current inventory")

        qty_remaining = sell_qty
        cost_of_sold = 0

        while qty_remaining > 0 and lots:
            lot_qty, lot_unit_cost = lots[0]
            take_qty = min(qty_remaining, lot_qty)
            cost_of_sold += (lot_unit_cost * take_qty) // QTY_SCALE

            if take_qty == lot_qty:
                lots.popleft()
            else:
                lots[0] = (lot_qty - take_qty, lot_unit_cost)

            qty_remaining -= take_qty

        proceeds = notional - fees
        state.realized_pnl += proceeds - cost_of_sold
        state.open_qty -= sell_qty
        state.open_cost -= cost_of_sold

        if state.open_qty == 0:
            state.open_cost = 0
            lots.clear()

    return state


def calculate_inventory_pnl(
    trades: pd.DataFrame | Any,
    *,
    current_prices: Mapping[Any, Decimal | int | float | str] | None = None,
    accounting_method: str = "WAC",
    group_cols: tuple[str, ...] = ("portfolio_id", "asset_id"),
    asset_col: str = "asset_id",
    side_col: str = "side",
    quantity_col: str = "quantity",
    price_col: str = "price",
    fees_col: str = "fees",
    event_time_col: str = "executed_at",
    corporate_action_factor_col: str = "corporate_action_factor",
    strict_inventory: bool = True,
) -> pd.DataFrame:
    """Replay inventory and compute realized/unrealized PnL for WAC or FIFO.

    Notes:
    - For exactness all monetary math is done in scaled integers derived from
      Decimal values.
    - This is O(N) over rows after sort and supports millions of trades.
    """

    frame = _to_pandas_frame(trades).copy()
    required = [*group_cols, side_col, quantity_col, price_col]
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise ValueError(f"Missing required inventory columns: {missing}")

    if fees_col not in frame.columns:
        frame[fees_col] = Decimal("0")
    if corporate_action_factor_col not in frame.columns:
        frame[corporate_action_factor_col] = Decimal("1")
    if event_time_col not in frame.columns:
        frame[event_time_col] = pd.Timestamp.min

    # Stable sort preserves ingest order for ties at identical timestamps.
    frame = frame.sort_values(list(group_cols) + [event_time_col], kind="mergesort")

    normalized_method = accounting_method.upper()
    if normalized_method not in {"WAC", "FIFO"}:
        raise ValueError("accounting_method must be either 'WAC' or 'FIFO'")
    replay_fn = _replay_wac if normalized_method == "WAC" else _replay_fifo
    price_lookup: Mapping[Any, Decimal | int | float | str] = current_prices or {}

    records: list[dict[str, Any]] = []
    for keys, group in frame.groupby(list(group_cols), sort=False, dropna=False):
        key_tuple = keys if isinstance(keys, tuple) else (keys,)
        side_values = group[side_col].map(_normalize_side).to_numpy()

        quantities = group[quantity_col].map(lambda v: _to_decimal(v, QTY_QUANT))
        prices = group[price_col].map(lambda v: _to_decimal(v, MONEY_QUANT))
        factors = group[corporate_action_factor_col].map(lambda v: _to_decimal(v, QTY_QUANT))
        fees = group[fees_col].map(_money_to_int)

        qty_adj_int = [int((qty * factor * QTY_SCALE).to_integral_value(rounding=ROUND_HALF_EVEN))
                       for qty, factor in zip(quantities, factors)]
        notional_int = [int(((qty * price) * MONEY_SCALE).to_integral_value(rounding=ROUND_HALF_EVEN))
                        for qty, price in zip(quantities, prices)]
        fees_int = fees.tolist()

        state = replay_fn(
            zip(side_values, qty_adj_int, notional_int, fees_int),
            strict_inventory=strict_inventory,
        )

        if state.open_qty > 0:
            vwap_int = (state.open_cost * QTY_SCALE) // state.open_qty
        else:
            vwap_int = 0

        asset_key = key_tuple[list(group_cols).index(asset_col)] if asset_col in group_cols else group[asset_col].iloc[0]

        market_price_raw = price_lookup.get(asset_key)
        market_price: Decimal | None = None
        unrealized_pnl: Decimal | None = None
        if market_price_raw is not None:
            market_price_int = _money_to_int(market_price_raw)
            unrealized_int = ((market_price_int - vwap_int) * state.open_qty) // QTY_SCALE
            market_price = _int_to_money(market_price_int)
            unrealized_pnl = _int_to_money(unrealized_int)

        record: dict[str, Any] = {
            group_cols[idx]: key_tuple[idx] for idx in range(len(group_cols))
        }
        record.update(
            {
                "accounting_method": normalized_method,
                "open_quantity": _int_to_qty(state.open_qty),
                "vwap": _int_to_money(vwap_int),
                "realized_pnl": _int_to_money(state.realized_pnl),
                "market_price": market_price,
                "unrealized_pnl": unrealized_pnl,
            }
        )
        records.append(record)

    return pd.DataFrame(records)


def calculate_max_drawdown(values: pd.Series | list[Decimal] | np.ndarray) -> Decimal | None:
    """Vectorized maximum drawdown for an equity curve (returns ratio in [0,1])."""

    array = np.asarray(pd.to_numeric(values, errors="coerce"), dtype=np.float64)
    array = array[np.isfinite(array)]
    array = array[array > 0]

    if array.size == 0:
        return None

    running_peaks = np.maximum.accumulate(array)
    drawdowns = (array / running_peaks) - 1.0
    maximum_drawdown = float(-np.min(drawdowns))
    return Decimal(str(maximum_drawdown)).quantize(RATIO_QUANT, rounding=ROUND_HALF_EVEN)


def build_portfolio_return_series(portfolio_values: pd.Series) -> pd.Series:
    """Compute standalone daily portfolio returns for univariate risk stats."""

    portfolio = _prepare_series(portfolio_values, "portfolio")
    portfolio = portfolio[portfolio > 0]
    returns = portfolio.pct_change()
    returns = returns.replace([np.inf, -np.inf], np.nan).dropna()
    return returns.astype(np.float64)


def align_price_series(
    *,
    portfolio_values: pd.Series,
    benchmark_values: pd.Series,
) -> pd.DataFrame:
    """Align portfolio and benchmark prices on a common calendar via ffill.

    Alignment pipeline:
      1) union of both date indexes,
      2) forward-fill missing observations (non-trading days),
      3) drop rows still missing either side,
      4) keep strictly positive price levels for return math.
    """

    portfolio = _prepare_series(portfolio_values, "portfolio")
    benchmark = _prepare_series(benchmark_values, "benchmark")

    union_index = portfolio.index.union(benchmark.index).sort_values()
    aligned = pd.concat([portfolio, benchmark], axis=1).reindex(union_index).ffill()
    aligned = aligned.dropna(subset=["portfolio", "benchmark"])

    return aligned[(aligned["portfolio"] > 0) & (aligned["benchmark"] > 0)]


def build_return_frame(aligned_prices: pd.DataFrame) -> pd.DataFrame:
    """Compute daily arithmetic returns for both portfolio and benchmark."""

    returns = aligned_prices.pct_change()
    returns = returns.replace([np.inf, -np.inf], np.nan).dropna(how="any")
    return returns[["portfolio", "benchmark"]]


def calculate_advanced_risk_metrics(
    *,
    portfolio_values: pd.Series,
    benchmark_values: pd.Series,
    risk_free_rate: float = 0.0,
    trading_days_per_year: int = TRADING_DAYS_PER_YEAR,
) -> dict[str, Any]:
    """Calculate vectorized advanced risk metrics.

    Metrics:
      - Sortino Ratio: (R_p - R_f) / sigma_d
      - Maximum Drawdown: max((Peak - Trough) / Peak)
      - Beta: Cov(R_p, R_m) / Var(R_m)
      - Alpha (Jensen): R_p - [R_f + beta * (R_m - R_f)]
      - VaR (Historical + Parametric) for 95% and 99%
    """

    portfolio_return_series = build_portfolio_return_series(portfolio_values)
    if portfolio_return_series.empty:
        return {
            "sortino_ratio": None,
            "maximum_drawdown": None,
            "beta": None,
            "alpha": None,
            "value_at_risk": {
                "historical": {"confidence_95": None, "confidence_99": None},
                "parametric": {"confidence_95": None, "confidence_99": None},
            },
        }

    portfolio_returns = portfolio_return_series.to_numpy(dtype=np.float64)
    annualization_sqrt = math.sqrt(float(trading_days_per_year))

    # Sortino ratio:
    #   excess_t = r_p,t - r_f,daily
    #   sigma_d  = sqrt(E[min(excess_t, 0)^2])
    #   Sortino  = (E[r_p]*N - r_f,annual) / (sigma_d * sqrt(N))
    risk_free_daily = risk_free_rate / float(trading_days_per_year)
    excess_returns = portfolio_returns - risk_free_daily
    downside_returns = np.minimum(excess_returns, 0.0)
    downside_deviation_daily = float(np.sqrt(np.mean(np.square(downside_returns))))

    annualized_portfolio_return = float(np.mean(portfolio_returns) * trading_days_per_year)
    if downside_deviation_daily > 0:
        sortino_ratio = (annualized_portfolio_return - risk_free_rate) / (
            downside_deviation_daily * annualization_sqrt
        )
    else:
        sortino_ratio = math.nan

    # Maximum drawdown:
    #   wealth_t    = Π(1 + r_p,t)
    #   drawdown_t  = wealth_t / cummax(wealth_t) - 1
    #   MDD         = -min(drawdown_t)
    wealth_index = np.cumprod(1.0 + portfolio_returns)
    running_peaks = np.maximum.accumulate(wealth_index)
    drawdowns = (wealth_index / running_peaks) - 1.0
    maximum_drawdown = float(-np.min(drawdowns))

    # Beta:
    #   beta = Cov(R_p, R_m) / Var(R_m)
    aligned_prices = align_price_series(
        portfolio_values=portfolio_values,
        benchmark_values=benchmark_values,
    )
    aligned_returns = build_return_frame(aligned_prices)
    if aligned_returns.empty:
        beta = math.nan
        alpha = math.nan
    else:
        benchmark_returns = aligned_returns["benchmark"].to_numpy(dtype=np.float64)
        aligned_portfolio_returns = aligned_returns["portfolio"].to_numpy(dtype=np.float64)
        benchmark_variance = float(np.var(benchmark_returns, ddof=0))
        if benchmark_variance > 0:
            covariance = float(np.cov(aligned_portfolio_returns, benchmark_returns, ddof=0)[0, 1])
            beta = covariance / benchmark_variance
        else:
            beta = math.nan

        # Alpha (Jensen):
        #   alpha = R_p - [R_f + beta * (R_m - R_f)]
        annualized_market_return = float(np.mean(benchmark_returns) * trading_days_per_year)
        aligned_annualized_portfolio_return = (
            float(np.mean(aligned_portfolio_returns) * trading_days_per_year)
        )
        alpha = aligned_annualized_portfolio_return - (
            risk_free_rate + beta * (annualized_market_return - risk_free_rate)
        )

    # Historical VaR (one-day, left-tail quantiles):
    #   VaR_c = -Q_{1-c}(R_p)
    historical_var = -np.quantile(portfolio_returns, VAR_TAIL_PROBABILITIES)
    historical_var = np.clip(historical_var, a_min=0.0, a_max=None)

    # Parametric VaR (Gaussian):
    #   VaR_c = -(mu + z_{1-c} * sigma)
    mu = float(np.mean(portfolio_returns))
    sigma = float(np.std(portfolio_returns, ddof=0))
    parametric_var = -(mu + VAR_Z_SCORES * sigma)
    parametric_var = np.clip(parametric_var, a_min=0.0, a_max=None)

    return {
        "sortino_ratio": _finite_or_none(sortino_ratio),
        "maximum_drawdown": _finite_or_none(maximum_drawdown),
        "beta": _finite_or_none(beta),
        "alpha": _finite_or_none(alpha),
        "value_at_risk": {
            "historical": {
                "confidence_95": _finite_or_none(historical_var[0]),
                "confidence_99": _finite_or_none(historical_var[1]),
            },
            "parametric": {
                "confidence_95": _finite_or_none(parametric_var[0]),
                "confidence_99": _finite_or_none(parametric_var[1]),
            },
        },
    }
