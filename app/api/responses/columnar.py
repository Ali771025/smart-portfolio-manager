"""Custom FastAPI responses for Arrow IPC and MessagePack payloads."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Any, Mapping
from uuid import UUID

from fastapi.responses import Response
from pydantic import BaseModel


def is_msgpack_available() -> bool:
    try:
        import msgpack  # noqa: F401
        return True
    except Exception:
        return False


def _to_primitive(value: Any) -> Any:
    """Normalize objects so both MessagePack and Arrow writers can encode quickly."""

    if isinstance(value, BaseModel):
        return value.model_dump(mode="json")
    if isinstance(value, Mapping):
        return {str(key): _to_primitive(inner) for key, inner in value.items()}
    if isinstance(value, list):
        return [_to_primitive(item) for item in value]
    if isinstance(value, tuple):
        return [_to_primitive(item) for item in value]
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):
        return value
    if isinstance(value, UUID):
        return str(value)
    return value


class ArrowIPCResponse(Response):
    """Return Apache Arrow stream bytes for low-overhead dense time-series APIs."""

    media_type = "application/vnd.apache.arrow.stream"

    def render(self, content: Any) -> bytes:
        if content is None:
            return b""

        try:
            import pyarrow as pa
            import pyarrow.ipc as ipc
        except Exception as exc:  # pragma: no cover - import guard only
            raise RuntimeError(
                "pyarrow is required for Arrow IPC responses. Install pyarrow to enable this route."
            ) from exc

        table = self._coerce_table(content, pa=pa)
        sink = pa.BufferOutputStream()
        with ipc.new_stream(sink, table.schema) as writer:
            writer.write_table(table)
        return sink.getvalue().to_pybytes()

    @staticmethod
    def _coerce_table(content: Any, *, pa: Any) -> Any:
        if isinstance(content, pa.Table):
            return content
        if isinstance(content, pa.RecordBatch):
            return pa.Table.from_batches([content])

        primitive = _to_primitive(content)

        if isinstance(primitive, Mapping):
            schema = primitive.get("schema")
            rows = primitive.get("rows")
            columns = primitive.get("columns")

            if rows is not None:
                normalized_rows = [_to_primitive(item) for item in rows]
                return pa.Table.from_pylist(normalized_rows, schema=schema)
            if columns is not None:
                normalized_columns = {key: _to_primitive(value) for key, value in columns.items()}
                return pa.Table.from_pydict(normalized_columns, schema=schema)

            normalized_columns = {key: _to_primitive(value) for key, value in primitive.items()}
            return pa.Table.from_pydict(normalized_columns, schema=schema)

        if isinstance(primitive, list):
            return pa.Table.from_pylist(primitive)

        raise TypeError("ArrowIPCResponse content must be a pyarrow table, rows list, or column dict")


class MessagePackResponse(Response):
    """Return MessagePack bytes with predictable encodings for financial payloads."""

    media_type = "application/msgpack"

    def render(self, content: Any) -> bytes:
        if content is None:
            return b""

        try:
            import msgpack
        except Exception as exc:  # pragma: no cover - import guard only
            raise RuntimeError(
                "msgpack is required for MessagePack responses. Install msgpack to enable this route."
            ) from exc

        payload = _to_primitive(content)
        return msgpack.packb(payload, use_bin_type=True, default=self._default_encoder)

    @staticmethod
    def _default_encoder(value: Any) -> Any:
        if isinstance(value, datetime):
            return value.isoformat()
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, UUID):
            return str(value)
        if isinstance(value, Enum):
            return value.value
        if isinstance(value, BaseModel):
            return value.model_dump(mode="json")
        raise TypeError(f"Unsupported MessagePack type: {type(value)!r}")
