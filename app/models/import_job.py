"""Import job audit table for broker Excel ingestion pipelines."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    DateTime,
    Enum as PGEnum,
    ForeignKey,
    Index,
    Integer,
    String,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.enums import ImportJobStatus
from app.models.mixins import TimestampMixin, UUIDMixin


class ImportJob(UUIDMixin, TimestampMixin, Base):
    """Tracks each upload, lifecycle status, and reconciliation errors."""

    __tablename__ = "import_jobs"
    __table_args__ = (
        Index("ix_import_jobs_user_created", "user_id", "created_at"),
        Index("ix_import_jobs_status_created", "status", "created_at"),
        CheckConstraint("total_rows >= 0", name="ck_import_jobs_total_rows_non_negative"),
        CheckConstraint("parsed_rows >= 0", name="ck_import_jobs_parsed_rows_non_negative"),
        CheckConstraint("inserted_rows >= 0", name="ck_import_jobs_inserted_rows_non_negative"),
        CheckConstraint("duplicates_skipped >= 0", name="ck_import_jobs_duplicates_non_negative"),
        CheckConstraint("failed_rows >= 0", name="ck_import_jobs_failed_rows_non_negative"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    portfolio_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    source_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    broker_format: Mapped[str | None] = mapped_column(String(32), nullable=True)

    status: Mapped[ImportJobStatus] = mapped_column(
        PGEnum(ImportJobStatus, name="import_job_status_enum", create_type=True),
        nullable=False,
        default=ImportJobStatus.PENDING,
        index=True,
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    total_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    parsed_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    inserted_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    duplicates_skipped: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    failed_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    error_details: Mapped[list[dict[str, Any]]] = mapped_column(
        JSONB,
        nullable=False,
        default=list,
        comment="RFC 7807 row-level errors for reconciliation and audit.",
    )
    diagnostics: Mapped[dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        comment="Structured import diagnostics summary (parser, counts, created entities).",
    )
