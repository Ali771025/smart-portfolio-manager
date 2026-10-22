"""Domain service for broker Excel ingestion into immutable transactions ledger."""

from __future__ import annotations

import logging
import math
import os
import traceback
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import pandas as pd
from fastapi import BackgroundTasks
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.database import async_session_factory
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import ImportJobStatus, TransactionType
from app.models.holding_snapshot import HoldingSnapshot
from app.models.import_job import ImportJob
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.schemas.imports import ImportJobRead, ImportRowError, ImportTradesReport
from app.services.excel_parser_utils import (
    ExcelFormatDetectionError,
    ImportFileKind,
    ParseWorkbookResult,
    ParsedBrokerTransaction,
    ParsedPortfolioPosition,
    parse_excel_transactions,
)
from app.services.file_storage_service import FileStorageService, FileValidationError
from app.services.ledger_hashing import build_reference_hash, q8
from app.services.asset_resolver_service import AssetResolverService
from app.services.portfolio_state_recompute_service import PortfolioStateRecomputeService
from app.services.portfolio_membership_service import PortfolioMembershipService
from app.services.pnl_calculator import PnLCalculatorService
from app.services.trade_reconciliation_service import TradeReconciliationService
from app.repositories.market_data import MarketDataRepository
from app.repositories.pnl import PnLRepository

logging.basicConfig(level=logging.DEBUG)
ZERO = Decimal("0.00000000")
logger = logging.getLogger(__name__)

# Get storage root from environment or use default
UPLOAD_STORAGE_ROOT = os.getenv("UPLOAD_STORAGE_ROOT", "/tmp/portfolio_uploads")


class PortfolioOwnershipError(LookupError):
    """Raised when an import targets a portfolio inaccessible to the current user."""


class ImportService:
    """Transactional import coordinator with explicit audit trail and reconciliation output."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.file_storage = FileStorageService(storage_root=UPLOAD_STORAGE_ROOT)

    async def import_trades(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        file_bytes: bytes,
        source_filename: str,
        background_tasks: BackgroundTasks | None = None,
    ) -> ImportTradesReport:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)

        # Store uploaded file with metadata
        try:
            uploaded_file = await self.file_storage.store_file(
                db=self.db,
                user_id=user_id,
                original_filename=source_filename,
                file_bytes=file_bytes,
            )
            await self.db.commit()
        except FileValidationError as ex:
            logger.warning("File validation failed", extra={"user_id": str(user_id), "filename": source_filename})
            raise ValueError(f"File validation failed: {ex}") from ex

        job = ImportJob(
            user_id=user_id,
            portfolio_id=portfolio_id,
            source_filename=source_filename,
            status=ImportJobStatus.PENDING,
            started_at=datetime.now(UTC),
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
            error_details=[],
        )
        self.db.add(job)
        await self.db.flush()
        await self.db.commit()
        await self.db.refresh(job)

        # Link uploaded file to import job
        uploaded_file.import_job_id = job.id
        self.db.add(uploaded_file)
        await self.db.commit()

        logger.info("Import job created with file storage", extra={"job_id": str(job.id), "uploaded_file_id": str(uploaded_file.id)})

        parse_result, parse_errors = self._safe_parse(
            file_bytes=file_bytes,
            instance_base=f"/api/v1/import/jobs/{job.id}",
            source_filename=source_filename,
        )

        broker_format = parse_result.broker_format.value if parse_result else None
        total_rows = parse_result.total_rows if parse_result else 0

        if parse_result is None:
            await self._update_job_status(
                job_id=job.id,
                status=ImportJobStatus.FAILED,
                broker_format=broker_format,
                total_rows=total_rows,
                parsed_rows=0,
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(parse_errors),
                errors=parse_errors,
                completed_at=datetime.now(UTC),
            )
            return await self._build_report(
                job_id=job.id,
                errors=parse_errors,
                inserted_reference_hashes=[],
                analysis={},
            )

        if parse_result.file_kind == ImportFileKind.PORTFOLIO_SNAPSHOT:
            snapshot_error = self._problem(
                title="Wrong Import Endpoint for Portfolio Snapshot",
                detail=(
                    "This is a Portfolio Holdings file, not a Trade History file. "
                    "Use the portfolio snapshot/initial balances import flow."
                ),
                instance=f"/api/v1/import/jobs/{job.id}/file_type",
                row_number=None,
                row_payload={
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                },
                status=422,
                problem_type="wrong_file_type",
            )
            all_errors = [*parse_errors, snapshot_error]
            await self._update_job_status(
                job_id=job.id,
                status=ImportJobStatus.FAILED,
                broker_format=broker_format,
                total_rows=total_rows,
                parsed_rows=len(parse_result.parsed_positions),
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(all_errors),
                errors=all_errors,
                completed_at=datetime.now(UTC),
            )
            return await self._build_report(
                job_id=job.id,
                errors=all_errors,
                inserted_reference_hashes=[],
                analysis={
                    "mode": "import",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_positions": len(parse_result.parsed_positions),
                },
            )

        # If no trade candidates remained after skipping non-trade rows, return
        # a successful no-op preview/import report instead of forcing a hard failure.
        if not parse_result.parsed_rows:
            await self._update_job_status(
                job_id=job.id,
                status=ImportJobStatus.COMPLETED,
                broker_format=broker_format,
                total_rows=total_rows,
                parsed_rows=0,
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(parse_errors),
                errors=parse_errors,
                completed_at=datetime.now(UTC),
            )
            return await self._build_report(
                job_id=job.id,
                errors=parse_errors,
                inserted_reference_hashes=[],
                analysis={
                    "mode": "import",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_rows": 0,
                    "skipped_non_trade_rows": parse_result.total_rows,
                },
            )

        ingest_result = await self._ingest_parsed_rows(
            job_id=job.id,
            user_id=user_id,
            portfolio_id=portfolio_id,
            parse_result=parse_result,
            parse_errors=parse_errors,
            source_filename=source_filename,
        )
        recompute_result = await PortfolioStateRecomputeService(self.db).recompute_portfolio_state(
            portfolio_id=portfolio_id,
            rebuild_positions=True,
        )
        logger.info(
            "import_trades_recompute_completed",
            extra={
                "job_id": str(job.id),
                "portfolio_id": str(portfolio_id),
                "snapshot_date": recompute_result.snapshot_date.isoformat(),
                "recomputed_at": recompute_result.completed_at.isoformat(),
                "positions_rebuilt": recompute_result.positions_rebuilt,
                "transactions_repriced": recompute_result.transactions_repriced,
            },
        )

        analysis = await self._compute_post_import_analysis(
            portfolio_id=portfolio_id,
            user_id=user_id,
        )
        ingest_diagnostics = ingest_result.get("diagnostics")
        if isinstance(ingest_diagnostics, dict):
            analysis.update({f"import_{key}": value for key, value in ingest_diagnostics.items()})
        analysis.update(
            {
                "recompute_status": "completed",
                "recompute_snapshot_date": recompute_result.snapshot_date.isoformat(),
                "recompute_completed_at": recompute_result.completed_at.isoformat(),
                "recompute_positions_rebuilt": recompute_result.positions_rebuilt,
                "analytics_updated_at": recompute_result.completed_at.isoformat(),
                "dashboard_updated_at": recompute_result.completed_at.isoformat(),
            }
        )

        if background_tasks is not None:
            background_tasks.add_task(
                self._run_async_analysis_refresh,
                portfolio_id=portfolio_id,
                user_id=user_id,
                job_id=job.id,
            )

        return await self._build_report(
            job_id=job.id,
            errors=ingest_result["errors"],
            inserted_reference_hashes=ingest_result["inserted_reference_hashes"],
            analysis=analysis,
        )

    async def import_portfolio_snapshot(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        file_bytes: bytes,
        source_filename: str,
    ) -> ImportTradesReport:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)

        try:
            uploaded_file = await self.file_storage.store_file(
                db=self.db,
                user_id=user_id,
                original_filename=source_filename,
                file_bytes=file_bytes,
            )
            await self.db.commit()
        except FileValidationError as ex:
            logger.warning("File validation failed", extra={"user_id": str(user_id), "filename": source_filename})
            raise ValueError(f"File validation failed: {ex}") from ex

        job = ImportJob(
            user_id=user_id,
            portfolio_id=portfolio_id,
            source_filename=source_filename,
            status=ImportJobStatus.PENDING,
            started_at=datetime.now(UTC),
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
            error_details=[],
        )
        self.db.add(job)
        await self.db.flush()
        await self.db.commit()
        await self.db.refresh(job)

        uploaded_file.import_job_id = job.id
        self.db.add(uploaded_file)
        await self.db.commit()

        parse_result, parse_errors = self._safe_parse(
            file_bytes=file_bytes,
            instance_base=f"/api/v1/import/snapshot/jobs/{job.id}",
            source_filename=source_filename,
        )

        broker_format = parse_result.broker_format.value if parse_result else None
        total_rows = parse_result.total_rows if parse_result else 0

        if parse_result is None:
            await self._update_job_status(
                job_id=job.id,
                status=ImportJobStatus.FAILED,
                broker_format=broker_format,
                total_rows=total_rows,
                parsed_rows=0,
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(parse_errors),
                errors=parse_errors,
                completed_at=datetime.now(UTC),
            )
            return await self._build_report(
                job_id=job.id,
                errors=parse_errors,
                inserted_reference_hashes=[],
                analysis={
                    "mode": "snapshot_import",
                    "source_filename": source_filename,
                    "file_type": "UNKNOWN",
                },
            )

        if parse_result.file_kind != ImportFileKind.PORTFOLIO_SNAPSHOT:
            wrong_type_error = self._problem(
                title="Wrong Import Endpoint for Trade Ledger",
                detail=(
                    "This is a Trade History file, not a Portfolio Holdings file. "
                    "Use the trade import endpoint."
                ),
                instance=f"/api/v1/import/snapshot/jobs/{job.id}/file_type",
                row_number=None,
                row_payload={
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                },
                status=422,
                problem_type="wrong_file_type",
            )
            all_errors = [*parse_errors, wrong_type_error]
            await self._update_job_status(
                job_id=job.id,
                status=ImportJobStatus.FAILED,
                broker_format=broker_format,
                total_rows=total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(all_errors),
                errors=all_errors,
                completed_at=datetime.now(UTC),
            )
            return await self._build_report(
                job_id=job.id,
                errors=all_errors,
                inserted_reference_hashes=[],
                analysis={
                    "mode": "snapshot_import",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_rows": len(parse_result.parsed_rows),
                },
            )

        ingest_result = await self._ingest_snapshot_positions(
            job_id=job.id,
            portfolio_id=portfolio_id,
            parse_result=parse_result,
            parse_errors=parse_errors,
        )
        recompute_result = await PortfolioStateRecomputeService(self.db).recompute_portfolio_state(
            portfolio_id=portfolio_id,
            rebuild_positions=True,
        )
        logger.info(
            "import_snapshot_recompute_completed",
            extra={
                "job_id": str(job.id),
                "portfolio_id": str(portfolio_id),
                "snapshot_date": recompute_result.snapshot_date.isoformat(),
                "recomputed_at": recompute_result.completed_at.isoformat(),
                "positions_rebuilt": recompute_result.positions_rebuilt,
                "transactions_repriced": recompute_result.transactions_repriced,
            },
        )

        analysis = await self._compute_post_import_analysis(
            portfolio_id=portfolio_id,
            user_id=user_id,
        )
        ingest_diagnostics = ingest_result.get("diagnostics")
        if isinstance(ingest_diagnostics, dict):
            analysis.update({f"import_{key}": value for key, value in ingest_diagnostics.items()})
        analysis.update(
            {
                "recompute_status": "completed",
                "recompute_snapshot_date": recompute_result.snapshot_date.isoformat(),
                "recompute_completed_at": recompute_result.completed_at.isoformat(),
                "recompute_positions_rebuilt": recompute_result.positions_rebuilt,
                "analytics_updated_at": recompute_result.completed_at.isoformat(),
                "dashboard_updated_at": recompute_result.completed_at.isoformat(),
            }
        )
        analysis.update(
            {
                "mode": "snapshot_import",
                "file_type": parse_result.file_kind.value,
                "broker_format": parse_result.broker_format.value,
                "total_rows": parse_result.total_rows,
                "parsed_positions": len(parse_result.parsed_positions),
                "applied_positions": ingest_result["inserted_count"],
            }
        )
        return await self._build_report(
            job_id=job.id,
            errors=ingest_result["errors"],
            inserted_reference_hashes=[],
            analysis=analysis,
        )

    async def preview_trades(
        self,
        *,
        file_bytes: bytes,
        source_filename: str,
    ) -> ImportTradesReport:
        parse_result, parse_errors = self._safe_parse(
            file_bytes=file_bytes,
            instance_base="/api/v1/import/preview",
            source_filename=source_filename,
        )

        if parse_result is None:
            safe_errors = [self._sanitize_json_value(item) for item in parse_errors]
            return ImportTradesReport(
                job=None,
                inserted_count=0,
                duplicates_skipped_count=0,
                failed_count=len(safe_errors),
                errors=[ImportRowError.model_validate(item) for item in safe_errors],
                inserted_reference_hashes=[],
                analysis={
                    "mode": "preview",
                    "source_filename": source_filename,
                    "file_type": "UNKNOWN",
                },
            )

        if parse_result.file_kind == ImportFileKind.PORTFOLIO_SNAPSHOT:
            safe_errors = [self._sanitize_json_value(item) for item in parse_errors]
            return ImportTradesReport(
                job=None,
                inserted_count=0,
                duplicates_skipped_count=0,
                failed_count=len(safe_errors),
                errors=[ImportRowError.model_validate(item) for item in safe_errors],
                inserted_reference_hashes=[],
                analysis={
                    "mode": "preview",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_positions": len(parse_result.parsed_positions),
                    "valid_positions": max(
                        len(parse_result.parsed_positions),
                        0,
                    ),
                },
            )

        validation_errors: list[dict[str, Any]] = []
        for row in parse_result.parsed_rows:
            validation_error = self._validate_financial_row(
                row=row,
                instance_base="/api/v1/import/preview",
            )
            if validation_error is not None:
                validation_errors.append(validation_error)

        errors = [*parse_errors, *validation_errors]
        safe_errors = [self._sanitize_json_value(item) for item in errors]
        parsed_rows = len(parse_result.parsed_rows)
        if parsed_rows == 0:
            return ImportTradesReport(
                job=None,
                inserted_count=0,
                duplicates_skipped_count=0,
                failed_count=len(safe_errors),
                errors=[ImportRowError.model_validate(item) for item in safe_errors],
                inserted_reference_hashes=[],
                analysis={
                    "mode": "preview",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_rows": 0,
                    "valid_rows": 0,
                    "skipped_non_trade_rows": parse_result.total_rows,
                },
            )
        return ImportTradesReport(
            job=None,
            inserted_count=0,
            duplicates_skipped_count=0,
            failed_count=len(safe_errors),
            errors=[ImportRowError.model_validate(item) for item in safe_errors],
            inserted_reference_hashes=[],
            analysis={
                "mode": "preview",
                "source_filename": source_filename,
                "file_type": parse_result.file_kind.value,
                "broker_format": parse_result.broker_format.value,
                "total_rows": parse_result.total_rows,
                "parsed_rows": len(parse_result.parsed_rows),
                "valid_rows": max(
                    len(parse_result.parsed_rows) - len(validation_errors),
                    0,
                ),
            },
        )

    async def preview_portfolio_snapshot(
        self,
        *,
        file_bytes: bytes,
        source_filename: str,
    ) -> ImportTradesReport:
        parse_result, parse_errors = self._safe_parse(
            file_bytes=file_bytes,
            instance_base="/api/v1/import/snapshot/preview",
            source_filename=source_filename,
        )

        if parse_result is None:
            safe_errors = [self._sanitize_json_value(item) for item in parse_errors]
            return ImportTradesReport(
                job=None,
                inserted_count=0,
                duplicates_skipped_count=0,
                failed_count=len(safe_errors),
                errors=[ImportRowError.model_validate(item) for item in safe_errors],
                inserted_reference_hashes=[],
                analysis={
                    "mode": "snapshot_preview",
                    "source_filename": source_filename,
                    "file_type": "UNKNOWN",
                },
            )

        if parse_result.file_kind != ImportFileKind.PORTFOLIO_SNAPSHOT:
            wrong_type_error = self._problem(
                title="Wrong Import Endpoint for Trade Ledger",
                detail=(
                    "This is a Trade History file, not a Portfolio Holdings file. "
                    "Use the trade import endpoint."
                ),
                instance="/api/v1/import/snapshot/preview/file_type",
                row_number=None,
                row_payload={
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                },
                status=422,
                problem_type="wrong_file_type",
            )
            all_errors = [*parse_errors, wrong_type_error]
            safe_errors = [self._sanitize_json_value(item) for item in all_errors]
            return ImportTradesReport(
                job=None,
                inserted_count=0,
                duplicates_skipped_count=0,
                failed_count=len(safe_errors),
                errors=[ImportRowError.model_validate(item) for item in safe_errors],
                inserted_reference_hashes=[],
                analysis={
                    "mode": "snapshot_preview",
                    "source_filename": source_filename,
                    "file_type": parse_result.file_kind.value,
                    "broker_format": parse_result.broker_format.value,
                    "total_rows": parse_result.total_rows,
                    "parsed_rows": len(parse_result.parsed_rows),
                },
            )

        safe_errors = [self._sanitize_json_value(item) for item in parse_errors]
        return ImportTradesReport(
            job=None,
            inserted_count=0,
            duplicates_skipped_count=0,
            failed_count=len(safe_errors),
            errors=[ImportRowError.model_validate(item) for item in safe_errors],
            inserted_reference_hashes=[],
            analysis={
                "mode": "snapshot_preview",
                "source_filename": source_filename,
                "file_type": parse_result.file_kind.value,
                "broker_format": parse_result.broker_format.value,
                "total_rows": parse_result.total_rows,
                "parsed_positions": len(parse_result.parsed_positions),
                "valid_positions": max(len(parse_result.parsed_positions) - len(parse_errors), 0),
            },
        )

    async def _assert_portfolio_owner(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> None:
        result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        logger.info(f"Checking portfolio ownership: portfolio_id={portfolio_id}, user_id={user_id}")

        if result.scalar_one_or_none() is None:
            raise PortfolioOwnershipError("Portfolio not found for this user.")

    def _safe_parse(
        self,
        *,
        file_bytes: bytes,
        instance_base: str,
        source_filename: str,
    ) -> tuple[ParseWorkbookResult | None, list[dict[str, Any]]]:
        try:
            parse_result = parse_excel_transactions(file_bytes, instance_base=instance_base)
            return parse_result, parse_result.errors
        except ExcelFormatDetectionError as ex:
            logger.warning(
                "Excel format detection failed",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )
            return None, [
                self._problem(
                    title="Unsupported Broker Format",
                    detail=str(ex),
                    instance=f"{instance_base}/format",
                    row_number=None,
                    row_payload=None,
                    status=422,
                    problem_type="format_unsupported",
                )
            ]
        except pd.errors.EmptyDataError:
            logger.warning(
                "Excel parse failed because worksheet is empty",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                },
            )
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail="Uploaded file has no readable worksheet rows.",
                    instance=f"{instance_base}/worksheet",
                    row_number=None,
                    row_payload=None,
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        except pd.errors.ParserError as ex:
            trace_line = self._extract_exception_line(ex)
            logger.warning(
                "Pandas parser error while reading Excel workbook",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "trace_line": trace_line,
                    "exception_message": str(ex),
                },
            )
            line_hint = f" at parser line {trace_line}" if trace_line is not None else ""
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail=f"Pandas parser error{line_hint}: {ex}",
                    instance=f"{instance_base}/parse",
                    row_number=None,
                    row_payload={"source_filename": source_filename},
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        except UnicodeDecodeError as ex:
            logger.warning(
                "Encoding error while decoding workbook",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "encoding": ex.encoding,
                    "failed_start": ex.start,
                    "failed_end": ex.end,
                },
            )
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail=(
                        "Workbook encoding is invalid. "
                        f"Failed to decode bytes {ex.start}:{ex.end} using {ex.encoding}."
                    ),
                    instance=f"{instance_base}/parse",
                    row_number=None,
                    row_payload={"source_filename": source_filename},
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        except KeyError as ex:
            missing_column = str(ex).strip("'\"")
            logger.warning(
                "Workbook is missing required column",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "missing_column": missing_column,
                },
            )
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail=f"Required column '{missing_column}' is missing from worksheet headers.",
                    instance=f"{instance_base}/columns/{missing_column}",
                    row_number=None,
                    row_payload={"missing_column": missing_column},
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        except ValueError as ex:
            trace_line = self._extract_exception_line(ex)
            logger.warning(
                "Workbook value parsing failed",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "trace_line": trace_line,
                    "exception_message": str(ex),
                },
            )
            detail = str(ex).strip() or "Workbook contains invalid values."
            if trace_line is not None:
                detail = f"{detail} (line {trace_line})"
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail=detail,
                    instance=f"{instance_base}/values",
                    row_number=None,
                    row_payload={"source_filename": source_filename},
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        except Exception as ex:
            trace_line = self._extract_exception_line(ex)
            logger.exception(
                "Unexpected workbook parse failure",
                extra={
                    "source_filename": source_filename,
                    "instance_base": instance_base,
                    "trace_line": trace_line,
                    "exception_type": type(ex).__name__,
                },
            )
            line_hint = f" (line {trace_line})" if trace_line is not None else ""
            return None, [
                self._problem(
                    title="Parse Failure",
                    detail=(
                        "Failed to parse workbook due to an unexpected parser error"
                        f"{line_hint}. Verify headers and worksheet data, then retry."
                    ),
                    instance=f"{instance_base}/parse",
                    row_number=None,
                    row_payload=None,
                    status=422,
                    problem_type="parse_failure",
                )
            ]
        
    async def _ingest_parsed_rows(
        self,
        *,
        job_id: uuid.UUID,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        parse_result: ParseWorkbookResult,
        parse_errors: list[dict[str, Any]],
        source_filename: str,
    ) -> dict[str, Any]:
        candidate_rows: list[ParsedBrokerTransaction] = []
        errors: list[dict[str, Any]] = [*parse_errors]
        financial_validation_failed = False

        for row in parse_result.parsed_rows:
            validation_error = self._validate_financial_row(
                row=row,
                instance_base=f"/api/v1/import/jobs/{job_id}",
            )
            if validation_error:
                errors.append(validation_error)
                financial_validation_failed = True
                continue
            candidate_rows.append(row)

        if financial_validation_failed:
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": 0,
                "errors": errors,
                "inserted_reference_hashes": [],
            }

        if not candidate_rows:
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": 0,
                "errors": errors,
                "inserted_reference_hashes": [],
            }

        existing_assets, assets_created_count = await self._ensure_assets(candidate_rows)
        existing_hashes = await self._fetch_existing_hashes(
            user_id=user_id,
            rows=candidate_rows,
        )
        seen_hashes_in_file: set[str] = set()
        seen_trade_signatures_in_file: set[tuple[str, str, str, str, str]] = set()
        insert_candidates: list[dict[str, Any]] = []
        candidate_rows_by_hash: dict[str, ParsedBrokerTransaction] = {}
        inserted_reference_hashes: list[str] = []
        duplicate_count = 0

        for row in candidate_rows:
            asset = existing_assets.get(row.symbol)
            if asset is None:
                errors.append(
                    self._problem(
                        title="Asset Resolution Failed",
                        detail=f"Could not resolve asset for symbol '{row.symbol}'.",
                        instance=f"/api/v1/import/jobs/{job_id}/rows/{row.row_number}",
                        row_number=row.row_number,
                        row_payload={"symbol": row.symbol, "description": row.description},
                        status=422,
                    )
                )
                continue

            reference_hash = build_reference_hash(
                user_id=user_id,
                symbol=row.symbol,
                executed_at=row.executed_at,
                quantity=row.quantity,
                transaction_type=row.transaction_type,
            )
            if reference_hash in existing_hashes:
                duplicate_count += 1
                errors.append(
                    self._problem(
                        title="Duplicate Transaction",
                        detail=(
                            "Transaction already exists in ledger and was skipped "
                            f"(symbol={row.symbol}, row={row.row_number})."
                        ),
                        instance=f"/api/v1/import/jobs/{job_id}/rows/{row.row_number}",
                        row_number=row.row_number,
                        row_payload={
                            "symbol": row.symbol,
                            "executed_at": row.executed_at.isoformat(),
                            "quantity": str(row.quantity),
                            "reference_hash": reference_hash,
                        },
                        status=409,
                        problem_type="integrity_error",
                    )
                )
                continue
            if reference_hash in seen_hashes_in_file:
                duplicate_count += 1
                errors.append(
                    self._problem(
                        title="Duplicate Transaction",
                        detail=(
                            "Duplicate transaction detected within the uploaded file and skipped "
                            f"(symbol={row.symbol}, row={row.row_number})."
                        ),
                        instance=f"/api/v1/import/jobs/{job_id}/rows/{row.row_number}",
                        row_number=row.row_number,
                        row_payload={
                            "symbol": row.symbol,
                            "executed_at": row.executed_at.isoformat(),
                            "quantity": str(row.quantity),
                            "reference_hash": reference_hash,
                        },
                        status=409,
                        problem_type="integrity_error",
                    )
                )
                continue
            seen_hashes_in_file.add(reference_hash)

            insert_candidates.append(
                {
                    "row": row,
                    "asset": asset,
                    "reference_hash": reference_hash,
                }
            )
            candidate_rows_by_hash[reference_hash] = row
            inserted_reference_hashes.append(reference_hash)

        if not insert_candidates:
            status = ImportJobStatus.FAILED if errors else ImportJobStatus.COMPLETED
            await self._update_job_status(
                job_id=job_id,
                status=status,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=duplicate_count,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": duplicate_count,
                "errors": errors,
                "inserted_reference_hashes": [],
            }

        existing_trade_signatures = await self._fetch_existing_trade_signatures(
            portfolio_id=portfolio_id,
            insert_candidates=insert_candidates,
        )
        filtered_insert_candidates: list[dict[str, Any]] = []
        filtered_hashes: list[str] = []
        for candidate in insert_candidates:
            row = candidate["row"]
            asset = candidate["asset"]
            signature = self._trade_signature(asset_id=asset.id, row=row)
            if signature in existing_trade_signatures:
                duplicate_count += 1
                errors.append(
                    self._problem(
                        title="Duplicate Transaction",
                        detail=(
                            "Transaction already exists with the same portfolio/asset/side/date/quantity/price "
                            f"(symbol={row.symbol}, row={row.row_number})."
                        ),
                        instance=f"/api/v1/import/jobs/{job_id}/rows/{row.row_number}",
                        row_number=row.row_number,
                        row_payload={
                            "symbol": row.symbol,
                            "executed_at": row.executed_at.isoformat(),
                            "quantity": str(row.quantity),
                            "unit_price": str(row.unit_price),
                        },
                        status=409,
                        problem_type="integrity_error",
                    )
                )
                continue
            if signature in seen_trade_signatures_in_file:
                duplicate_count += 1
                errors.append(
                    self._problem(
                        title="Duplicate Transaction",
                        detail=(
                            "Duplicate transaction detected in file for portfolio/asset/side/date/quantity/price "
                            f"(symbol={row.symbol}, row={row.row_number})."
                        ),
                        instance=f"/api/v1/import/jobs/{job_id}/rows/{row.row_number}",
                        row_number=row.row_number,
                        row_payload={
                            "symbol": row.symbol,
                            "executed_at": row.executed_at.isoformat(),
                            "quantity": str(row.quantity),
                            "unit_price": str(row.unit_price),
                        },
                        status=409,
                        problem_type="integrity_error",
                    )
                )
                continue
            seen_trade_signatures_in_file.add(signature)
            filtered_insert_candidates.append(candidate)
            filtered_hashes.append(candidate["reference_hash"])

        insert_candidates = filtered_insert_candidates
        inserted_reference_hashes = filtered_hashes
        if not insert_candidates:
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED if errors else ImportJobStatus.COMPLETED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=duplicate_count,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": duplicate_count,
                "errors": errors,
                "inserted_reference_hashes": [],
            }

        await self._update_job_status(
            job_id=job_id,
            status=ImportJobStatus.PROCESSING,
            broker_format=parse_result.broker_format.value,
            total_rows=parse_result.total_rows,
            parsed_rows=len(parse_result.parsed_rows),
            inserted_rows=0,
            duplicates_skipped=duplicate_count,
            failed_rows=len(errors),
            errors=errors,
            completed_at=None,
        )

        mappings, accounting_errors, memberships_created_count = await self._prepare_accounting_mappings(
            portfolio_id=portfolio_id,
            job_id=job_id,
            insert_candidates=insert_candidates,
            source_filename=source_filename,
        )
        if accounting_errors:
            errors.extend(accounting_errors)
            await self.db.rollback()
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_rows),
                inserted_rows=0,
                duplicates_skipped=duplicate_count,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": duplicate_count,
                "errors": errors,
                "inserted_reference_hashes": [],
            }

        # Two-transaction unit-of-work:
        # 1) Try all-or-nothing ledger insert in nested transaction.
        # 2) Always persist import job result (including failures).
        ledger_failed = False
        insert_count = 0
        reconciliation_suggestions_created = 0
        try:
            await self.db.execute(select(ImportJob).where(ImportJob.id == job_id).with_for_update())
            await self.db.run_sync(self._bulk_insert_transactions, mappings)
            await self.db.commit()
            insert_count = len(mappings)
        except IntegrityError as ex:
            await self.db.rollback()
            ledger_failed = True
            logger.warning(
                "Ledger insert integrity failure during import",
                extra={
                    "job_id": str(job_id),
                    "candidate_rows": len(mappings),
                    "exception_message": str(ex.orig),
                },
            )
            conflicting_hashes = await self._find_conflicting_reference_hashes(
                {mapping["reference_hash"] for mapping in mappings}
            )
            if conflicting_hashes:
                for conflict_hash in sorted(conflicting_hashes):
                    conflict_row = candidate_rows_by_hash.get(conflict_hash)
                    if conflict_row is None:
                        continue
                    errors.append(
                        self._problem(
                            title="Duplicate Transaction",
                            detail=(
                                "Transaction collided with an existing ledger record during insert "
                                f"(symbol={conflict_row.symbol}, row={conflict_row.row_number})."
                            ),
                            instance=f"/api/v1/import/jobs/{job_id}/rows/{conflict_row.row_number}",
                            row_number=conflict_row.row_number,
                            row_payload={
                                "symbol": conflict_row.symbol,
                                "executed_at": conflict_row.executed_at.isoformat(),
                                "quantity": str(conflict_row.quantity),
                                "reference_hash": conflict_hash,
                            },
                            status=409,
                            problem_type="integrity_error",
                        )
                    )
            errors.append(
                self._problem(
                    title="Ledger Insert Integrity Failure",
                    detail=(
                        "One or more transactions violate database integrity constraints "
                        "(likely duplicate ledger rows)."
                    ),
                    instance=f"/api/v1/import/jobs/{job_id}/ledger",
                    row_number=None,
                    row_payload={
                        "candidate_rows": len(mappings),
                        "duplicate_reference_hashes": sorted(conflicting_hashes),
                    },
                    status=422,
                    problem_type="integrity_error",
                )
            )
            insert_count = 0
            inserted_reference_hashes = []
        except Exception as ex:
            await self.db.rollback()
            ledger_failed = True
            logger.exception(
                "Unexpected ledger insert failure during import",
                extra={
                    "job_id": str(job_id),
                    "candidate_rows": len(mappings),
                    "exception_type": type(ex).__name__,
                },
            )
            errors.append(
                self._problem(
                    title="Ledger Insert Failure",
                    detail=f"Bulk insert failed and was rolled back: {ex}",
                    instance=f"/api/v1/import/jobs/{job_id}/ledger",
                    row_number=None,
                    row_payload={"candidate_rows": len(mappings)},
                    status=500,
                    problem_type="integrity_error",
                )
            )
            insert_count = 0
            inserted_reference_hashes = []

        if not ledger_failed:
            try:
                reconciliation_suggestions_created = await self._generate_reconciliation_suggestions(
                    user_id=user_id,
                    reference_hashes=inserted_reference_hashes,
                )
            except Exception as ex:  # noqa: BLE001 - detection must not roll back imported ledger
                await self.db.rollback()
                logger.exception(
                    "Post-import reconciliation detection failed",
                    extra={"job_id": str(job_id), "exception_type": type(ex).__name__},
                )

        final_status = ImportJobStatus.FAILED if ledger_failed else ImportJobStatus.COMPLETED
        diagnostics = {
            "detected_format": parse_result.broker_format.value,
            "import_mode": "TRADES",
            "rows_total": parse_result.total_rows,
            "rows_parsed": len(parse_result.parsed_rows),
            "rows_imported": insert_count,
            "rows_skipped": max(parse_result.total_rows - len(parse_result.parsed_rows), 0) + duplicate_count,
            "assets_created": assets_created_count,
            "assets_linked": len({item["asset"].id for item in insert_candidates}),
            "portfolio_memberships_created": memberships_created_count,
            "trades_created": insert_count,
            "holdings_created": 0,
            "warnings": duplicate_count,
            "errors": len(errors),
            "reconciliation_suggestions_created": reconciliation_suggestions_created,
        }
        await self._update_job_status(
            job_id=job_id,
            status=final_status,
            broker_format=parse_result.broker_format.value,
            total_rows=parse_result.total_rows,
            parsed_rows=len(parse_result.parsed_rows),
            inserted_rows=insert_count,
            duplicates_skipped=duplicate_count,
            failed_rows=len(errors),
            errors=errors,
            completed_at=datetime.now(UTC),
            diagnostics=diagnostics,
        )

        return {
            "inserted_count": insert_count,
            "duplicates_skipped_count": duplicate_count,
            "errors": errors,
            "inserted_reference_hashes": inserted_reference_hashes,
            "diagnostics": diagnostics,
        }

    async def _ingest_snapshot_positions(
        self,
        *,
        job_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        parse_result: ParseWorkbookResult,
        parse_errors: list[dict[str, Any]],
    ) -> dict[str, Any]:
        errors: list[dict[str, Any]] = [*parse_errors]
        positions = parse_result.parsed_positions
        snapshot_date = datetime.now(UTC).date()

        if not positions:
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=0,
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": 0,
                "errors": errors,
            }

        symbols = {item.symbol for item in positions if item.symbol}
        assets, assets_created_count = await self._ensure_assets_by_symbols(symbols)
        asset_ids = {asset.id for asset in assets.values()}
        membership_service = PortfolioMembershipService(self.db)
        by_asset_id, memberships_created_count = await membership_service.ensure_bulk_membership_with_status(
            portfolio_id=portfolio_id,
            asset_ids=asset_ids,
        )
        existing_snapshots_result = await self.db.execute(
            select(HoldingSnapshot).where(
                HoldingSnapshot.portfolio_id == portfolio_id,
                HoldingSnapshot.asset_id.in_(asset_ids),
                HoldingSnapshot.snapshot_date == snapshot_date,
            ).with_for_update()
        )
        snapshots_by_asset_id = {
            item.asset_id: item for item in existing_snapshots_result.scalars().all()
        }

        applied_count = 0
        for parsed in positions:
            asset = assets.get(parsed.symbol)
            if asset is None:
                errors.append(
                    self._problem(
                        title="Asset Resolution Failed",
                        detail=f"Could not resolve asset for symbol '{parsed.symbol}'.",
                        instance=f"/api/v1/import/snapshot/jobs/{job_id}/rows/{parsed.row_number}",
                        row_number=parsed.row_number,
                        row_payload={"symbol": parsed.symbol},
                        status=422,
                    )
                )
                continue

            position = by_asset_id[asset.id]

            position.total_quantity = q8(parsed.quantity)
            position.weighted_avg_cost = q8(parsed.unit_cost)
            position.total_cost_basis = q8(parsed.total_cost_basis)
            position.last_updated = datetime.now(UTC).replace(tzinfo=None)

            snapshot = snapshots_by_asset_id.get(asset.id)
            if snapshot is None:
                snapshot = HoldingSnapshot(
                    portfolio_id=portfolio_id,
                    asset_id=asset.id,
                    snapshot_date=snapshot_date,
                    quantity=ZERO,
                    average_cost=ZERO,
                    cost_basis=ZERO,
                    market_price=None,
                    market_value=None,
                    unrealized_pnl=None,
                    weight_pct=None,
                    source_metadata=None,
                )
                self.db.add(snapshot)
                snapshots_by_asset_id[asset.id] = snapshot

            snapshot.quantity = q8(parsed.quantity)
            snapshot.average_cost = q8(parsed.unit_cost)
            snapshot.cost_basis = q8(parsed.total_cost_basis)
            snapshot.source_metadata = {
                "import_job_id": str(job_id),
                "broker_format": parse_result.broker_format.value,
                "row_number": parsed.row_number,
            }
            applied_count += 1

        if applied_count == 0:
            await self.db.rollback()
            await self._update_job_status(
                job_id=job_id,
                status=ImportJobStatus.FAILED,
                broker_format=parse_result.broker_format.value,
                total_rows=parse_result.total_rows,
                parsed_rows=len(parse_result.parsed_positions),
                inserted_rows=0,
                duplicates_skipped=0,
                failed_rows=len(errors),
                errors=errors,
                completed_at=datetime.now(UTC),
            )
            return {
                "inserted_count": 0,
                "duplicates_skipped_count": 0,
                "errors": errors,
            }

        await self.db.commit()
        final_status = ImportJobStatus.COMPLETED if not errors else ImportJobStatus.COMPLETED
        diagnostics = {
            "detected_format": parse_result.broker_format.value,
            "import_mode": "SNAPSHOT",
            "rows_total": parse_result.total_rows,
            "rows_parsed": len(parse_result.parsed_positions),
            "rows_imported": applied_count,
            "rows_skipped": max(parse_result.total_rows - len(parse_result.parsed_positions), 0),
            "assets_created": assets_created_count,
            "assets_linked": len(asset_ids),
            "portfolio_memberships_created": memberships_created_count,
            "trades_created": 0,
            "holdings_created": applied_count,
            "warnings": 0,
            "errors": len(errors),
        }
        await self._update_job_status(
            job_id=job_id,
            status=final_status,
            broker_format=parse_result.broker_format.value,
            total_rows=parse_result.total_rows,
            parsed_rows=len(parse_result.parsed_positions),
            inserted_rows=applied_count,
            duplicates_skipped=0,
            failed_rows=len(errors),
            errors=errors,
            completed_at=datetime.now(UTC),
            diagnostics=diagnostics,
        )
        return {
            "inserted_count": applied_count,
            "duplicates_skipped_count": 0,
            "errors": errors,
            "diagnostics": diagnostics,
        }

    async def _prepare_accounting_mappings(
        self,
        *,
        portfolio_id: uuid.UUID,
        job_id: uuid.UUID,
        insert_candidates: list[dict[str, Any]],
        source_filename: str,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], int]:
        ordered_candidates = sorted(
            insert_candidates,
            key=lambda item: (item["row"].executed_at, item["row"].row_number),
        )
        asset_ids = {item["asset"].id for item in ordered_candidates}
        membership_service = PortfolioMembershipService(self.db)
        positions, memberships_created_count = await membership_service.ensure_bulk_membership_with_status(
            portfolio_id=portfolio_id,
            asset_ids=asset_ids,
        )

        mappings: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        for item in ordered_candidates:
            row: ParsedBrokerTransaction = item["row"]
            asset: Asset = item["asset"]
            reference_hash: str = item["reference_hash"]
            position = positions[asset.id]

            old_qty = q8(position.total_quantity)
            old_wac = q8(position.weighted_avg_cost)
            realized_pnl = ZERO
            requires_reconciliation = False

            if row.transaction_type == TransactionType.BUY:
                new_qty = q8(old_qty + row.quantity)
                if new_qty > ZERO:
                    numerator = q8(old_qty * old_wac) + q8(row.total_amount)
                    new_wac = q8(numerator / new_qty)
                else:
                    new_wac = ZERO
                position.total_quantity = new_qty
                position.weighted_avg_cost = new_wac
            else:
                if row.quantity > old_qty:
                    requires_reconciliation = True
                else:
                    revenue = q8((row.quantity * row.unit_price) - row.fees)
                    cost_of_sold = q8(row.quantity * old_wac)
                    realized_pnl = q8(revenue - cost_of_sold)

                    new_qty = q8(old_qty - row.quantity)
                    new_wac = ZERO if new_qty == ZERO else old_wac
                    position.total_quantity = new_qty
                    position.weighted_avg_cost = new_wac
                    position.cumulative_realized_pnl = q8(position.cumulative_realized_pnl + realized_pnl)

            if not requires_reconciliation:
                position.total_cost_basis = q8(position.total_quantity * position.weighted_avg_cost)
                position.trade_count += 1
                position.last_updated = datetime.now(UTC).replace(tzinfo=None)

            mappings.append(
                {
                    "portfolio_id": portfolio_id,
                    "asset_id": asset.id,
                    "transaction_type": row.transaction_type,
                    "quantity": q8(row.quantity),
                    "price_per_unit": q8(row.unit_price),
                    "fees": q8(row.fees),
                    "total_amount": q8(row.total_amount),
                    "currency": "IRR",
                    "realized_pnl": q8(realized_pnl),
                    "wac_at_execution": q8(old_wac),
                    "reference_hash": reference_hash,
                    "idempotency_key": f"import:{job_id}:{row.row_number}:{reference_hash[:16]}",
                    "executed_at": row.executed_at,
                    "notes": row.description,
                    "source_metadata": {
                        "import_job_id": str(job_id),
                        "source_file": source_filename,
                        "source_broker": row.broker_format.value,
                        "source_row_number": row.row_number,
                        "row_number": row.row_number,
                        "broker_format": row.broker_format.value,
                        "raw_description": row.description,
                        "requires_reconciliation": requires_reconciliation,
                    },
                    "external_ref": None,
                }
            )

        if errors:
            return [], errors, memberships_created_count
        return mappings, [], memberships_created_count

    @staticmethod
    def _bulk_insert_transactions(sync_session: Session, mappings: list[dict[str, Any]]) -> None:
        sync_session.bulk_insert_mappings(Transaction, mappings)

    async def _generate_reconciliation_suggestions(
        self,
        *,
        user_id: uuid.UUID,
        reference_hashes: list[str],
    ) -> int:
        if not reference_hashes:
            return 0
        result = await self.db.execute(
            select(Transaction.id).where(
                Transaction.reference_hash.in_(reference_hashes),
                Transaction.transaction_type == TransactionType.SELL,
            )
        )
        sell_ids = list(result.scalars().all())
        if not sell_ids:
            return 0
        suggestions = await TradeReconciliationService(self.db).detect_candidates_for_transactions(
            user_id=user_id,
            transaction_ids=sell_ids,
        )
        return len(suggestions)

    async def _ensure_assets(self, rows: list[ParsedBrokerTransaction]) -> tuple[dict[str, Asset], int]:
        symbols = {row.symbol for row in rows if row.symbol}
        return await self._ensure_assets_by_symbols(symbols)

    async def _ensure_assets_by_symbols(self, symbols: set[str]) -> tuple[dict[str, Asset], int]:
        sorted_symbols = sorted(symbols)
        if not sorted_symbols:
            return {}, 0
        resolver = AssetResolverService(self.db)
        by_symbol: dict[str, Asset] = {}
        created_count = 0
        for symbol in sorted_symbols:
            match = await resolver.resolve_symbol(
                symbol_raw=symbol,
                symbol_normalized=symbol,
                market="TSETMC",
                display_name=symbol,
            )
            by_symbol[symbol] = match.asset
            if match.created:
                created_count += 1
        return by_symbol, created_count

    async def _fetch_existing_hashes(
        self,
        *,
        user_id: uuid.UUID,
        rows: list[ParsedBrokerTransaction],
    ) -> set[str]:
        candidate_hashes = {
            build_reference_hash(
                user_id=user_id,
                symbol=row.symbol,
                executed_at=row.executed_at,
                quantity=row.quantity,
                transaction_type=row.transaction_type,
            )
            for row in rows
        }
        if not candidate_hashes:
            return set()

        result = await self.db.execute(
            select(Transaction.reference_hash).where(Transaction.reference_hash.in_(candidate_hashes))
        )
        return {value for value in result.scalars().all()}

    @staticmethod
    def _trade_signature(
        *,
        asset_id: uuid.UUID,
        row: ParsedBrokerTransaction,
    ) -> tuple[str, str, str, str, str]:
        return (
            str(asset_id),
            row.transaction_type.value,
            row.executed_at.date().isoformat(),
            str(q8(row.quantity)),
            str(q8(row.unit_price)),
        )

    async def _fetch_existing_trade_signatures(
        self,
        *,
        portfolio_id: uuid.UUID,
        insert_candidates: list[dict[str, Any]],
    ) -> set[tuple[str, str, str, str, str]]:
        if not insert_candidates:
            return set()

        asset_ids = {item["asset"].id for item in insert_candidates}
        if not asset_ids:
            return set()

        result = await self.db.execute(
            select(
                Transaction.asset_id,
                Transaction.transaction_type,
                func.date(Transaction.executed_at),
                Transaction.quantity,
                Transaction.price_per_unit,
            ).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.asset_id.in_(asset_ids),
            )
        )

        signatures: set[tuple[str, str, str, str, str]] = set()
        for asset_id, transaction_type, executed_date, quantity, price_per_unit in result.all():
            signatures.add(
                (
                    str(asset_id),
                    transaction_type.value,
                    str(executed_date),
                    str(q8(quantity)),
                    str(q8(price_per_unit)),
                )
            )
        return signatures

    async def _find_conflicting_reference_hashes(self, candidate_hashes: set[str]) -> set[str]:
        if not candidate_hashes:
            return set()
        result = await self.db.execute(
            select(Transaction.reference_hash).where(Transaction.reference_hash.in_(candidate_hashes))
        )
        return {value for value in result.scalars().all()}

    def _validate_financial_row(
        self,
        *,
        row: ParsedBrokerTransaction,
        instance_base: str,
    ) -> dict[str, Any] | None:
        if row.quantity <= ZERO:
            return self._problem(
                title="Financial Validation Failed",
                detail="Quantity must be positive.",
                instance=f"{instance_base}/rows/{row.row_number}",
                row_number=row.row_number,
                row_payload={"quantity": str(row.quantity), "symbol": row.symbol},
                status=422,
            )
        if row.unit_price <= ZERO:
            return self._problem(
                title="Financial Validation Failed",
                detail="Unit price must be positive.",
                instance=f"{instance_base}/rows/{row.row_number}",
                row_number=row.row_number,
                row_payload={"unit_price": str(row.unit_price), "symbol": row.symbol},
                status=422,
            )
        if row.total_amount <= ZERO:
            return self._problem(
                title="Financial Validation Failed",
                detail="Total amount must be positive.",
                instance=f"{instance_base}/rows/{row.row_number}",
                row_number=row.row_number,
                row_payload={"total_amount": str(row.total_amount), "symbol": row.symbol},
                status=422,
            )
        expected = row.quantity * row.unit_price
        if row.transaction_type == TransactionType.BUY:
            expected += row.fees
        else:
            expected -= row.fees
        variance = abs(expected - row.total_amount)
        tolerance = Decimal("1.00000000")
        if variance > tolerance:
            return self._problem(
                title="Financial Validation Failed",
                detail="Amount mismatch exceeds tolerance after fee reconciliation.",
                instance=f"{instance_base}/rows/{row.row_number}",
                row_number=row.row_number,
                row_payload={
                    "expected_total": str(expected),
                    "row_total": str(row.total_amount),
                    "symbol": row.symbol,
                },
                status=422,
            )
        return None

    async def _update_job_status(
        self,
        *,
        job_id: uuid.UUID,
        status: ImportJobStatus,
        broker_format: str | None,
        total_rows: int,
        parsed_rows: int,
        inserted_rows: int,
        duplicates_skipped: int,
        failed_rows: int,
        errors: list[dict[str, Any]],
        completed_at: datetime | None,
        diagnostics: dict[str, Any] | None = None,
    ) -> None:
        result = await self.db.execute(select(ImportJob).where(ImportJob.id == job_id))
        job = result.scalar_one()
        safe_errors = [self._sanitize_json_value(item) for item in errors]
        job.status = status
        job.broker_format = broker_format
        job.total_rows = total_rows
        job.parsed_rows = parsed_rows
        job.inserted_rows = inserted_rows
        job.duplicates_skipped = duplicates_skipped
        job.failed_rows = failed_rows
        job.error_details = safe_errors
        if diagnostics is not None:
            job.diagnostics = self._sanitize_json_value(diagnostics) if isinstance(diagnostics, dict) else {}
        if completed_at is not None:
            job.completed_at = completed_at
        await self.db.commit()

    async def _build_report(
        self,
        *,
        job_id: uuid.UUID,
        errors: list[dict[str, Any]],
        inserted_reference_hashes: list[str],
        analysis: dict[str, Decimal | int | str],
    ) -> ImportTradesReport:
        result = await self.db.execute(select(ImportJob).where(ImportJob.id == job_id))
        job = result.scalar_one()
        safe_errors = [self._sanitize_json_value(item) for item in errors]
        safe_analysis = {
            key: self._sanitize_json_value(value) for key, value in analysis.items()
        }
        return ImportTradesReport(
            job=ImportJobRead.model_validate(job),
            inserted_count=job.inserted_rows,
            duplicates_skipped_count=job.duplicates_skipped,
            failed_count=job.failed_rows,
            errors=[ImportRowError.model_validate(item) for item in safe_errors],
            inserted_reference_hashes=inserted_reference_hashes,
            analysis=safe_analysis,
        )

    async def _compute_post_import_analysis(
        self,
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> dict[str, Decimal | int | str]:
        service = PnLCalculatorService(
            pnl_repo=PnLRepository(self.db),
            market_repo=MarketDataRepository(self.db),
        )
        summary = await service.calculate_realtime_summary(
            portfolio_id=portfolio_id,
            user_id=user_id,
        )
        analysis: dict[str, Decimal | int | str] = {
            "portfolio_id": str(portfolio_id),
            "total_current_value": summary.total_current_value,
            "total_invested": summary.total_invested,
            "total_unrealized_pnl": summary.total_unrealized_pnl,
            "total_realized_pnl": summary.total_realized_pnl,
            "roi_percent": summary.roi_percent,
            "active_assets": len(summary.assets),
        }
        portfolio_ids_result = await self.db.execute(
            select(Portfolio.id).where(
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        portfolio_ids = list(portfolio_ids_result.scalars().all())
        aggregate_current_value = Decimal("0")
        aggregate_invested = Decimal("0")
        aggregate_unrealized = Decimal("0")
        aggregate_realized = Decimal("0")
        for pid in portfolio_ids:
            item = await service.calculate_realtime_summary(
                portfolio_id=pid,
                user_id=user_id,
            )
            aggregate_current_value += item.total_current_value
            aggregate_invested += item.total_invested
            aggregate_unrealized += item.total_unrealized_pnl
            aggregate_realized += item.total_realized_pnl

        aggregate_total_pnl = aggregate_unrealized + aggregate_realized
        aggregate_roi = Decimal("0")
        if aggregate_invested > Decimal("0"):
            aggregate_roi = (aggregate_total_pnl / aggregate_invested) * Decimal("100")
        analysis.update(
            {
                "aggregate_portfolios": len(portfolio_ids),
                "aggregate_total_current_value": aggregate_current_value,
                "aggregate_total_invested": aggregate_invested,
                "aggregate_total_unrealized_pnl": aggregate_unrealized,
                "aggregate_total_realized_pnl": aggregate_realized,
                "aggregate_roi_percent": aggregate_roi,
            }
        )
        return analysis

    @staticmethod
    async def _run_async_analysis_refresh(
        *,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        job_id: uuid.UUID | None = None,
    ) -> None:
        try:
            async with async_session_factory() as db:
                service = PnLCalculatorService(
                    pnl_repo=PnLRepository(db),
                    market_repo=MarketDataRepository(db),
                )
                await service.calculate_realtime_summary(portfolio_id=portfolio_id, user_id=user_id)
                await db.close()
        except Exception as ex:  # noqa: BLE001
            logger.warning(
                "Async post-import analysis refresh failed",
                extra={
                    "portfolio_id": str(portfolio_id),
                    "user_id": str(user_id),
                    "job_id": str(job_id) if job_id is not None else None,
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )
            if job_id is not None:
                await ImportService._append_async_refresh_warning(
                    job_id=job_id,
                    portfolio_id=portfolio_id,
                    user_id=user_id,
                    reason=str(ex),
                )

    @staticmethod
    async def _append_async_refresh_warning(
        *,
        job_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        user_id: uuid.UUID,
        reason: str,
    ) -> None:
        try:
            async with async_session_factory() as db:
                result = await db.execute(select(ImportJob).where(ImportJob.id == job_id))
                job = result.scalar_one_or_none()
                if job is None:
                    return
                details = list(job.error_details or [])
                details.append(
                    {
                        "type": "async_refresh_warning",
                        "title": "Post-Import Analysis Refresh Failed",
                        "status": 200,
                        "detail": (
                            "Import succeeded, but asynchronous analysis refresh failed. "
                            "You can safely retry portfolio refresh."
                        ),
                        "instance": f"/api/v1/import/jobs/{job_id}/analysis-refresh",
                        "row_number": None,
                        "row_payload": {
                            "portfolio_id": str(portfolio_id),
                            "user_id": str(user_id),
                            "reason": reason,
                        },
                    }
                )
                job.error_details = details
                await db.commit()
        except Exception as ex:  # noqa: BLE001
            logger.warning(
                "Failed to persist async refresh warning",
                extra={
                    "job_id": str(job_id),
                    "exception_type": type(ex).__name__,
                    "exception_message": str(ex),
                },
            )

    @staticmethod
    def _problem(
        *,
        title: str,
        detail: str,
        instance: str,
        row_number: int | None,
        row_payload: dict[str, Any] | None,
        status: int,
        problem_type: str = "validation_error",
    ) -> dict[str, Any]:
        safe_payload = ImportService._sanitize_json_value(row_payload)
        return {
            "type": problem_type,
            "problem_type": problem_type,
            "title": title,
            "status": status,
            "detail": detail,
            "instance": instance,
            "row_number": row_number,
            "row_payload": safe_payload if isinstance(safe_payload, dict) else {"value": safe_payload},
        }

    @staticmethod
    def _sanitize_json_value(value: Any) -> Any:
        if value is None:
            return None
        if isinstance(value, dict):
            return {str(key): ImportService._sanitize_json_value(item) for key, item in value.items()}
        if isinstance(value, (list, tuple, set)):
            return [ImportService._sanitize_json_value(item) for item in value]
        if isinstance(value, Decimal):
            if value.is_finite():
                return str(value)
            return "0"
        if isinstance(value, float):
            if not math.isfinite(value):
                return "0"
            return value
        return value

    @staticmethod
    def _extract_exception_line(exception: Exception) -> int | None:
        tb = exception.__traceback__
        if tb is None:
            return None
        frames = traceback.extract_tb(tb)
        if not frames:
            return None
        return frames[-1].lineno
