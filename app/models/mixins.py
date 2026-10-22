"""
Reusable SQLAlchemy 2.0 mixins for UUID primary keys and audit timestamps.

Every table in the system inherits both mixins through composition,
guaranteeing consistent PK strategy and temporal auditing.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column


class UUIDMixin:
    """
    Provides a UUID v4 primary key column named `id`.
    PostgreSQL stores this as a native 128-bit UUID type (not CHAR(36)).
    """
    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        sort_order=-10,  # ensure `id` appears first in CREATE TABLE
    )


class TimestampMixin:
    """
    Automatic `created_at` and `updated_at` columns.

    • `created_at`: set ONCE by the DB server via `server_default`.
    • `updated_at`: updated by SQLAlchemy on every flush via `onupdate`,
       AND has a DB-level default for rows inserted outside the ORM
       (e.g., data migrations).
    """
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        sort_order=9000,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        sort_order=9001,
    )


class AuditTrailMixin(TimestampMixin):
    """
    Immutable user attribution for write-side commands.

    Each row stores the authenticated user who created the record.
    """

    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        sort_order=8999,
    )
