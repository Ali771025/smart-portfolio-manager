"""Pydantic v2 DTOs for factor analysis and exposure summaries.

Response contracts for:
  - Factor exposures (market, size, value, momentum, etc.)
  - Factor contributions to return
  - Regression diagnostics (R-squared, alpha, beta)

Factors represent systematic risk sources that explain portfolio returns.
"""

from __future__ import annotations

import math
import uuid
from datetime import date, datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ═══════════════════════════════════════════════════════════════
# Base Classes
# ═══════════════════════════════════════════════════════════════

class FactorsBaseModel(BaseModel):
    """Base DTO for factor schemas with strict validation."""

    model_config = ConfigDict(extra="forbid", ser_json_inf_nan="null")


def _sanitize_factor(value: Any) -> float | None:
    """Sanitize factor value (finite, 4 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 4)


def _sanitize_pct(value: Any) -> float | None:
    """Sanitize percentage value (finite, 2 decimal places)."""
    if value is None:
        return None
    parsed = float(value)
    if not math.isfinite(parsed):
        return None
    return round(parsed, 2)


# ═══════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════

class FactorType(str, Enum):
    """Standard factor types for multi-factor analysis."""
    MARKET = "market"
    SIZE = "size"
    VALUE = "value"
    MOMENTUM = "momentum"
    QUALITY = "quality"
    VOLATILITY = "volatility"
    LIQUIDITY = "liquidity"
    YIELD = "yield"
    CUSTOM = "custom"


class FactorFrequency(str, Enum):
    """Frequency of factor exposure calculations."""
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"


class RegressionStatus(str, Enum):
    """Status of the factor regression."""
    SUCCESS = "success"
    INSUFFICIENT_DATA = "insufficient_data"
    SINGULAR_MATRIX = "singular_matrix"
    CONVERGENCE_FAILED = "convergence_failed"


# ═══════════════════════════════════════════════════════════════
# Factor Exposure
# ═══════════════════════════════════════════════════════════════

class FactorExposureDTO(FactorsBaseModel):
    """Exposure to a single factor."""
    factor_type: FactorType = Field(description="Factor identifier")
    factor_name: str = Field(description="Human-readable factor name")
    exposure: float | None = Field(
        default=None,
        description="Factor loading/coefficient (beta)",
    )
    t_statistic: float | None = Field(
        default=None,
        description="Statistical significance (t-stat)",
    )
    p_value: float | None = Field(
        default=None,
        description="p-value for significance testing",
    )
    is_significant: bool = Field(
        default=False,
        description="True if p_value < 0.05",
    )
    contribution_return_pct: float | None = Field(
        default=None,
        description="Factor's contribution to total return",
    )
    contribution_risk_pct: float | None = Field(
        default=None,
        description="Factor's contribution to portfolio risk",
    )

    @field_validator(
        "exposure", "t_statistic", "p_value",
        "contribution_return_pct", "contribution_risk_pct",
        mode="before",
    )
    @classmethod
    def round_exposure_fields(cls, value: Any) -> float | None:
        return _sanitize_factor(value)


# ═══════════════════════════════════════════════════════════════
# Regression Diagnostics
# ═══════════════════════════════════════════════════════════════

class RegressionDiagnosticsDTO(FactorsBaseModel):
    """Diagnostic statistics for the factor regression."""
    r_squared: float | None = Field(
        default=None,
        description="Proportion of variance explained (0-1)",
    )
    adjusted_r_squared: float | None = Field(
        default=None,
        description="R-squared adjusted for number of factors",
    )
    alpha_annual_pct: float | None = Field(
        default=None,
        description="Annualized alpha (Jensen's alpha)",
    )
    alpha_t_statistic: float | None = Field(
        default=None,
        description="Alpha t-statistic",
    )
    alpha_is_significant: bool = Field(
        default=False,
        description="True if alpha is statistically significant",
    )
    residual_volatility_pct: float | None = Field(
        default=None,
        description="Annualized residual (idiosyncratic) volatility",
    )
    information_ratio: float | None = Field(
        default=None,
        description="Alpha / residual volatility",
    )
    status: RegressionStatus = Field(
        default=RegressionStatus.SUCCESS,
        description="Regression computation status",
    )
    error_message: str | None = Field(
        default=None,
        description="Error message if regression failed",
    )
    observations_count: int = Field(
        default=0,
        description="Number of observations used",
    )

    @field_validator(
        "r_squared", "adjusted_r_squared", "alpha_annual_pct",
        "alpha_t_statistic", "residual_volatility_pct", "information_ratio",
        mode="before",
    )
    @classmethod
    def round_diagnostic_fields(cls, value: Any) -> float | None:
        return _sanitize_factor(value)


# ═══════════════════════════════════════════════════════════════
# Factor Summary Response
# ═══════════════════════════════════════════════════════════════

class FactorSummaryResponseDTO(FactorsBaseModel):
    """Complete factor analysis summary for a portfolio."""
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    base_currency: str = Field(default="IRR", description="Currency")
    as_of_date: date = Field(description="Analysis as-of date")
    period: str = Field(
        description="Analysis period (e.g., '1Y', 'YTD', 'ALL')",
    )
    start_date: date = Field(description="Period start date")
    end_date: date = Field(description="Period end date")

    # Factor exposures
    factors: list[FactorExposureDTO] = Field(
        default_factory=list,
        description="Factor exposures and contributions",
    )

    # Regression diagnostics
    regression: RegressionDiagnosticsDTO = Field(
        default_factory=RegressionDiagnosticsDTO,
        description="Regression statistics",
    )

    # Total attribution
    total_return_attributed_pct: float | None = Field(
        default=None,
        description="Total return explained by factors",
    )
    total_return_unattributed_pct: float | None = Field(
        default=None,
        description="Return not explained by factors (alpha)",
    )

    # Metadata
    is_fresh: bool = Field(
        default=True,
        description="True if calculation used fresh data",
    )
    is_stale: bool = Field(
        default=False,
        description="True if data may be outdated",
    )
    last_computed_at: datetime | None = Field(
        default=None,
        description="When this analysis was last computed",
    )

    @field_validator(
        "total_return_attributed_pct", "total_return_unattributed_pct",
        mode="before",
    )
    @classmethod
    def round_attribution_fields(cls, value: Any) -> float | None:
        return _sanitize_pct(value)


# ═══════════════════════════════════════════════════════════════
# Single Asset Factor Exposure
# ═══════════════════════════════════════════════════════════════

class AssetFactorExposureDTO(FactorsBaseModel):
    """Factor exposure for a single asset."""
    asset_id: str = Field(description="Asset identifier")
    ticker_symbol: str = Field(description="Ticker symbol")
    asset_name: str | None = Field(default=None, description="Asset name")

    # Factor exposures
    market_beta: float | None = Field(
        default=None,
        description="Market beta (sensitivity to market returns)",
    )
    size_loading: float | None = Field(
        default=None,
        description="Size factor loading",
    )
    value_loading: float | None = Field(
        default=None,
        description="Value factor loading",
    )
    momentum_loading: float | None = Field(
        default=None,
        description="Momentum factor loading",
    )

    # Risk decomposition
    systematic_risk_pct: float | None = Field(
        default=None,
        description="Systematic (factor) risk percentage",
    )
    idiosyncratic_risk_pct: float | None = Field(
        default=None,
        description="Idiosyncratic (asset-specific) risk percentage",
    )
    total_risk_pct: float | None = Field(
        default=None,
        description="Total risk (volatility) percentage",
    )

    @field_validator(
        "market_beta", "size_loading", "value_loading", "momentum_loading",
        "systematic_risk_pct", "idiosyncratic_risk_pct", "total_risk_pct",
        mode="before",
    )
    @classmethod
    def round_asset_factor_fields(cls, value: Any) -> float | None:
        return _sanitize_factor(value)


class AssetFactorExposureResponseDTO(FactorsBaseModel):
    """Response for multi-asset factor exposures."""
    portfolio_id: uuid.UUID = Field(description="Portfolio identifier")
    as_of_date: date = Field(description="Data as-of date")
    period: str = Field(description="Analysis period")
    assets: list[AssetFactorExposureDTO] = Field(
        default_factory=list,
        description="Factor exposures by asset",
    )
    is_fresh: bool = Field(default=True)
    last_computed_at: datetime | None = Field(default=None)
