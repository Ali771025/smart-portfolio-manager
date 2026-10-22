"""File storage service for uploaded Excel files with validation and metadata tracking."""

from __future__ import annotations

import hashlib
import logging
import os
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import BinaryIO

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.uploaded_file import UploadedFile

logger = logging.getLogger(__name__)

ALLOWED_EXCEL_EXTENSIONS = (".xlsx", ".xlsm", ".xls")
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


class FileStorageError(Exception):
    """Base exception for file storage operations."""


class FileValidationError(FileStorageError):
    """Raised when file validation fails."""


class FileStorageService:
    """Handles secure storage and retrieval of uploaded Excel files."""

    def __init__(self, storage_root: str | Path) -> None:
        self.storage_root = Path(storage_root)
        self.storage_root.mkdir(parents=True, exist_ok=True)

    def validate_excel_file(
        self,
        *,
        filename: str,
        file_bytes: bytes,
    ) -> None:
        """Validate Excel file extension, size, and signature.
        
        Raises:
            FileValidationError: If validation fails.
        """
        # Extension check
        lower_name = filename.lower()
        if not any(lower_name.endswith(ext) for ext in ALLOWED_EXCEL_EXTENSIONS):
            raise FileValidationError(
                f"Unsupported file extension. Allowed: {', '.join(ALLOWED_EXCEL_EXTENSIONS)}"
            )

        # Size check
        if len(file_bytes) == 0:
            raise FileValidationError("File is empty")
        if len(file_bytes) > MAX_FILE_SIZE_BYTES:
            raise FileValidationError(
                f"File size {len(file_bytes)} bytes exceeds maximum {MAX_FILE_SIZE_BYTES} bytes"
            )

        # Signature check
        if not self._matches_excel_signature(file_bytes, filename=filename):
            raise FileValidationError("File signature does not match Excel format")

    @staticmethod
    def _matches_excel_signature(content: bytes, *, filename: str) -> bool:
        """Verify file signature matches Excel format."""
        lower_name = filename.lower()
        if lower_name.endswith((".xlsx", ".xlsm")):
            # ZIP signature (XLSX/XLSM are ZIP archives)
            return content.startswith(b"PK\x03\x04")
        if lower_name.endswith(".xls"):
            # OLE2 signature (legacy XLS format)
            return content.startswith(bytes.fromhex("D0CF11E0A1B11AE1"))
        return False

    @staticmethod
    def compute_content_hash(file_bytes: bytes) -> str:
        """Compute SHA256 hash of file content."""
        return hashlib.sha256(file_bytes).hexdigest()

    def generate_safe_filename(self, original_filename: str) -> str:
        """Generate a safe, unique filename using UUID.
        
        Preserves original extension for compatibility.
        """
        # Extract extension safely
        ext = ""
        for allowed_ext in ALLOWED_EXCEL_EXTENSIONS:
            if original_filename.lower().endswith(allowed_ext):
                ext = allowed_ext
                break
        
        # Generate UUID-based filename
        unique_id = uuid.uuid4()
        return f"{unique_id}{ext}"

    def get_storage_path(self, stored_filename: str) -> Path:
        """Get full storage path for a stored filename.
        
        Uses date-based subdirectories for organization.
        """
        # Organize by year/month for better filesystem performance
        now = datetime.now(UTC)
        subdir = self.storage_root / str(now.year) / f"{now.month:02d}"
        subdir.mkdir(parents=True, exist_ok=True)
        return subdir / stored_filename

    async def store_file(
        self,
        *,
        db: AsyncSession,
        user_id: uuid.UUID,
        original_filename: str,
        file_bytes: bytes,
        import_job_id: uuid.UUID | None = None,
    ) -> UploadedFile:
        """Store uploaded file with metadata tracking.
        
        Args:
            db: Database session
            user_id: User who uploaded the file
            original_filename: Original filename from upload
            file_bytes: File content
            import_job_id: Optional import job ID to link
            
        Returns:
            UploadedFile metadata record
            
        Raises:
            FileValidationError: If file validation fails
            FileStorageError: If storage operation fails
        """
        # Validate file
        self.validate_excel_file(filename=original_filename, file_bytes=file_bytes)

        # Generate safe filename and compute hash
        stored_filename = self.generate_safe_filename(original_filename)
        content_hash = self.compute_content_hash(file_bytes)
        storage_path = self.get_storage_path(stored_filename)

        # Write file to disk
        try:
            storage_path.write_bytes(file_bytes)
            logger.info(
                "File stored successfully",
                extra={
                    "user_id": str(user_id),
                    "original_filename": original_filename,
                    "stored_filename": stored_filename,
                    "storage_path": str(storage_path),
                    "file_size_bytes": len(file_bytes),
                    "content_hash": content_hash,
                },
            )
        except OSError as ex:
            logger.error(
                "Failed to write file to storage",
                extra={
                    "user_id": str(user_id),
                    "original_filename": original_filename,
                    "storage_path": str(storage_path),
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )
            raise FileStorageError(f"Failed to write file to storage: {ex}") from ex

        # Create metadata record
        uploaded_file = UploadedFile(
            user_id=user_id,
            import_job_id=import_job_id,
            original_filename=original_filename,
            stored_filename=stored_filename,
            storage_path=str(storage_path),
            file_size_bytes=len(file_bytes),
            content_hash=content_hash,
            uploaded_at=datetime.now(UTC),
        )
        db.add(uploaded_file)
        await db.flush()
        await db.refresh(uploaded_file)

        return uploaded_file

    def read_file(self, uploaded_file: UploadedFile) -> bytes:
        """Read stored file content.
        
        Args:
            uploaded_file: Metadata record
            
        Returns:
            File content as bytes
            
        Raises:
            FileStorageError: If file cannot be read
        """
        storage_path = Path(uploaded_file.storage_path)
        
        if not storage_path.exists():
            logger.error(
                "Stored file not found",
                extra={
                    "uploaded_file_id": str(uploaded_file.id),
                    "storage_path": str(storage_path),
                },
            )
            raise FileStorageError(f"Stored file not found: {storage_path}")

        try:
            content = storage_path.read_bytes()
            
            # Verify content hash
            computed_hash = self.compute_content_hash(content)
            if computed_hash != uploaded_file.content_hash:
                logger.error(
                    "File content hash mismatch",
                    extra={
                        "uploaded_file_id": str(uploaded_file.id),
                        "expected_hash": uploaded_file.content_hash,
                        "computed_hash": computed_hash,
                    },
                )
                raise FileStorageError("File content hash mismatch - file may be corrupted")
            
            return content
        except OSError as ex:
            logger.error(
                "Failed to read stored file",
                extra={
                    "uploaded_file_id": str(uploaded_file.id),
                    "storage_path": str(storage_path),
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )
            raise FileStorageError(f"Failed to read stored file: {ex}") from ex

    def delete_file(self, uploaded_file: UploadedFile) -> None:
        """Delete stored file from disk.
        
        Args:
            uploaded_file: Metadata record
            
        Note:
            Does not delete the database record, only the physical file.
        """
        storage_path = Path(uploaded_file.storage_path)
        
        if not storage_path.exists():
            logger.warning(
                "Attempted to delete non-existent file",
                extra={
                    "uploaded_file_id": str(uploaded_file.id),
                    "storage_path": str(storage_path),
                },
            )
            return

        try:
            storage_path.unlink()
            logger.info(
                "File deleted successfully",
                extra={
                    "uploaded_file_id": str(uploaded_file.id),
                    "storage_path": str(storage_path),
                },
            )
        except OSError as ex:
            logger.error(
                "Failed to delete stored file",
                extra={
                    "uploaded_file_id": str(uploaded_file.id),
                    "storage_path": str(storage_path),
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )
            raise FileStorageError(f"Failed to delete stored file: {ex}") from ex
