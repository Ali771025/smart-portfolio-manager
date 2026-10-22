"""TSETMC market data provider implementation (hardened).

Production-grade implementation of the MarketDataProvider protocol for the
Tehran Stock Exchange (TSETMC) API with comprehensive resilience features.

Resilience Features:
  - Structured exception hierarchy (market_provider_errors.py)
  - Retry with bounded exponential backoff for transient failures
  - Circuit breaker for upstream protection
  - Parser validation for malformed payloads
  - Graceful degradation on partial failures
  - Structured logging with request lifecycle tracking
  - Timeout handling with configurable connect/read timeouts
  - Retryable vs non-retryable error distinction

TSETMC API Field Mapping (internal → TSETMC):
  - close_price      → pClosing
  - last_trade_price → pDrCotVal (last trade / closing transaction)
  - open_price       → priceFirst
  - high_price       → priceMax
  - low_price        → priceMin
  - volume           → qTotTran5J (total transaction volume)
  - close_change     → pClosingChange
  - close_change_pct → pClosingPercent
  - last_change      → pDrCotValChange
"""

from __future__ import annotations

import asyncio
import importlib
import logging
import time
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any

import httpx

from app.services.market_provider import (
    BaseMarketDataProvider,
    ClientTypeBreakdown,
    IndexSnapshot,
    InstrumentState,
    LiveMarketSnapshot,
    MarketIndex,
    MarketOverview,
    MarketInstrument,
    MarketProviderConfig,
    MarketProviderStatus,
    MarketQuote,
    MarketSnapshot,
    OrderBookSnapshot,
    PriceBar,
    ProviderHealth,
    SupervisorMessage,
    SymbolStatus,
)
from app.services.market_normalizers import (
    TSETMCNormalizer,
    normalize_market_symbol,
    normalize_tsetmc_indices,
    normalize_tsetmc_market_overview,
    parse_iranian_decimal,
)
from app.services.market_provider_errors import (
    FieldValidationError,
    PayloadSchemaError,
    ProviderCircuitOpenError,
    ProviderConnectionError,
    ProviderHTTPError,
    ProviderRateLimitError,
    ProviderServerError,
    ProviderTimeoutError,
    is_retryable_error,
    safe_parse_price_row,
    validate_instrument_state_payload,
    validate_price_payload,
)

logger = logging.getLogger("tsetmc_provider")

# ═══════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════

IRAN_TZ = timezone(timedelta(hours=3, minutes=30))
"""Asia/Tehran timezone (UTC+03:30)."""

FOUR_PLACES = Decimal("0.0001")
EIGHT_PLACES = Decimal("0.00000000")
ZERO = Decimal("0.0000")

# TSETMC field name constants (centralized for single source of truth)
_FIELD_CLOSING_PRICE = "pClosing"
_FIELD_LAST_TRADE = "pDrCotVal"
_FIELD_OPEN = "priceFirst"
_FIELD_HIGH = "priceMax"
_FIELD_LOW = "priceMin"
_FIELD_VOLUME = "qTotTran5J"
_FIELD_CLOSE_CHANGE = "pClosingChange"
_FIELD_CLOSE_CHANGE_PCT = "pClosingPercent"
_FIELD_LAST_CHANGE = "pDrCotValChange"
_FIELD_INSTRUMENT_NAME = "instrumentName"
_FIELD_DATE = "date"
_FIELD_DATE_ALT = "pDate"
_FIELD_CORPORATE_ACTION = "hasCorporateAction"
_FIELD_CORPORATE_ACTION_DAY = "isCorporateActionDay"
_FIELD_CORPORATE_ACTION_DATA = "corporateAction"
_FIELD_INSTRUMENT_STATE = "instrumentState"
_FIELD_STATE = "state"
_FIELD_STATUS = "status"
_FIELD_CLOSING_DAILY = "closingPriceDaily"
_MARKET_WATCH_PATH = "/ClosingPrice/GetMarketWatch"
_MARKET_WATCH_PARAMS: tuple[tuple[str, str], ...] = (
    ("market", "0"),
    ("industrialGroup", ""),
    *(("paperTypes", str(value)) for value in range(1, 10)),
    ("showTraded", "false"),
    ("withBestLimits", "true"),
    ("hEven", "0"),
    ("RefID", "0"),
)


# ═══════════════════════════════════════════════════════════════
# Normalization Helpers
# ═══════════════════════════════════════════════════════════════

def _q4(value: Decimal) -> Decimal:
    """Quantize to NUMERIC(18,4) precision for price fields."""
    return value.quantize(FOUR_PLACES, rounding=ROUND_HALF_UP)


def _q8(value: Decimal) -> Decimal:
    """Quantize to NUMERIC(24,8) precision for high-precision fields."""
    return value.quantize(EIGHT_PLACES, rounding=ROUND_HALF_UP)


def _safe_decimal(value: Any, default: Decimal = ZERO) -> Decimal:
    """Safely convert value to Decimal, returning default on failure.

    Handles None, empty strings, comma separators, and TSETMC display suffixes
    such as K/M/B/T gracefully.
    """
    parsed = parse_iranian_decimal(value)
    if parsed is None:
        return default
    return _q4(parsed) if parsed.is_finite() else default


def _safe_int(value: Any, default: int = 0) -> int:
    """Safely convert value to int, returning default on failure.

    Negative values are clamped to 0 (volume cannot be negative).
    """
    if value is None:
        return default
    try:
        result = int(_safe_decimal(value, Decimal(default)))
        return max(result, 0) if result >= 0 else default
    except (ValueError, TypeError):
        return default


def _parse_tsetmc_date(raw: Any) -> date | None:
    """Parse TSETMC date field (typically YYYYMMDD integer or string).

    Returns None if parsing fails rather than raising.
    """
    if raw is None:
        return None
    try:
        date_str = str(int(raw)).zfill(8)
        return datetime.strptime(date_str, "%Y%m%d").date()
    except (ValueError, TypeError):
        return None


def _parse_tsetmc_datetime(raw: Any, tz: timezone = IRAN_TZ) -> datetime | None:
    """Parse TSETMC datetime field (typically YYYYMMDDHHMMSS integer).

    Returns timezone-aware datetime in the specified timezone (default: Asia/Tehran).
    Returns None if parsing fails.
    """
    if raw is None:
        return None
    try:
        dt_str = str(int(raw)).zfill(14)
        naive = datetime.strptime(dt_str, "%Y%m%d%H%M%S")
        return naive.replace(tzinfo=tz)
    except (ValueError, TypeError):
        return None


def _parse_market_watch_event_time(
    row: dict[str, Any],
    *,
    trade_date: date,
    received_at: datetime,
) -> datetime:
    raw_event = _first_value(row, "event_time", "lastTradeTime", "hEven")
    parsed = _parse_tsetmc_datetime(raw_event, received_at.tzinfo or IRAN_TZ)
    if parsed is not None:
        return parsed
    try:
        time_text = str(int(raw_event or 0)).zfill(6)
        parsed_time = datetime.strptime(time_text, "%H%M%S").time()
        return datetime.combine(
            trade_date,
            parsed_time,
            tzinfo=received_at.tzinfo or IRAN_TZ,
        )
    except (TypeError, ValueError):
        return received_at


def _normalize_instrument_state(raw: Any) -> InstrumentState:
    """Normalize TSETMC instrument state string to InstrumentState enum.

    Handles various TSETMC state formats:
    - Direct strings: "1", "2", "3", "4", "5"
    - Descriptive strings: "Trading", "Halted", etc.
    - Nested dicts with state/status keys
    """
    if raw is None:
        return InstrumentState.UNKNOWN

    # Handle dict format
    if isinstance(raw, dict):
        raw = raw.get(_FIELD_STATE) or raw.get(_FIELD_STATUS)
        if raw is None:
            return InstrumentState.UNKNOWN

    state_str = str(raw).strip().upper()

    # Direct enum match
    for member in InstrumentState:
        if member.value in state_str:
            return member

    # TSETMC numeric state codes (common values)
    state_code_map: dict[str, InstrumentState] = {
        "1": InstrumentState.TRADEABLE,
        "2": InstrumentState.HALT,
        "3": InstrumentState.SUSPENDED,
        "4": InstrumentState.CLOSED,
        "5": InstrumentState.STOPPED,
        "A": InstrumentState.TRADEABLE,
    }
    if state_str in state_code_map:
        return state_code_map[state_str]

    return InstrumentState.UNKNOWN


def _extract_corporate_action_flag(row: dict[str, Any]) -> bool:
    """Extract corporate action flag from TSETMC response row.

    TSETMC uses multiple fields to indicate corporate actions:
    - hasCorporateAction (boolean)
    - isCorporateActionDay (boolean)
    - corporateAction (object/dict)
    """
    return bool(
        row.get(_FIELD_CORPORATE_ACTION)
        or row.get(_FIELD_CORPORATE_ACTION_DAY)
        or row.get(_FIELD_CORPORATE_ACTION_DATA)
    )


def _first_value(row: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in row and row[key] not in (None, ""):
            return row[key]
    return None


# ═══════════════════════════════════════════════════════════════
# Structured Logging Helpers
# ═══════════════════════════════════════════════════════════════

def _log_request_start(operation: str, **kwargs: Any) -> None:
    """Log request start with context."""
    logger.debug(
        "tsetmc.request.start operation=%s %s",
        operation,
        " ".join(f"{k}={v}" for k, v in kwargs.items()),
    )


def _log_request_success(operation: str, latency_ms: float, **kwargs: Any) -> None:
    """Log request success with latency."""
    logger.debug(
        "tsetmc.request.success operation=%s latency=%.1fms %s",
        operation,
        latency_ms,
        " ".join(f"{k}={v}" for k, v in kwargs.items()),
    )


def _log_request_failure(operation: str, error: Exception, latency_ms: float, **kwargs: Any) -> None:
    """Log request failure with error details."""
    logger.warning(
        "tsetmc.request.failed operation=%s error=%s latency=%.1fms %s",
        operation,
        type(error).__name__,
        latency_ms,
        " ".join(f"{k}={v}" for k, v in kwargs.items()),
    )


def _log_parse_failure(operation: str, error: Exception, **kwargs: Any) -> None:
    """Log parse failure."""
    logger.warning(
        "tsetmc.parse.failed operation=%s error=%s %s",
        operation,
        type(error).__name__,
        " ".join(f"{k}={v}" for k, v in kwargs.items()),
    )


def _log_retry_attempt(operation: str, attempt: int, max_attempts: int, delay: float, error: Exception) -> None:
    """Log retry attempt."""
    logger.info(
        "tsetmc.retry operation=%s attempt=%d/%d delay=%.1fs error=%s",
        operation,
        attempt,
        max_attempts,
        delay,
        type(error).__name__,
    )


# ═══════════════════════════════════════════════════════════════
# TSETMC Provider Implementation
# ═══════════════════════════════════════════════════════════════

class TSETMCProvider(BaseMarketDataProvider):
    """TSETMC HTTP provider for Tehran Stock Exchange data (hardened).

    This client encapsulates all external communication with TSETMC endpoints.
    It normalizes provider-specific field names into stable internal structures
    suitable for service/repository use.

    Resilience Features:
      - Semaphore-based concurrency control
      - Retry with bounded exponential backoff for transient failures
      - Circuit breaker for upstream protection
      - Parser validation for malformed payloads
      - Graceful degradation on partial failures
      - Structured logging with request lifecycle tracking
      - Timeout handling with configurable connect/read timeouts

    Usage:
        async with TSETMCProvider(config) as provider:
            snapshot = await provider.fetch_live_market_snapshot("ins_code")
    """

    def __init__(self, config: MarketProviderConfig) -> None:
        super().__init__(config)
        self._name = "tsetmc"
        self._client: httpx.AsyncClient | None = None
        self._semaphore = asyncio.Semaphore(config.max_concurrent)
        self._failure_count = 0
        self._circuit_opened_at: datetime | None = None
        self._last_success_at: datetime | None = None
        self._total_requests = 0
        self._total_errors = 0
        self._total_retries = 0

    async def __aenter__(self) -> TSETMCProvider:
        self._client = httpx.AsyncClient(
            base_url=self._config.base_url,
            timeout=httpx.Timeout(
                connect=self._config.connect_timeout,
                read=self._config.request_timeout,
                write=self._config.connect_timeout,
                pool=self._config.connect_timeout,
            ),
            limits=httpx.Limits(
                max_connections=self._config.max_concurrent + 5,
                max_keepalive_connections=self._config.max_concurrent,
            ),
            headers={
                # TSETMC rejects non-browser user agents with a 403 response.
                # These are the same request headers used by its public web app.
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/126.0.0.0 Safari/537.36"
                ),
                "Accept": "application/json, text/plain, */*",
                "Origin": "https://www.tsetmc.com",
                "Referer": "https://www.tsetmc.com/",
            },
        )
        logger.debug("TSETMCProvider initialized base_url=%s", self._config.base_url)
        return self

    async def __aexit__(self, *args: Any) -> None:
        await self.close()

    async def close(self) -> None:
        """Close the HTTP client and release resources."""
        if self._client is not None:
            await self._client.aclose()
            self._client = None
            logger.debug("TSETMCProvider closed")

    @property
    def stats(self) -> dict[str, Any]:
        """Return provider statistics for monitoring."""
        return {
            "total_requests": self._total_requests,
            "total_errors": self._total_errors,
            "total_retries": self._total_retries,
            "failure_count": self._failure_count,
            "circuit_open": self._circuit_opened_at is not None,
            "last_success_at": self._last_success_at.isoformat() if self._last_success_at else None,
        }

    # ── Circuit Breaker ────────────────────────────────────────

    def _circuit_allow(self) -> bool:
        """Check if requests are allowed (circuit not open)."""
        if self._circuit_opened_at is None:
            return True
        elapsed = (datetime.now(IRAN_TZ) - self._circuit_opened_at).total_seconds()
        if elapsed >= self._config.circuit_breaker_reset_seconds:
            logger.info(
                "circuit_breaker.reset elapsed=%.1fs failures=%d",
                elapsed,
                self._failure_count,
            )
            self._failure_count = 0
            self._circuit_opened_at = None
            return True
        return False

    def _circuit_record_success(self) -> None:
        """Record a successful request for circuit breaker."""
        self._failure_count = 0
        self._circuit_opened_at = None
        self._last_success_at = datetime.now(IRAN_TZ)

    def _circuit_record_failure(self) -> None:
        """Record a failed request for circuit breaker."""
        self._failure_count += 1
        if self._failure_count >= self._config.circuit_breaker_failure_threshold:
            self._circuit_opened_at = datetime.now(IRAN_TZ)
            logger.warning(
                "circuit_breaker.open failures=%d threshold=%d",
                self._failure_count,
                self._config.circuit_breaker_failure_threshold,
            )

    # ── HTTP Layer with Bounded Retry ──────────────────────────

    async def _get_json(
        self,
        path: str,
        *,
        params: tuple[tuple[str, str], ...] | None = None,
        quiet_statuses: set[int] | None = None,
    ) -> dict[str, Any]:
        """Fetch JSON from TSETMC with bounded retry and structured logging.

        Retry policy:
          - Only retries on transient failures (timeout, connection, 5xx, 429)
          - Never retries on parse errors or non-retryable HTTP errors
          - Uses bounded exponential backoff: delay = min(base * 2^attempt, max_delay)
          - Jitter is applied to prevent thundering herd

        Raises:
            ProviderCircuitOpenError: If circuit breaker is open.
            ProviderTimeoutError: On request timeout.
            ProviderConnectionError: On connection failure.
            ProviderRateLimitError: On HTTP 429.
            ProviderServerError: On HTTP 5xx.
            ProviderHTTPError: On other HTTP errors.
            PayloadSchemaError: On response parse failure.
        """
        if self._client is None:
            raise RuntimeError("TSETMCProvider not initialized; use 'async with'")

        if not self._circuit_allow():
            raise ProviderCircuitOpenError(
                f"Circuit breaker open; skipping request to {path}",
                provider=self._name,
            )

        self._total_requests += 1
        last_error: Exception | None = None
        max_attempts = self._config.retry_attempts
        quiet_statuses = quiet_statuses or set()

        for attempt in range(1, max_attempts + 1):
            start = time.monotonic()

            try:
                async with self._semaphore:
                    response = await self._client.get(path, params=params)

                latency_ms = (time.monotonic() - start) * 1000

                # Handle HTTP errors
                if response.status_code == 429:
                    error = ProviderRateLimitError(provider=self._name)
                    _log_request_failure("get_json", error, latency_ms, path=path, status=429)
                    self._total_errors += 1
                    last_error = error
                    # 429 is retryable, continue loop
                elif response.status_code >= 500:
                    error = ProviderServerError(
                        f"Server error {response.status_code}",
                        provider=self._name,
                        status_code=response.status_code,
                    )
                    _log_request_failure("get_json", error, latency_ms, path=path, status=response.status_code)
                    self._total_errors += 1
                    last_error = error
                    # 5xx is retryable, continue loop
                elif response.status_code >= 400:
                    # 4xx (except 429) is not retryable
                    error = ProviderHTTPError(
                        f"HTTP {response.status_code}",
                        provider=self._name,
                        status_code=response.status_code,
                        retryable=False,
                    )
                    if response.status_code in quiet_statuses:
                        logger.debug(
                            "tsetmc.request.optional_missing operation=get_json path=%s status=%s latency=%.1fms",
                            path,
                            response.status_code,
                            latency_ms,
                        )
                    else:
                        _log_request_failure("get_json", error, latency_ms, path=path, status=response.status_code)
                        self._total_errors += 1
                    raise error from None
                else:
                    # Success
                    _log_request_success("get_json", latency_ms, path=path, size=len(response.content))
                    self._circuit_record_success()

                    # Validate JSON response
                    try:
                        return response.json()
                    except Exception as exc:
                        raise PayloadSchemaError(
                            f"Invalid JSON response: {exc}",
                            provider=self._name,
                        ) from exc

            except httpx.TimeoutException as exc:
                latency_ms = (time.monotonic() - start) * 1000
                error = ProviderTimeoutError(
                    f"Request timeout after {latency_ms:.0f}ms",
                    provider=self._name,
                    timeout_seconds=self._config.request_timeout,
                )
                _log_request_failure("get_json", error, latency_ms, path=path)
                self._total_errors += 1
                last_error = error
                # Timeout is retryable, continue loop

            except httpx.ConnectError as exc:
                latency_ms = (time.monotonic() - start) * 1000
                error = ProviderConnectionError(
                    f"Connection failed: {exc}",
                    provider=self._name,
                )
                _log_request_failure("get_json", error, latency_ms, path=path)
                self._total_errors += 1
                last_error = error
                # Connection error is retryable, continue loop

            except (ProviderHTTPError, PayloadSchemaError):
                # Non-retryable errors, re-raise immediately
                raise

            except Exception as exc:
                latency_ms = (time.monotonic() - start) * 1000
                _log_request_failure("get_json", exc, latency_ms, path=path)
                self._total_errors += 1
                raise

            # Check if we should retry
            if attempt < max_attempts and last_error is not None and is_retryable_error(last_error):
                delay = min(
                    self._config.retry_base_delay * (self._config.retry_backoff_multiplier ** (attempt - 1)),
                    self._config.retry_max_delay,
                )
                # Add jitter (±25%)
                jitter = delay * 0.25
                import random
                delay = delay + random.uniform(-jitter, jitter)
                delay = max(0.1, delay)  # Ensure positive

                _log_retry_attempt("get_json", attempt, max_attempts, delay, last_error)
                self._total_retries += 1
                await asyncio.sleep(delay)
            else:
                break

        # Exhausted retries
        if last_error is not None:
            self._circuit_record_failure()
            raise last_error

        # Should not reach here, but safety fallback
        raise ProviderHTTPError(
            "Request failed without explicit error",
            provider=self._name,
        )

    async def _get_text(self, path: str) -> str:
        """Fetch text from TSETMC with the same bounded transient retry policy."""
        if self._client is None:
            raise RuntimeError("TSETMCProvider not initialized; use 'async with'")
        if not self._circuit_allow():
            raise ProviderCircuitOpenError(
                f"Circuit breaker open; skipping request to {path}",
                provider=self._name,
            )

        last_error: Exception | None = None
        for attempt in range(1, self._config.retry_attempts + 1):
            start = time.monotonic()
            try:
                async with self._semaphore:
                    response = await self._client.get(path)
                latency_ms = (time.monotonic() - start) * 1000
                if response.status_code >= 500:
                    last_error = ProviderServerError(
                        f"Server error {response.status_code}",
                        provider=self._name,
                        status_code=response.status_code,
                    )
                    _log_request_failure("get_text", last_error, latency_ms, path=path)
                elif response.status_code >= 400:
                    raise ProviderHTTPError(
                        f"HTTP {response.status_code}",
                        provider=self._name,
                        status_code=response.status_code,
                        retryable=False,
                    )
                else:
                    self._circuit_record_success()
                    return response.text
            except httpx.TimeoutException as exc:
                last_error = ProviderTimeoutError(str(exc), provider=self._name)
            except httpx.ConnectError as exc:
                last_error = ProviderConnectionError(str(exc), provider=self._name)
            except ProviderHTTPError:
                raise

            if attempt < self._config.retry_attempts and last_error is not None and is_retryable_error(last_error):
                delay = min(
                    self._config.retry_base_delay * (self._config.retry_backoff_multiplier ** (attempt - 1)),
                    self._config.retry_max_delay,
                )
                _log_retry_attempt("get_text", attempt, self._config.retry_attempts, delay, last_error)
                await asyncio.sleep(delay)
            else:
                break

        if last_error is not None:
            self._circuit_record_failure()
            raise last_error
        raise ProviderHTTPError("Text request failed without explicit error", provider=self._name)

    # ── Market Watch Normalization ─────────────────────────────

    def _normalize_market_watch_mapping(self, row: dict[str, Any], *, received_at: datetime) -> MarketQuote | None:
        instrument_id = str(_first_value(row, "instrument_id", "insCode", "ins_code", "inscode", "id", "InsCode") or "").strip()
        symbol = normalize_market_symbol(
            _first_value(
                row,
                "symbol",
                "lva",
                "lVal18AFC",
                "lval18AFC",
                "ticker",
                "Ticker",
            )
            or ""
        )
        if not instrument_id or not symbol:
            return None

        closing_price = parse_iranian_decimal(
            _first_value(row, "closing_price", "pcl", "pClosing", "pclosing", "close", "Close"),
        )
        last_price = parse_iranian_decimal(
            _first_value(row, "last_price", "pdv", "pDrCotVal", "pdrCotVal", "last", "Last"),
        )
        if closing_price is None or closing_price < ZERO:
            return None
        if last_price is not None and last_price < ZERO:
            return None

        trade_date = _parse_tsetmc_date(_first_value(row, "trade_date", "dEven", "date")) or received_at.date()
        event_time = _parse_market_watch_event_time(
            row,
            trade_date=trade_date,
            received_at=received_at,
        )

        trade_count = _safe_int(_first_value(row, "trade_count", "ztt", "zTotTran", "tradeCount"))
        volume = _safe_int(_first_value(row, "volume", "qtj", "qTotTran5J", "qTotTran"))
        value = parse_iranian_decimal(_first_value(row, "value", "qtc", "qTotCap", "tradeValue"))
        if trade_count < 0 or volume < 0 or (value is not None and value < ZERO):
            return None

        return MarketQuote(
            instrument_id=instrument_id,
            symbol=symbol,
            trade_date=trade_date,
            event_time=event_time,
            first_price=parse_iranian_decimal(_first_value(row, "first_price", "pf", "priceFirst", "first")),
            last_price=last_price,
            closing_price=closing_price,
            yesterday_price=parse_iranian_decimal(_first_value(row, "yesterday_price", "py", "priceYesterday", "pYesterday")),
            high_price=parse_iranian_decimal(_first_value(row, "high_price", "pmx", "priceMax", "high")),
            low_price=parse_iranian_decimal(_first_value(row, "low_price", "pmn", "priceMin", "low")),
            trade_count=trade_count,
            volume=volume,
            value=value,
            status=_normalize_instrument_state(_first_value(row, "status", "state", "instrumentState")),
            received_at=received_at,
            source=self.name,
        )

    def _normalize_market_watch_csv_row(self, row: str, *, received_at: datetime) -> MarketQuote | None:
        parts = [part.strip() for part in row.split(",")]
        if len(parts) < 8:
            return None
        mapped = {
            "insCode": parts[0],
            "symbol": parts[2] if len(parts) > 2 else "",
            "company_name": parts[3] if len(parts) > 3 else None,
            "pClosing": parts[4] if len(parts) > 4 else None,
            "pDrCotVal": parts[5] if len(parts) > 5 else None,
            "zTotTran": parts[6] if len(parts) > 6 else None,
            "qTotTran5J": parts[7] if len(parts) > 7 else None,
            "qTotCap": parts[8] if len(parts) > 8 else None,
            "priceMin": parts[9] if len(parts) > 9 else None,
            "priceMax": parts[10] if len(parts) > 10 else None,
            "priceYesterday": parts[11] if len(parts) > 11 else None,
            "priceFirst": parts[12] if len(parts) > 12 else None,
        }
        return self._normalize_market_watch_mapping(mapped, received_at=received_at)

    def normalize_market_watch_payload(self, payload: Any, *, received_at: datetime | None = None) -> list[MarketQuote]:
        """Normalize a TSETMC market-watch JSON/text payload to internal quotes."""
        received_at = received_at or datetime.now(IRAN_TZ)
        rows: list[Any] = []
        if isinstance(payload, dict):
            for key in ("marketWatch", "marketwatch", "marketWatchList", "items", "data"):
                value = payload.get(key)
                if isinstance(value, list):
                    rows = value
                    break
            if not rows:
                rows = [payload]
        elif isinstance(payload, list):
            rows = payload
        elif isinstance(payload, str):
            text_rows = [item for item in payload.split("@", 1)[0].split(";") if item.strip()]
            return [
                quote
                for item in text_rows
                if (quote := self._normalize_market_watch_csv_row(item, received_at=received_at)) is not None
            ]

        return [
            quote
            for row in rows
            if isinstance(row, dict)
            if (quote := self._normalize_market_watch_mapping(row, received_at=received_at)) is not None
        ]

    async def _get_market_watch_from_optional_library(self) -> list[MarketQuote]:
        """Best-effort wrapper for optional third-party tsetmc packages."""
        try:
            module = importlib.import_module("tsetmc")
        except Exception:
            return []

        for attr in ("market_watch", "get_market_watch", "watch"):
            candidate = getattr(module, attr, None)
            if callable(candidate):
                try:
                    payload = candidate()
                    if asyncio.iscoroutine(payload):
                        payload = await payload
                    return self.normalize_market_watch_payload(payload)
                except Exception as exc:
                    logger.debug("optional_tsetmc.%s failed: %s", attr, exc)
        return []

    # ── Normalization: TSETMC row → internal PriceBar ──────────

    def _normalize_price_row(self, row: dict[str, Any]) -> PriceBar | None:
        """Normalize a single TSETMC price row to PriceBar.

        Uses safe_parse_price_row for validation that doesn't raise on failure.
        Returns None if the row is invalid or has no valid close price.
        """
        validated = safe_parse_price_row(row, provider=self._name)
        if validated is None:
            return None

        bar_date = _parse_tsetmc_date(validated.get(_FIELD_DATE) or validated.get(_FIELD_DATE_ALT))
        if bar_date is None:
            return None

        close_price = _safe_decimal(validated.get(_FIELD_CLOSING_PRICE))
        if close_price <= ZERO:
            return None

        return PriceBar(
            date=bar_date,
            open_price=_safe_decimal(validated.get(_FIELD_OPEN), close_price),
            high_price=_safe_decimal(validated.get(_FIELD_HIGH), close_price),
            low_price=_safe_decimal(validated.get(_FIELD_LOW), close_price),
            close_price=close_price,
            last_trade_price=_safe_decimal(validated.get(_FIELD_LAST_TRADE), close_price),
            adjusted_close=close_price,
            adjustment_factor=Decimal("1.0000"),
            volume=_safe_int(validated.get(_FIELD_VOLUME)),
        )

    # ── Provider Interface Implementation ──────────────────────

    async def fetch_live_market_snapshot(
        self,
        ins_code: str,
    ) -> LiveMarketSnapshot | None:
        """Fetch real-time market data for a single instrument.

        Args:
            ins_code: TSETMC instrument code (e.g., "65462587328540985").

        Returns:
            LiveMarketSnapshot if successful, None if unavailable or invalid.

        Raises:
            ProviderCircuitOpenError: If circuit breaker is active.
            ProviderTimeoutError: On timeout (after retries).
            ProviderConnectionError: On connection failure (after retries).
            ProviderHTTPError: On non-retryable HTTP errors.
            PayloadSchemaError: On response parse failure.

        TSETMC endpoints used:
            - /ClosingPrice/GetClosingPriceDailyList/{ins_code}/0
            - /Instrument/GetInstrumentState/{ins_code}
        """
        operation = "fetch_live_market_snapshot"
        _log_request_start(operation, ins_code=ins_code)

        if not self._circuit_allow():
            logger.warning("circuit_breaker.open operation=%s ins_code=%s", operation, ins_code)
            return None

        # Fetch price data
        try:
            payload = await self._get_json(
                f"/ClosingPrice/GetClosingPriceDailyList/{ins_code}/0"
            )
            validate_price_payload(payload, provider=self._name)
        except ProviderCircuitOpenError:
            raise
        except ProviderTimeoutError as exc:
            self._circuit_record_failure()
            _log_request_failure(operation, exc, 0, ins_code=ins_code)
            return None
        except ProviderConnectionError as exc:
            self._circuit_record_failure()
            _log_request_failure(operation, exc, 0, ins_code=ins_code)
            return None
        except ProviderHTTPError as exc:
            self._circuit_record_failure()
            _log_request_failure(operation, exc, 0, ins_code=ins_code)
            return None
        except PayloadSchemaError as exc:
            self._circuit_record_failure()
            _log_parse_failure(operation, exc, ins_code=ins_code)
            return None
        except Exception as exc:
            self._circuit_record_failure()
            _log_request_failure(operation, exc, 0, ins_code=ins_code)
            return None

        rows = payload.get(_FIELD_CLOSING_DAILY) or []
        if not rows:
            self._circuit_record_failure()
            logger.debug("tsetmc.parse.empty operation=%s ins_code=%s", operation, ins_code)
            return None

        latest = rows[0]
        close_price = _safe_decimal(latest.get(_FIELD_CLOSING_PRICE))
        if close_price <= ZERO:
            self._circuit_record_failure()
            logger.debug("tsetmc.parse.invalid_price operation=%s ins_code=%s", operation, ins_code)
            return None
        last_trade_price = _safe_decimal(latest.get(_FIELD_LAST_TRADE), close_price)
        price_change = _safe_decimal(latest.get(_FIELD_LAST_CHANGE))
        price_change_percent = None
        close_change_percent = _safe_decimal(latest.get(_FIELD_CLOSE_CHANGE_PCT))
        if close_change_percent != ZERO:
            price_change_percent = close_change_percent

        # Fetch instrument state (separate request, graceful degradation)
        state = InstrumentState.TRADEABLE
        try:
            state_payload = await self._get_json(
                f"/Instrument/GetInstrumentState/{ins_code}",
                quiet_statuses={404},
            )
            validate_instrument_state_payload(state_payload, provider=self._name)
            raw_state = (
                state_payload.get(_FIELD_INSTRUMENT_STATE)
                or state_payload.get(_FIELD_STATE)
                or state_payload.get(_FIELD_STATUS)
            )
            state = _normalize_instrument_state(raw_state)
        except Exception as exc:
            logger.debug(
                "tsetmc.state.degraded ins_code=%s error=%s",
                ins_code,
                exc,
            )

        self._circuit_record_success()

        snapshot = LiveMarketSnapshot(
            ins_code=ins_code,
            ticker=ins_code,
            close_price=close_price,
            last_trade_price=last_trade_price,
            open_price=_safe_decimal(latest.get(_FIELD_OPEN), close_price),
            high_price=_safe_decimal(latest.get(_FIELD_HIGH), close_price),
            low_price=_safe_decimal(latest.get(_FIELD_LOW), close_price),
            volume=_safe_int(latest.get(_FIELD_VOLUME)),
            state=state,
            has_corporate_action=_extract_corporate_action_flag(latest),
            fetched_at=datetime.now(IRAN_TZ),
            price_change=price_change,
            price_change_percent=price_change_percent,
        )

        _log_request_success(
            operation,
            0,
            ins_code=ins_code,
            close=f"{close_price:.4f}",
            state=state.value,
        )
        return snapshot

    async def get_instruments(self) -> list[MarketInstrument]:
        """Return normalized TSETMC instruments.

        The live project does not yet persist a whole-market instrument source
        contract, so this skeleton deliberately returns normalized empty data
        rather than exposing raw TSETMC payloads to services.
        """
        return []

    async def resolve_instrument_id(self, symbol: str) -> str | None:
        """Resolve one exact active symbol through TSETMC instrument search."""
        canonical = normalize_market_symbol(symbol)
        if not canonical:
            return None
        try:
            payload = await self._get_json(f"/Instrument/GetInstrumentSearch/{symbol.strip()}")
        except Exception as exc:
            logger.warning("instrument.resolve_failed symbol=%s error=%s", symbol, exc)
            return None
        rows = payload.get("instrumentSearch") or payload.get("data") or []
        exact = [
            row
            for row in rows
            if isinstance(row, dict)
            and normalize_market_symbol(row.get("lVal18AFC")) == canonical
            and str(row.get("insCode") or "").strip()
        ]
        active = [row for row in exact if int(row.get("lastDate") or 0) == 1]
        candidates = active or exact
        instrument_ids = {str(row["insCode"]).strip() for row in candidates}
        return next(iter(instrument_ids)) if len(instrument_ids) == 1 else None

    async def get_market_snapshot(self) -> MarketSnapshot:
        """Return normalized whole-market snapshot data."""
        operation = "get_market_snapshot"
        received_at = datetime.now(IRAN_TZ)

        library_quotes = await self._get_market_watch_from_optional_library()
        if library_quotes:
            return MarketSnapshot(
                provider=self.name,
                fetched_at=received_at,
                quotes=library_quotes,
                instruments_count=len(library_quotes),
            )

        try:
            payload = await self._get_json(
                _MARKET_WATCH_PATH,
                params=_MARKET_WATCH_PARAMS,
            )
            quotes = self.normalize_market_watch_payload(payload, received_at=received_at)
            if quotes:
                _log_request_success(operation, 0, endpoint=_MARKET_WATCH_PATH, quotes=len(quotes))
                return MarketSnapshot(
                    provider=self.name,
                    fetched_at=received_at,
                    quotes=quotes,
                    instruments_count=len(quotes),
                )
        except Exception as exc:
            logger.warning(
                "market_watch.endpoint_failed endpoint=%s error=%s",
                _MARKET_WATCH_PATH,
                exc,
            )
        return MarketSnapshot(
            provider=self.name,
            fetched_at=received_at,
            quotes=[],
            instruments_count=0,
        )

    async def get_latest_quote(
        self,
        symbol_or_instrument_id: str,
    ) -> MarketQuote | None:
        """Return a normalized latest quote for a symbol or TSETMC instrument id."""
        snapshot = await self.fetch_live_market_snapshot(symbol_or_instrument_id)
        if snapshot is None:
            return None
        return TSETMCNormalizer.quote_from_snapshot(snapshot)

    async def get_daily_prices(
        self,
        instrument_id: str,
        from_date: date,
        to_date: date,
    ) -> list[PriceBar]:
        """Return normalized daily price bars."""
        return await self.fetch_symbol_history(instrument_id, from_date, to_date)

    async def get_client_types(
        self,
        trade_date: date | None = None,
    ) -> list[ClientTypeBreakdown]:
        """Return normalized client-type breakdowns."""
        _ = trade_date
        return []

    async def get_order_book(self, instrument_id: str) -> OrderBookSnapshot:
        """Return normalized order-book levels."""
        return OrderBookSnapshot(
            instrument_id=instrument_id,
            fetched_at=datetime.now(IRAN_TZ),
            levels=[],
        )

    async def get_indices(self) -> list[MarketIndex]:
        """Return normalized market indices."""
        payload = await self._get_json("/Index/GetIndexB1LastAll/All/1")
        return normalize_tsetmc_indices(payload, received_at=datetime.now(IRAN_TZ))

    async def get_market_overview(self) -> MarketOverview | None:
        """Return the latest market overview and canonical Tehran indices."""
        received_at = datetime.now(IRAN_TZ)
        overview_payload, indices = await asyncio.gather(
            self._get_json("/MarketData/GetMarketOverview/1"),
            self.get_indices(),
        )
        by_code = {item.index_code: item for item in indices}
        total = by_code.get("32097828799138957")
        equal_weight = by_code.get("67130298613737946")
        if total is None or equal_weight is None:
            return None
        return normalize_tsetmc_market_overview(
            overview_payload,
            total_index=total,
            equal_weight_index=equal_weight,
            received_at=received_at,
        )

    async def get_symbol_statuses(self) -> list[SymbolStatus]:
        """Return normalized symbol statuses."""
        return []

    async def get_supervisor_messages(self) -> list[SupervisorMessage]:
        """Return normalized market supervisor messages."""
        return []

    async def fetch_symbol_history(
        self,
        ins_code: str,
        start_date: date,
        end_date: date,
    ) -> list[PriceBar]:
        """Fetch historical OHLCV data for an instrument.

        Args:
            ins_code: TSETMC instrument code.
            start_date: Start of date range (inclusive).
            end_date: End of date range (inclusive).

        Returns:
            List of PriceBar sorted by date ascending. Empty list on error.

        TSETMC endpoints used:
            - /ClosingPrice/GetClosingPriceDailyList/{ins_code}/0
        """
        operation = "fetch_symbol_history"
        _log_request_start(operation, ins_code=ins_code, start=start_date, end=end_date)

        try:
            payload = await self._get_json(
                f"/ClosingPrice/GetClosingPriceDailyList/{ins_code}/0"
            )
            validate_price_payload(payload, provider=self._name)
        except ProviderCircuitOpenError:
            raise
        except Exception as exc:
            _log_request_failure(operation, exc, 0, ins_code=ins_code)
            return []

        rows = payload.get(_FIELD_CLOSING_DAILY) or []
        result: list[PriceBar] = []
        parse_errors = 0

        for row in rows:
            bar = self._normalize_price_row(row)
            if bar is None:
                parse_errors += 1
                continue
            if bar.date < start_date or bar.date > end_date:
                continue
            result.append(bar)

        self._circuit_record_success()
        result.sort(key=lambda x: x.date)

        _log_request_success(
            operation,
            0,
            ins_code=ins_code,
            bars=len(result),
            parse_errors=parse_errors,
        )
        return result

    async def fetch_index_snapshot(
        self,
        index_code: str,
    ) -> IndexSnapshot | None:
        """Fetch current market index value (e.g., TEDPIX, TEP10).

        Args:
            index_code: Index instrument code.

        Returns:
            IndexSnapshot if successful, None if unavailable.

        TSETMC endpoints used:
            - /ClosingPrice/GetClosingPriceDailyList/{index_code}/0
        """
        operation = "fetch_index_snapshot"
        _log_request_start(operation, index_code=index_code)

        try:
            payload = await self._get_json(
                f"/ClosingPrice/GetClosingPriceDailyList/{index_code}/0"
            )
            validate_price_payload(payload, provider=self._name)
        except ProviderCircuitOpenError:
            raise
        except Exception as exc:
            _log_request_failure(operation, exc, 0, index_code=index_code)
            return None

        rows = payload.get(_FIELD_CLOSING_DAILY) or []
        if not rows:
            logger.debug("tsetmc.parse.empty operation=%s index_code=%s", operation, index_code)
            return None

        latest = rows[0]
        last_value = _safe_decimal(latest.get(_FIELD_CLOSING_PRICE))
        if last_value <= ZERO:
            return None

        open_value = _safe_decimal(latest.get(_FIELD_OPEN), last_value)
        change_value = last_value - open_value
        change_percent = (
            (change_value / open_value * Decimal("100"))
            if open_value > ZERO
            else ZERO
        )

        self._circuit_record_success()

        snapshot = IndexSnapshot(
            index_code=index_code,
            name=str(latest.get(_FIELD_INSTRUMENT_NAME, index_code)),
            last_value=last_value,
            change_value=_q4(change_value),
            change_percent=_q4(change_percent),
            open_value=open_value,
            high_value=_safe_decimal(latest.get(_FIELD_HIGH), last_value),
            low_value=_safe_decimal(latest.get(_FIELD_LOW), last_value),
            volume=_safe_int(latest.get(_FIELD_VOLUME)),
            fetched_at=datetime.now(IRAN_TZ),
        )

        _log_request_success(
            operation,
            0,
            index_code=index_code,
            value=f"{last_value:.4f}",
            change=f"{change_percent:.2f}%",
        )
        return snapshot

    async def healthcheck(self) -> ProviderHealth:
        """Check TSETMC API connectivity and return health status.

        Performs a lightweight request to verify:
        - Network connectivity
        - TSETMC API availability
        - Response latency

        Returns:
            ProviderHealth with current status and diagnostics.
        """
        start = time.monotonic()

        try:
            await self._get_json("/Instrument/GetInstrumentState/0")
            latency_ms = (time.monotonic() - start) * 1000

            status = MarketProviderStatus.HEALTHY
            if latency_ms > 5000:
                status = MarketProviderStatus.DEGRADED

            return ProviderHealth(
                provider_name=self.name,
                status=status,
                latency_ms=round(latency_ms, 2),
                last_success_at=self._last_success_at,
                details={
                    "circuit_failures": str(self._failure_count),
                    "circuit_open": str(self._circuit_opened_at is not None),
                    "total_requests": str(self._total_requests),
                    "total_errors": str(self._total_errors),
                    "total_retries": str(self._total_retries),
                },
            )
        except Exception as exc:
            latency_ms = (time.monotonic() - start) * 1000
            logger.warning("tsetmc.healthcheck.failed error=%s", exc)
            return ProviderHealth(
                provider_name=self.name,
                status=MarketProviderStatus.UNAVAILABLE,
                latency_ms=round(latency_ms, 2),
                last_success_at=self._last_success_at,
                error_message=str(exc),
            )

    def __repr__(self) -> str:
        return (
            f"<TSETMCProvider name={self._name!r} "
            f"requests={self._total_requests} errors={self._total_errors} "
            f"retries={self._total_retries}>"
        )
