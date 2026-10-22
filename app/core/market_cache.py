"""Redis cache layer for market data snapshots.

Provides fast reads for live market data with automatic TTL expiration.
Falls back to None on Redis failures — callers should use DB as source of truth.

Redis Key Schema:
    market:quote:{instrument_id}       → JSON normalized latest quote (persistent)
    market:quote:symbol:{symbol}       → JSON normalized latest quote (persistent)
    market:overview                    → JSON market overview (persistent)
    market:indices                     → JSON latest normalized indices (persistent)
    market:disclosures:latest          → JSON latest normalized disclosures (persistent)
    market:last_update                 → ISO timestamp of last market update (persistent)
    market:watch:snapshot              → JSON latest market watch rows (persistent)
    market:stream:quotes               → Redis Stream for optional quote fanout
    price:snapshot:{ins_code}          → legacy JSON LiveMarketSnapshot (hot, 60s TTL)
    price:index:{index_code}           → legacy JSON IndexSnapshot (hot, 60s TTL)
    price:sync:status                  → legacy sync metadata (persistent)
"""

from __future__ import annotations

import json
import logging
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from app.core.config import settings
from app.core.redis import get_redis
from app.services.market_provider import CodalDisclosure, MarketIndex, MarketOverview, MarketQuote

logger = logging.getLogger("market_cache")


# ═══════════════════════════════════════════════════════════════
# Key Builders
# ═══════════════════════════════════════════════════════════════

def _snapshot_key(ins_code: str) -> str:
    """Build Redis key for live market snapshot."""
    return f"{settings.REDIS_PRICE_PREFIX}snapshot:{ins_code}"


def _index_key(index_code: str) -> str:
    """Build Redis key for index snapshot."""
    return f"{settings.REDIS_PRICE_PREFIX}index:{index_code}"


def _sync_status_key() -> str:
    """Build Redis key for sync metadata."""
    return f"{settings.REDIS_PRICE_PREFIX}sync:status"


def quote_key(instrument_id: str) -> str:
    return f"market:quote:{instrument_id}"


def quote_symbol_key(symbol: str) -> str:
    return f"market:quote:symbol:{symbol}"


def overview_key() -> str:
    return "market:overview"


def indices_key() -> str:
    return "market:indices"


def last_update_key() -> str:
    return "market:last_update"


def watch_snapshot_key() -> str:
    return "market:watch:snapshot"


def quote_stream_key() -> str:
    return "market:stream:quotes"


def disclosures_key() -> str:
    return "market:disclosures:latest"


def serialize_disclosures(items: list[CodalDisclosure | Any]) -> str:
    return json.dumps([
        {
            "tracking_number": item.tracking_number,
            "symbol": item.symbol,
            "company_name": item.company_name,
            "title": item.title,
            "letter_code": item.letter_code,
            "sent_at": _serialize_datetime(item.sent_at),
            "published_at": _serialize_datetime(item.published_at),
            "category": item.category,
            "url": item.url,
            "has_attachment": bool(item.has_attachment),
            "source": item.source,
        }
        for item in items
    ], ensure_ascii=False)


def deserialize_disclosures(data: str | bytes) -> list[dict[str, Any]]:
    rows = json.loads(data)
    if not isinstance(rows, list):
        return []
    return [
        {
            **row,
            "sent_at": _deserialize_datetime(row.get("sent_at")),
            "published_at": _deserialize_datetime(row.get("published_at")),
        }
        for row in rows
        if isinstance(row, dict) and row.get("tracking_number")
    ]


async def cache_disclosures(items: list[CodalDisclosure | Any]) -> bool:
    redis = get_redis()
    if not redis:
        return False
    try:
        await redis.set(disclosures_key(), serialize_disclosures(items))
        return True
    except Exception as exc:
        logger.warning("cache_disclosures failed: %s", exc)
        return False


async def get_cached_disclosures() -> list[dict[str, Any]] | None:
    redis = get_redis()
    if not redis:
        return None
    try:
        raw = await redis.get(disclosures_key())
        return deserialize_disclosures(raw) if raw else None
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        logger.warning("get_cached_disclosures failed: %s", exc)
        return None


# ═══════════════════════════════════════════════════════════════
# Serialization Helpers
# ═══════════════════════════════════════════════════════════════

def _serialize_decimal(d: Decimal) -> str:
    """Serialize Decimal to string for JSON compatibility."""
    return str(d)


def _deserialize_decimal(s: str) -> Decimal:
    """Deserialize string to Decimal."""
    return Decimal(s)


def _serialize_datetime(dt: datetime | None) -> str | None:
    """Serialize datetime to ISO format string."""
    if dt is None:
        return None
    return dt.isoformat()


def _deserialize_datetime(s: str | None) -> datetime | None:
    """Deserialize ISO format string to datetime."""
    if s is None:
        return None
    return datetime.fromisoformat(s)


def _serialize_optional_decimal(value: Decimal | None) -> str | None:
    return str(value) if value is not None else None


def _deserialize_optional_decimal(value: str | None) -> Decimal | None:
    return Decimal(value) if value is not None else None


def serialize_market_quote(quote: MarketQuote | Any) -> str:
    payload = {
        "instrument_id": quote.instrument_id,
        "symbol": quote.symbol,
        "trade_date": quote.trade_date.isoformat() if quote.trade_date else None,
        "event_time": _serialize_datetime(quote.event_time),
        "first_price": _serialize_optional_decimal(quote.first_price),
        "last_price": _serialize_optional_decimal(quote.last_price),
        "closing_price": _serialize_optional_decimal(quote.closing_price),
        "yesterday_price": _serialize_optional_decimal(quote.yesterday_price),
        "high_price": _serialize_optional_decimal(quote.high_price),
        "low_price": _serialize_optional_decimal(quote.low_price),
        "trade_count": int(quote.trade_count or 0),
        "volume": int(quote.volume or 0),
        "value": _serialize_optional_decimal(quote.value),
        "buy_count": quote.buy_count,
        "sell_count": quote.sell_count,
        "status": quote.status.value if hasattr(quote.status, "value") else str(quote.status or "UNKNOWN"),
        "received_at": _serialize_datetime(quote.received_at),
        "source": quote.source,
    }
    return json.dumps(payload)


def deserialize_market_quote(data: str) -> dict[str, Any] | None:
    try:
        payload = json.loads(data)
        trade_date = payload.get("trade_date")
        return {
            "instrument_id": payload["instrument_id"],
            "symbol": payload["symbol"],
            "trade_date": date.fromisoformat(trade_date) if trade_date else None,
            "event_time": _deserialize_datetime(payload.get("event_time")),
            "first_price": _deserialize_optional_decimal(payload.get("first_price")),
            "last_price": _deserialize_optional_decimal(payload.get("last_price")),
            "closing_price": _deserialize_optional_decimal(payload.get("closing_price")),
            "yesterday_price": _deserialize_optional_decimal(payload.get("yesterday_price")),
            "high_price": _deserialize_optional_decimal(payload.get("high_price")),
            "low_price": _deserialize_optional_decimal(payload.get("low_price")),
            "trade_count": int(payload.get("trade_count") or 0),
            "volume": int(payload.get("volume") or 0),
            "value": _deserialize_optional_decimal(payload.get("value")),
            "buy_count": payload.get("buy_count"),
            "sell_count": payload.get("sell_count"),
            "status": payload.get("status", "UNKNOWN"),
            "received_at": _deserialize_datetime(payload.get("received_at")),
            "source": payload.get("source", "UNKNOWN"),
        }
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        logger.warning("Failed to deserialize market quote: %s", exc)
        return None


async def cache_market_quote(
    quote: MarketQuote | Any,
    *,
    ttl_seconds: int | None = None,
    publish_stream: bool = False,
) -> bool:
    """Cache latest normalized quote by instrument id and symbol.

    No TTL is applied by default because PostgreSQL fallback is required for
    durable reads and Redis is only a latest-snapshot accelerator.
    """
    redis = get_redis()
    if not redis:
        return False

    payload = serialize_market_quote(quote)
    try:
        if ttl_seconds is None:
            await redis.set(quote_key(quote.instrument_id), payload)
            await redis.set(quote_symbol_key(quote.symbol), payload)
        else:
            await redis.setex(quote_key(quote.instrument_id), ttl_seconds, payload)
            await redis.setex(quote_symbol_key(quote.symbol), ttl_seconds, payload)
        await redis.set(last_update_key(), (quote.received_at or quote.event_time or datetime.now(UTC)).isoformat())
        if publish_stream:
            xadd = getattr(redis, "xadd", None)
            if callable(xadd):
                await xadd(quote_stream_key(), {"payload": payload}, maxlen=1000, approximate=True)
        return True
    except Exception as exc:
        logger.warning("cache_market_quote failed for %s: %s", getattr(quote, "instrument_id", "?"), exc)
        return False


async def bulk_cache_market_quotes(
    quotes: list[MarketQuote | Any],
    *,
    ttl_seconds: int | None = None,
    publish_stream: bool = False,
) -> int:
    redis = get_redis()
    if not redis or not quotes:
        return 0
    cached = 0
    try:
        async with redis.pipeline(transaction=False) as pipe:
            for quote in quotes:
                payload = serialize_market_quote(quote)
                if ttl_seconds is None:
                    pipe.set(quote_key(quote.instrument_id), payload)
                    pipe.set(quote_symbol_key(quote.symbol), payload)
                else:
                    pipe.setex(quote_key(quote.instrument_id), ttl_seconds, payload)
                    pipe.setex(quote_symbol_key(quote.symbol), ttl_seconds, payload)
                cached += 1
            latest = max(
                (quote.received_at or quote.event_time for quote in quotes if quote.received_at or quote.event_time),
                default=datetime.now(UTC),
            )
            pipe.set(last_update_key(), latest.isoformat())
            await pipe.execute()
        if publish_stream:
            for quote in quotes:
                await cache_market_quote(quote, ttl_seconds=ttl_seconds, publish_stream=True)
        return cached
    except Exception as exc:
        logger.warning("bulk_cache_market_quotes failed: %s", exc)
        return 0


async def get_market_quote(symbol_or_instrument_id: str) -> dict[str, Any] | None:
    redis = get_redis()
    if not redis:
        return None
    for key in (quote_key(symbol_or_instrument_id), quote_symbol_key(symbol_or_instrument_id)):
        try:
            raw = await redis.get(key)
            if raw:
                return deserialize_market_quote(raw)
        except Exception as exc:
            logger.warning("get_market_quote failed for %s: %s", symbol_or_instrument_id, exc)
            return None
    return None


def serialize_market_indices(indices: list[MarketIndex | Any]) -> str:
    return json.dumps([
        {
            "index_code": item.index_code,
            "name": item.name,
            "value": _serialize_decimal(item.value),
            "change": _serialize_optional_decimal(item.change),
            "change_percent": _serialize_optional_decimal(item.change_percent),
            "event_time": _serialize_datetime(item.event_time),
            "source": item.source,
        }
        for item in indices
    ])


def deserialize_market_indices(data: str) -> list[dict[str, Any]]:
    rows = json.loads(data)
    return [
        {
            "index_code": row["index_code"],
            "name": row["name"],
            "value": _deserialize_decimal(row["value"]),
            "change": _deserialize_optional_decimal(row.get("change")),
            "change_percent": _deserialize_optional_decimal(row.get("change_percent")),
            "event_time": _deserialize_datetime(row.get("event_time")),
            "source": row.get("source", "UNKNOWN"),
        }
        for row in rows
    ]


async def cache_market_indices(indices: list[MarketIndex | Any]) -> bool:
    redis = get_redis()
    if not redis:
        return False
    try:
        await redis.set(indices_key(), serialize_market_indices(indices))
        latest = max((item.event_time for item in indices if item.event_time), default=datetime.now(UTC))
        await redis.set(last_update_key(), latest.isoformat())
        return True
    except Exception as exc:
        logger.warning("cache_market_indices failed: %s", exc)
        return False


async def get_market_indices() -> list[dict[str, Any]] | None:
    redis = get_redis()
    if not redis:
        return None
    try:
        raw = await redis.get(indices_key())
        return deserialize_market_indices(raw) if raw else None
    except Exception as exc:
        logger.warning("get_market_indices failed: %s", exc)
        return None


def serialize_market_overview(item: MarketOverview | Any) -> str:
    return json.dumps(
        {
            "total_index_value": _serialize_decimal(item.total_index_value),
            "total_index_change": _serialize_optional_decimal(item.total_index_change),
            "equal_weight_index_value": _serialize_decimal(item.equal_weight_index_value),
            "equal_weight_index_change": _serialize_optional_decimal(item.equal_weight_index_change),
            "market_value": _serialize_optional_decimal(item.market_value),
            "trades_count": int(item.trades_count),
            "trades_value": _serialize_optional_decimal(item.trades_value),
            "trades_volume": int(item.trades_volume),
            "price_info_timestamp": _serialize_datetime(item.price_info_timestamp),
            "server_received_at": _serialize_datetime(item.server_received_at),
            "source": item.source,
        }
    )


def deserialize_market_overview(data: str) -> dict[str, Any]:
    row = json.loads(data)
    return {
        "total_index_value": _deserialize_decimal(row["total_index_value"]),
        "total_index_change": _deserialize_optional_decimal(row.get("total_index_change")),
        "equal_weight_index_value": _deserialize_decimal(row["equal_weight_index_value"]),
        "equal_weight_index_change": _deserialize_optional_decimal(
            row.get("equal_weight_index_change"),
        ),
        "market_value": _deserialize_optional_decimal(row.get("market_value")),
        "trades_count": int(row.get("trades_count", 0)),
        "trades_value": _deserialize_optional_decimal(row.get("trades_value")),
        "trades_volume": int(row.get("trades_volume", 0)),
        "price_info_timestamp": _deserialize_datetime(row.get("price_info_timestamp")),
        "server_received_at": _deserialize_datetime(row.get("server_received_at")),
        "source": row.get("source", "UNKNOWN"),
    }


async def cache_normalized_market_overview(item: MarketOverview | Any) -> bool:
    redis = get_redis()
    if not redis:
        return False
    try:
        await redis.set(overview_key(), serialize_market_overview(item))
        await redis.set(last_update_key(), item.price_info_timestamp.isoformat())
        return True
    except Exception as exc:
        logger.warning("cache_normalized_market_overview failed: %s", exc)
        return False


async def get_normalized_market_overview() -> dict[str, Any] | None:
    redis = get_redis()
    if not redis:
        return None
    try:
        raw = await redis.get(overview_key())
        return deserialize_market_overview(raw) if raw else None
    except Exception as exc:
        logger.warning("get_normalized_market_overview failed: %s", exc)
        return None


async def cache_market_watch_snapshot(quotes: list[MarketQuote | Any]) -> bool:
    redis = get_redis()
    if not redis:
        return False
    try:
        payload = [json.loads(serialize_market_quote(quote)) for quote in quotes]
        await redis.set(watch_snapshot_key(), json.dumps(payload))
        await redis.set(last_update_key(), datetime.now(UTC).isoformat())
        return True
    except Exception as exc:
        logger.warning("cache_market_watch_snapshot failed: %s", exc)
        return False


async def get_market_watch_snapshot() -> list[dict[str, Any]] | None:
    redis = get_redis()
    if not redis:
        return None
    try:
        raw = await redis.get(watch_snapshot_key())
        if not raw:
            return None
        return [
            item
            for row in json.loads(raw)
            if (item := deserialize_market_quote(json.dumps(row))) is not None
        ]
    except Exception as exc:
        logger.warning("get_market_watch_snapshot failed: %s", exc)
        return None


async def get_market_last_update() -> datetime | None:
    redis = get_redis()
    if not redis:
        return None
    try:
        raw = await redis.get(last_update_key())
        return datetime.fromisoformat(raw) if raw else None
    except Exception as exc:
        logger.warning("get_market_last_update failed: %s", exc)
        return None


# ═══════════════════════════════════════════════════════════════
# Live Market Snapshot Cache
# ═══════════════════════════════════════════════════════════════

def serialize_live_snapshot(snapshot: Any) -> str:
    """Serialize LiveMarketSnapshot to JSON string.

    Accepts any object with the expected attributes (dataclass, Pydantic, etc).
    """
    return json.dumps({
        "ins_code": snapshot.ins_code,
        "ticker": snapshot.ticker,
        "close_price": _serialize_decimal(snapshot.close_price),
        "last_trade_price": _serialize_decimal(snapshot.last_trade_price),
        "price_change": (
            _serialize_decimal(snapshot.price_change)
            if getattr(snapshot, "price_change", None) is not None
            else None
        ),
        "price_change_percent": (
            _serialize_decimal(snapshot.price_change_percent)
            if getattr(snapshot, "price_change_percent", None) is not None
            else None
        ),
        "open_price": _serialize_decimal(snapshot.open_price),
        "high_price": _serialize_decimal(snapshot.high_price),
        "low_price": _serialize_decimal(snapshot.low_price),
        "volume": snapshot.volume,
        "state": snapshot.state.value if hasattr(snapshot.state, "value") else str(snapshot.state),
        "has_corporate_action": snapshot.has_corporate_action,
        "fetched_at": _serialize_datetime(snapshot.fetched_at),
    })


def deserialize_live_snapshot(data: str) -> dict[str, Any] | None:
    """Deserialize JSON string to dict suitable for LiveMarketSnapshot construction.

    Returns None on parse failure.
    """
    try:
        payload = json.loads(data)
        return {
            "ins_code": payload["ins_code"],
            "ticker": payload["ticker"],
            "close_price": _deserialize_decimal(payload["close_price"]),
            "last_trade_price": _deserialize_decimal(payload["last_trade_price"]),
            "price_change": (
                _deserialize_decimal(payload["price_change"])
                if payload.get("price_change") is not None
                else None
            ),
            "price_change_percent": (
                _deserialize_decimal(payload["price_change_percent"])
                if payload.get("price_change_percent") is not None
                else None
            ),
            "open_price": _deserialize_decimal(payload["open_price"]),
            "high_price": _deserialize_decimal(payload["high_price"]),
            "low_price": _deserialize_decimal(payload["low_price"]),
            "volume": int(payload["volume"]),
            "state": payload["state"],
            "has_corporate_action": bool(payload["has_corporate_action"]),
            "fetched_at": _deserialize_datetime(payload.get("fetched_at")),
        }
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        logger.warning("Failed to deserialize live snapshot: %s", exc)
        return None


async def cache_live_snapshot(
    ins_code: str,
    snapshot: Any,
    ttl_seconds: int | None = None,
) -> bool:
    """Write live market snapshot to Redis.

    Args:
        ins_code: TSETMC instrument code.
        snapshot: LiveMarketSnapshot or compatible object.
        ttl_seconds: Time-to-live. Defaults to REDIS_LIVE_PRICE_TTL_SECONDS.

    Returns:
        True if cached successfully, False otherwise.
    """
    redis = get_redis()
    if not redis:
        return False

    key = _snapshot_key(ins_code)
    payload = serialize_live_snapshot(snapshot)
    ttl = ttl_seconds or settings.REDIS_LIVE_PRICE_TTL_SECONDS

    try:
        await redis.setex(key, ttl, payload)
        return True
    except Exception as exc:
        logger.warning("cache_live_snapshot failed for %s: %s", ins_code, exc)
        return False


async def get_live_snapshot(ins_code: str) -> dict[str, Any] | None:
    """Read live market snapshot from Redis.

    Returns:
        Dict with snapshot fields if found, None on miss or error.
    """
    redis = get_redis()
    if not redis:
        return None

    key = _snapshot_key(ins_code)
    try:
        raw = await redis.get(key)
        if raw:
            return deserialize_live_snapshot(raw)
    except Exception as exc:
        logger.warning("get_live_snapshot failed for %s: %s", ins_code, exc)

    return None


async def bulk_cache_live_snapshots(
    snapshots: list[Any],
    ttl_seconds: int | None = None,
) -> int:
    """Batch-write multiple live snapshots using Redis pipeline.

    Args:
        snapshots: List of LiveMarketSnapshot or compatible objects.
        ttl_seconds: Time-to-live for all entries.

    Returns:
        Number of successfully cached snapshots.
    """
    redis = get_redis()
    if not redis or not snapshots:
        return 0

    ttl = ttl_seconds or settings.REDIS_LIVE_PRICE_TTL_SECONDS
    cached_count = 0

    try:
        async with redis.pipeline(transaction=False) as pipe:
            for snapshot in snapshots:
                key = _snapshot_key(snapshot.ins_code)
                payload = serialize_live_snapshot(snapshot)
                pipe.setex(key, ttl, payload)
            results = await pipe.execute()
            cached_count = sum(1 for r in results if r)
        logger.debug("bulk_cached %d live snapshots", cached_count)
    except Exception as exc:
        logger.warning("bulk_cache_live_snapshots failed: %s", exc)

    return cached_count


async def invalidate_live_snapshot(ins_code: str) -> bool:
    """Remove a live snapshot from Redis cache.

    Returns:
        True if key was deleted, False otherwise.
    """
    redis = get_redis()
    if not redis:
        return False

    key = _snapshot_key(ins_code)
    try:
        result = await redis.delete(key)
        return result > 0
    except Exception as exc:
        logger.warning("invalidate_live_snapshot failed for %s: %s", ins_code, exc)
        return False


# ═══════════════════════════════════════════════════════════════
# Index Snapshot Cache
# ═══════════════════════════════════════════════════════════════

def serialize_index_snapshot(snapshot: Any) -> str:
    """Serialize IndexSnapshot to JSON string."""
    return json.dumps({
        "index_code": snapshot.index_code,
        "name": snapshot.name,
        "last_value": _serialize_decimal(snapshot.last_value),
        "change_value": _serialize_decimal(snapshot.change_value),
        "change_percent": _serialize_decimal(snapshot.change_percent),
        "open_value": _serialize_decimal(snapshot.open_value),
        "high_value": _serialize_decimal(snapshot.high_value),
        "low_value": _serialize_decimal(snapshot.low_value),
        "volume": snapshot.volume,
        "fetched_at": _serialize_datetime(snapshot.fetched_at),
    })


def deserialize_index_snapshot(data: str) -> dict[str, Any] | None:
    """Deserialize JSON string to dict suitable for IndexSnapshot construction."""
    try:
        payload = json.loads(data)
        return {
            "index_code": payload["index_code"],
            "name": payload["name"],
            "last_value": _deserialize_decimal(payload["last_value"]),
            "change_value": _deserialize_decimal(payload["change_value"]),
            "change_percent": _deserialize_decimal(payload["change_percent"]),
            "open_value": _deserialize_decimal(payload["open_value"]),
            "high_value": _deserialize_decimal(payload["high_value"]),
            "low_value": _deserialize_decimal(payload["low_value"]),
            "volume": int(payload["volume"]),
            "fetched_at": _deserialize_datetime(payload.get("fetched_at")),
        }
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        logger.warning("Failed to deserialize index snapshot: %s", exc)
        return None


async def cache_index_snapshot(
    index_code: str,
    snapshot: Any,
    ttl_seconds: int | None = None,
) -> bool:
    """Write index snapshot to Redis."""
    redis = get_redis()
    if not redis:
        return False

    key = _index_key(index_code)
    payload = serialize_index_snapshot(snapshot)
    ttl = ttl_seconds or settings.REDIS_LIVE_PRICE_TTL_SECONDS

    try:
        await redis.setex(key, ttl, payload)
        return True
    except Exception as exc:
        logger.warning("cache_index_snapshot failed for %s: %s", index_code, exc)
        return False


async def get_index_snapshot(index_code: str) -> dict[str, Any] | None:
    """Read index snapshot from Redis."""
    redis = get_redis()
    if not redis:
        return None

    key = _index_key(index_code)
    try:
        raw = await redis.get(key)
        if raw:
            return deserialize_index_snapshot(raw)
    except Exception as exc:
        logger.warning("get_index_snapshot failed for %s: %s", index_code, exc)

    return None


# ═══════════════════════════════════════════════════════════════
# Sync Metadata Cache
# ═══════════════════════════════════════════════════════════════

async def cache_sync_status(
    *,
    last_sync_at: datetime,
    synced_assets: int,
    failed_assets: int,
    provider_status: str,
) -> bool:
    """Write sync status metadata to Redis (persistent, no TTL)."""
    redis = get_redis()
    if not redis:
        return False

    key = _sync_status_key()
    payload = json.dumps({
        "last_sync_at": _serialize_datetime(last_sync_at),
        "synced_assets": synced_assets,
        "failed_assets": failed_assets,
        "provider_status": provider_status,
        "updated_at": datetime.now(UTC).isoformat(),
    })

    try:
        await redis.set(key, payload)
        return True
    except Exception as exc:
        logger.warning("cache_sync_status failed: %s", exc)
        return False


async def get_sync_status() -> dict[str, Any] | None:
    """Read sync status metadata from Redis."""
    redis = get_redis()
    if not redis:
        return None

    key = _sync_status_key()
    try:
        raw = await redis.get(key)
        if raw:
            return json.loads(raw)
    except Exception as exc:
        logger.warning("get_sync_status failed: %s", exc)

    return None
