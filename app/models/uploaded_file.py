"""Uploaded Excel file metadata and storage tracking."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.mixins import TimestampMixin, UUIDMixin


class UploadedFile(UUIDMixin, TimestampMixin, Base):
    """Tracks uploaded Excel files with metadata and storage location."""

    __tablename__ = "uploaded_files"
    __table_args__ = (
        Index("ix_uploaded_files_user_created", "user_id", "created_at"),
        Index("ix_uploaded_files_import_job", "import_job_id"),
        Index("ix_uploaded_files_content_hash", "content_hash"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    import_job_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("import_jobs.id", ondelete="SET NULL"),
        nullable=True,
    )

    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_filename: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    storage_path: Mapped[str] = mapped_column(String(512), nullable=False)
    
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    content_hash: Mapped[str] = mapped_column(String(64), nullable=False, comment="SHA256 hash")
    
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
