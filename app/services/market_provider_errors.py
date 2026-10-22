"""Market provider exceptions and validation utilities.

Provides a structured exception hierarchy for market data provider failures,
along with reusable validation functions for TSETMC API responses.

Exception Hierarchy:
    MarketProviderError (base)
    ├── ProviderNetworkError        - Network/transport failures
    │   ├── ProviderTimeoutError    - Request timeout
    │   └── ProviderConnectionError - Connection refused/reset
    ├── ProviderHTTPError           - HTTP 4xx/5xx responses
    │   ├── ProviderRateLimitError  - HTTP 429
    │   └── ProviderServerError     - HTTP 5xx
    ├── ProviderParseError          - Response parsing failures
    │   ├── PayloadSchemaError      - Unexpected response structure
    │   └── FieldValidationError    - Invalid field values
    └── ProviderCircuitOpenError    - Circuit breaker active

Retryable vs Non-Retryable:
    RETRYABLE: TimeoutError, ConnectionError, RateLimitError, ServerError
    NON-RETRYABLE: PayloadSchemaError, FieldValidationError, CircuitOpenError
"""

from __future__ import annotations

import logging
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Any

logger = logging.getLogger("market_provider.errors")


# ═══════════════════════════════════════════════════════════════
# Exception Hierarchy
# ═══════════════════════════════════════════════════════════════

class MarketProviderError(Exception):
    """Base exception for all market provider errors."""

    def __init__(self, message: str, *, provider: str = "unknown") -> None:
        self.provider = provider
        super().__init__(message)


class ProviderNetworkError(MarketProviderError):
    """Network/transport level failures."""
    pass


class ProviderTimeoutError(ProviderNetworkError):
    """Request timed out. RETRYABLE."""

    def __init__(self, message: str, *, provider: str = "unknown", timeout_seconds: float | None = None) -> None:
        self.timeout_seconds = timeout_seconds
        super().__init__(message, provider=provider)


class ProviderConnectionError(ProviderNetworkError):
    """Connection refused, reset, or DNS failure. RETRYABLE."""
    pass


class ProviderHTTPError(MarketProviderError):
    """HTTP error response. RETRYABLE if 5xx, NON-RETRYABLE if 4xx."""

    def __init__(
        self,
        message: str,
        *,
        provider: str = "unknown",
        status_code: int = 0,
        retryable: bool = False,
    ) -> None:
        self.status_code = status_code
        self.retryable = retryable
        super().__init__(message, provider=provider)


class ProviderRateLimitError(ProviderHTTPError):
    """HTTP 429 Too Many Requests. RETRYABLE."""

    def __init__(self, message: str = "Rate limited by provider", *, provider: str = "unknown") -> None:
        super().__init__(message, provider=provider, status_code=429, retryable=True)


class ProviderServerError(ProviderHTTPError):
    """HTTP 5xx server error. RETRYABLE."""

    def __init__(self, message: str, *, provider: str = "unknown", status_code: int = 500) -> None:
        super().__init__(message, provider=provider, status_code=status_code, retryable=True)


class ProviderParseError(MarketProviderError):
    """Response parsing failure. NON-RETRYABLE."""
    pass


class PayloadSchemaError(ProviderParseError):
    """Unexpected response structure (missing keys, wrong types). NON-RETRYABLE."""

    def __init__(
        self,
        message: str,
        *,
        provider: str = "unknown",
        expected_shape: str | None = None,
        actual_keys: list[str] | None = None,
    ) -> None:
        self.expected_shape = expected_shape
        self.actual_keys = actual_keys or []
        super().__init__(message, provider=provider)


class FieldValidationError(ProviderParseError):
    """Invalid field value in response. NON-RETRYABLE."""

    def __init__(
        self,
        message: str,
        *,
        provider: str = "unknown",
        field_name: str | None = None,
        field_value: Any = None,
    ) -> None:
        self.field_name = field_name
        self.field_value = field_value
        super().__init__(message, provider=provider)


class ProviderCircuitOpenError(MarketProviderError):
    """Circuit breaker is open. NON-RETRYABLE."""
    pass


# ═══════════════════════════════════════════════════════════════
# Retryable Check Utility
# ═══════════════════════════════════════════════════════════════

def is_retryable_error(exc: Exception) -> bool:
    """Check if an exception is retryable.

    Used by retry logic to distinguish transient failures from permanent ones.

    Retryable:
        - ProviderTimeoutError
        - ProviderConnectionError
        - ProviderRateLimitError (429)
        - ProviderServerError (5xx)
        - httpx.TimeoutException (library-level timeout)
        - httpx.HTTPStatusError with 429 or 5xx

    Non-Retryable:
        - ProviderParseError and subclasses
        - ProviderCircuitOpenError
        - httpx.HTTPStatusError with 4xx (except 429)
        - ValueError, TypeError (parsing errors)
    """
    from app.services.market_provider import MarketProviderError

    # Our custom exceptions
    if isinstance(exc, MarketProviderError):
        if isinstance(exc, ProviderHTTPError):
            return exc.retryable
        if isinstance(exc, ProviderNetworkError):
            return True
        return False

    # httpx library exceptions
    import httpx
    if isinstance(exc, httpx.TimeoutException):
        return True
    if isinstance(exc, httpx.HTTPStatusError):
        if exc.response.status_code == 429:
            return True
        return exc.response.status_code >= 500

    # Other exceptions are not retryable
    return False


# ═══════════════════════════════════════════════════════════════
# Validation Utilities
# ═══════════════════════════════════════════════════════════════

# Minimum expected fields for TSETMC price responses
REQUIRED_PRICE_ROW_FIELDS = {"pClosing"}

# Fields that should be numeric (Decimal-compatible)
NUMERIC_FIELDS = {"pClosing", "pDrCotVal", "priceFirst", "priceMax", "priceMin", "qTotTran5J"}


def _parse_tsetmc_numeric(value: Any) -> Decimal:
    """Parse TSETMC numeric display values such as '1,234' or '2.5B'."""
    if value is None:
        raise InvalidOperation("empty numeric value")

    text = str(value).strip()
    if not text:
        raise InvalidOperation("empty numeric value")

    multiplier = Decimal("1")
    suffix = text[-1:].upper()
    if suffix in {"K", "M", "B", "T"}:
        multiplier = {
            "K": Decimal("1000"),
            "M": Decimal("1000000"),
            "B": Decimal("1000000000"),
            "T": Decimal("1000000000000"),
        }[suffix]
        text = text[:-1].strip()

    normalized = (
        text.replace(",", "")
        .replace("٬", "")
        .replace("_", "")
        .replace("−", "-")
    )
    return Decimal(normalized) * multiplier


def validate_price_payload(payload: dict[str, Any], *, provider: str = "tsetmc") -> None:
    """Validate TSETMC price response structure.

    Args:
        payload: Raw JSON response from TSETMC.
        provider: Provider name for error messages.

    Raises:
        PayloadSchemaError: If response structure is invalid.
    """
    if not isinstance(payload, dict):
        raise PayloadSchemaError(
            f"Expected dict response, got {type(payload).__name__}",
            provider=provider,
            expected_shape="dict with 'closingPriceDaily' key",
        )

    closing_daily = payload.get("closingPriceDaily")
    if closing_daily is None:
        raise PayloadSchemaError(
            "Missing 'closingPriceDaily' in response",
            provider=provider,
            expected_shape="dict with 'closingPriceDaily' key",
            actual_keys=list(payload.keys()),
        )

    if not isinstance(closing_daily, list):
        raise PayloadSchemaError(
            f"Expected 'closingPriceDaily' to be list, got {type(closing_daily).__name__}",
            provider=provider,
            expected_shape="list of price rows",
        )


def validate_price_row(row: dict[str, Any], *, provider: str = "tsetmc") -> None:
    """Validate a single TSETMC price row.

    Args:
        row: Single price row from closingPriceDaily array.
        provider: Provider name for error messages.

    Raises:
        PayloadSchemaError: If row structure is invalid.
        FieldValidationError: If required fields are missing or invalid.
    """
    if not isinstance(row, dict):
        raise PayloadSchemaError(
            f"Expected dict price row, got {type(row).__name__}",
            provider=provider,
        )

    missing = REQUIRED_PRICE_ROW_FIELDS - set(row.keys())
    if missing:
        raise PayloadSchemaError(
            f"Missing required fields: {', '.join(sorted(missing))}",
            provider=provider,
            expected_shape=f"row with fields: {', '.join(sorted(REQUIRED_PRICE_ROW_FIELDS))}",
            actual_keys=list(row.keys()),
        )

    close_price = row.get("pClosing")
    if close_price is None:
        raise FieldValidationError(
            "pClosing is None",
            provider=provider,
            field_name="pClosing",
            field_value=close_price,
        )

    try:
        price = _parse_tsetmc_numeric(close_price)
        if not price.is_finite() or price <= 0:
            raise FieldValidationError(
                f"pClosing must be positive finite Decimal, got {price}",
                provider=provider,
                field_name="pClosing",
                field_value=close_price,
            )
    except InvalidOperation as exc:
        raise FieldValidationError(
            f"Cannot parse pClosing as Decimal: {close_price}",
            provider=provider,
            field_name="pClosing",
            field_value=close_price,
        ) from exc


def validate_instrument_state_payload(
    payload: dict[str, Any],
    *,
    provider: str = "tsetmc",
) -> None:
    """Validate TSETMC instrument state response structure.

    Args:
        payload: Raw JSON response from instrument state endpoint.
        provider: Provider name for error messages.

    Raises:
        PayloadSchemaError: If response structure is invalid.
    """
    if not isinstance(payload, dict):
        raise PayloadSchemaError(
            f"Expected dict response, got {type(payload).__name__}",
            provider=provider,
        )

    # Instrument state can have various keys, but at least one should exist
    valid_keys = {"instrumentState", "state", "status"}
    if not valid_keys.intersection(payload.keys()):
        raise PayloadSchemaError(
            f"Missing instrument state fields. Expected one of: {', '.join(sorted(valid_keys))}",
            provider=provider,
            expected_shape=f"dict with one of: {', '.join(sorted(valid_keys))}",
            actual_keys=list(payload.keys()),
        )


def safe_parse_price_row(row: dict[str, Any], *, provider: str = "tsetmc") -> dict[str, Any] | None:
    """Safely parse and validate a TSETMC price row.

    Returns validated row dict if valid, None if parsing fails.
    Logs validation errors at debug level.

    This is a softer alternative to validate_price_row that returns None
    instead of raising, suitable for batch processing where individual
    row failures should not abort the entire batch.
    """
    try:
        validate_price_row(row, provider=provider)
        return row
    except (PayloadSchemaError, FieldValidationError) as exc:
        logger.debug("Price row validation failed: %s", exc)
        return None
