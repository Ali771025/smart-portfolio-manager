"""Asynchronous Excel import flow with broker-specific parser modules."""

from __future__ import annotations

import hashlib
import io
import logging
import os
import re
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

import pandas as pd
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.core.database import async_session_factory
from app.models.asset import Asset
from app.models.cash_transaction import PortfolioCashTransaction
from app.models.enums import ImportJobStatus, TransactionType
from app.models.import_job import ImportJob
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.models.uploaded_file import UploadedFile
from app.services.asset_resolver_service import AssetResolverService
from app.services.file_storage_service import FileStorageService, FileValidationError
from app.services.import_parsers import (
    BrokerType,
    ImportParseError,
    NormalizedImportTransaction,
    NormalizedTransactionType,
    build_parser_for_broker,
    detect_broker_format,
)
from app.services.ledger_hashing import q8
from app.services.portfolio_state_recompute_service import PortfolioStateRecomputeService
from app.services.portfolio_membership_service import PortfolioMembershipService

logger = logging.getLogger(__name__)

UPLOAD_STORAGE_ROOT = os.getenv("UPLOAD_STORAGE_ROOT", "/tmp/portfolio_uploads")
MAX_IMPORT_ROWS = 10_000
ZERO = Decimal("0.00000000")
ALLOW_ASSET_AUTO_CREATE = os.getenv("IMPORT_AUTO_CREATE_ASSETS", "true").strip().lower() not in {"0", "false", "no"}
DEFAULT_STRICT_SELL_VALIDATION = os.getenv("IMPORT_STRICT_SELL_VALIDATION", "true").strip().lower() not in {
    "0",
    "false",
    "no",
}
DEFAULT_ALLOW_SHORT_SELLING = os.getenv("IMPORT_ALLOW_SHORT_SELLING", "false").strip().lower() in {
    "1",
    "true",
    "yes",
}

ASSET_EVENT_TYPES = {
    NormalizedTransactionType.BUY,
    NormalizedTransactionType.SELL,
    NormalizedTransactionType.BONUS,
    NormalizedTransactionType.SPLIT,
}
CASH_EVENT_TYPES = {
    NormalizedTransactionType.DIVIDEND,
    NormalizedTransactionType.DEPOSIT,
    NormalizedTransactionType.WITHDRAWAL,
    NormalizedTransactionType.FEE,
    NormalizedTransactionType.TAX,
    NormalizedTransactionType.OPENING_CASH_BALANCE,
}
SKIPPABLE_TYPES = {NormalizedTransactionType.IGNORE}


class PortfolioOwnershipError(LookupError):
    """Raised when user tries to import into a portfolio they do not own."""


class ExcelImportService:
    """Orchestrates async Excel upload jobs and normalized transaction persistence."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.file_storage = FileStorageService(storage_root=UPLOAD_STORAGE_ROOT)

    async def create_import_job(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        file_bytes: bytes,
        source_filename: str,
    ) -> ImportJob:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)
        try:
            uploaded_file = await self.file_storage.store_file(
                db=self.db,
                user_id=user_id,
                original_filename=source_filename,
                file_bytes=file_bytes,
            )
        except FileValidationError as exc:
            raise ValueError(str(exc)) from exc

        job = ImportJob(
            user_id=user_id,
            portfolio_id=portfolio_id,
            source_filename=source_filename,
            status=ImportJobStatus.PENDING,
            started_at=datetime.now(UTC),
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
            error_details=[],
            diagnostics={},
        )
        self.db.add(job)
        await self.db.flush()
        uploaded_file.import_job_id = job.id
        self.db.add(uploaded_file)
        await self.db.commit()
        await self.db.refresh(job)
        return job

    async def get_job(self, *, job_id: uuid.UUID, user_id: uuid.UUID) -> ImportJob:
        result = await self.db.execute(
            select(ImportJob).where(
                ImportJob.id == job_id,
                ImportJob.user_id == user_id,
            )
        )
        job = result.scalar_one_or_none()
        if job is None:
            raise PortfolioOwnershipError("Import job not found.")
        return job

    async def get_job_errors(self, *, job_id: uuid.UUID, user_id: uuid.UUID) -> list[dict[str, Any]]:
        job = await self.get_job(job_id=job_id, user_id=user_id)
        errors = []
        row_results = job.diagnostics.get("row_results", []) if isinstance(job.diagnostics, dict) else []
        if isinstance(row_results, list):
            for item in row_results:
                if isinstance(item, dict) and item.get("status") == "error":
                    errors.append(
                        {
                            "row_number": item.get("row_number"),
                            "raw_text": item.get("raw_description", ""),
                            "error_reason": item.get("message", "Unknown import error"),
                            "type": item.get("type"),
                            "symbol": item.get("symbol"),
                            "asset_id": item.get("asset_id"),
                            "quantity": item.get("quantity"),
                            "price": item.get("unit_price", item.get("price")),
                            "amount": item.get("amount"),
                            "normalized_description": item.get("normalized_description"),
                            "suggestion": item.get("suggestion"),
                        }
                    )
        if errors:
            return errors
        for item in job.error_details or []:
            errors.append(
                {
                    "row_number": item.get("row_number"),
                    "raw_text": item.get("raw_text", ""),
                    "error_reason": item.get("error_reason", "Unknown parse error"),
                }
            )
        return errors

    @staticmethod
    async def process_job_background(job_id: uuid.UUID) -> None:
        async with async_session_factory() as db:
            service = ExcelImportService(db)
            await service.process_job(job_id=job_id)

    async def process_job(self, *, job_id: uuid.UUID) -> None:
        job_result = await self.db.execute(select(ImportJob).where(ImportJob.id == job_id))
        job = job_result.scalar_one_or_none()
        if job is None:
            logger.warning("Excel import background task could not find job %s", job_id)
            return
        logger.info(
            "excel_import_processing_started",
            extra={
                "job_id": str(job.id),
                "portfolio_id": str(job.portfolio_id),
                "user_id": str(job.user_id),
                "source_filename": job.source_filename,
            },
        )

        uploaded_file_result = await self.db.execute(
            select(UploadedFile).where(UploadedFile.import_job_id == job_id)
        )
        uploaded_file = uploaded_file_result.scalar_one_or_none()
        if uploaded_file is None:
            await self._mark_failed(
                job=job,
                errors=[self._error(0, "", "Uploaded file metadata is missing.")],
                broker=None,
                total_rows=0,
                parsed_rows=0,
                inserted_rows=0,
                diagnostics={},
            )
            return

        job.status = ImportJobStatus.PROCESSING
        await self.db.commit()

        try:
            content = self.file_storage.read_file(uploaded_file)
            dataframe = pd.read_excel(io.BytesIO(content), dtype=object)
            if dataframe.empty:
                raise ValueError("Excel file is empty.")
            if len(dataframe.index) > MAX_IMPORT_ROWS:
                raise ValueError(f"Excel file exceeds {MAX_IMPORT_ROWS} rows.")
        except Exception:  # noqa: BLE001
            logger.exception("Failed to read Excel import job %s", job.id)
            await self._mark_failed(
                job=job,
                errors=[self._error(0, "", "فایل اکسل قابل خواندن نیست یا ساختار معتبری ندارد.")],
                broker=None,
                total_rows=0,
                parsed_rows=0,
                inserted_rows=0,
                diagnostics={},
            )
            return

        rows = self._dataframe_to_rows(dataframe)
        total_rows = len(rows)

        try:
            broker = detect_broker_format(dataframe.columns)
            parser = build_parser_for_broker(broker)
            normalized_rows, parse_errors = parser.parse(rows=rows, source_file=job.source_filename)
        except Exception:  # noqa: BLE001
            logger.exception("Failed to detect or parse broker import job %s", job.id)
            await self._mark_failed(
                job=job,
                errors=[self._error(0, "", "ساختار فایل کارگزاری شناسایی یا پردازش نشد.")],
                broker=None,
                total_rows=total_rows,
                parsed_rows=0,
                inserted_rows=0,
                diagnostics={},
            )
            return

        persistence: dict[str, Any] | None = None
        try:
            persistence = await self._persist_rows(
                job=job,
                broker=broker,
                rows=normalized_rows,
                parse_errors=parse_errors,
                source_file_hash=uploaded_file.content_hash,
                strict_sell_validation=DEFAULT_STRICT_SELL_VALIDATION,
                allow_short_selling=DEFAULT_ALLOW_SHORT_SELLING,
            )
            recompute_result = await PortfolioStateRecomputeService(self.db).recompute_portfolio_state(
                portfolio_id=job.portfolio_id,
                rebuild_positions=True,
            )
            diagnostics = persistence.get("diagnostics")
            if isinstance(diagnostics, dict):
                diagnostics["post_import_recompute"] = {
                    "portfolio_id": str(recompute_result.portfolio_id),
                    "positions_rebuilt": recompute_result.positions_rebuilt,
                    "transactions_repriced": recompute_result.transactions_repriced,
                    "snapshot_date": recompute_result.snapshot_date.isoformat(),
                    "recomputed_at": recompute_result.completed_at.isoformat(),
                    "analytics_updated_at": recompute_result.completed_at.isoformat(),
                    "dashboard_updated_at": recompute_result.completed_at.isoformat(),
                    "status": "completed",
                }
        except Exception:  # noqa: BLE001
            logger.exception("Post-import recomputation failed for job %s", job.id)
            await self._mark_failed(
                job=job,
                errors=[
                    self._error(
                        0,
                        "",
                        "تراکنش‌ها ثبت شدند، اما به‌روزرسانی مانده پرتفوی کامل نشد.",
                    )
                ],
                broker=broker,
                total_rows=total_rows,
                parsed_rows=len(normalized_rows),
                inserted_rows=int((persistence or {}).get("inserted_rows", 0)),
                diagnostics={},
            )
            return
        await self._finalize_job(
            job=job,
            broker=broker,
            total_rows=total_rows,
            parsed_rows=len(normalized_rows),
            inserted_rows=persistence["inserted_rows"],
            duplicates=persistence["duplicates"],
            errors=persistence["errors"],
            diagnostics=persistence["diagnostics"],
        )
        logger.info(
            "excel_import_processing_completed",
            extra={
                "job_id": str(job.id),
                "portfolio_id": str(job.portfolio_id),
                "status": job.status.value,
                "inserted_rows": job.inserted_rows,
                "failed_rows": job.failed_rows,
                "completed_at": job.completed_at.isoformat() if job.completed_at is not None else None,
            },
        )

    async def _persist_rows(
        self,
        *,
        job: ImportJob,
        broker: BrokerType,
        rows: list[NormalizedImportTransaction],
        parse_errors: list[ImportParseError],
        source_file_hash: str | None,
        strict_sell_validation: bool,
        allow_short_selling: bool,
    ) -> dict[str, Any]:
        errors: list[dict[str, Any]] = [self._error(err.row_number, err.raw_text, err.error_reason) for err in parse_errors]
        row_results: list[dict[str, Any]] = []
        resolver = AssetResolverService(self.db)

        detected_by_type: dict[str, int] = {txn_type.value: 0 for txn_type in NormalizedTransactionType}
        for row in rows:
            detected_by_type[row.transaction_type.value] = detected_by_type.get(row.transaction_type.value, 0) + 1

        trade_mappings: list[dict[str, Any]] = []
        cash_mappings: list[dict[str, Any]] = []
        inserted_reference_hashes: list[str] = []
        duplicates = 0
        inserted_trade_count = 0
        inserted_cash_count = 0
        skipped_rows = 0
        warning_rows = 0
        error_rows = len(parse_errors)
        unresolved_symbols = 0
        created_symbols = 0

        # row-level duplicate prevention, then DB-level unique constraints.
        seen_idempotency_keys: set[str] = set()

        for err in parse_errors:
            row_results.append(
                {
                    "row_number": err.row_number,
                    "status": "error",
                    "message_code": "ROW_PARSE_ERROR",
                    "normalized_type": NormalizedTransactionType.UNKNOWN.value,
                    "type": NormalizedTransactionType.UNKNOWN.value,
                    "symbol": None,
                    "asset_id": None,
                    "quantity": None,
                    "unit_price": None,
                    "amount": None,
                    "debit": None,
                    "credit": None,
                    "symbol_resolution": "not_applicable",
                    "raw_description": err.raw_text,
                    "normalized_description": err.raw_text,
                    "message": err.error_reason,
                    "suggestion": "Fix row format or extend parser rules.",
                }
            )

        ordered = sorted(rows, key=lambda item: (item.date, item.row_number))

        # Position replay starts from existing persisted holdings, not only the file rows.
        symbols_for_asset_events = {
            row.symbol for row in ordered if row.transaction_type in ASSET_EVENT_TYPES and row.symbol
        }
        symbol_to_asset: dict[str, Asset] = {}
        symbol_resolution_diag: dict[str, dict[str, Any]] = {}

        for symbol in sorted(symbols_for_asset_events):
            broker_symbols = sorted(
                {
                    str((row.diagnostics or {}).get("broker_symbol") or symbol)
                    for row in ordered
                    if row.symbol == symbol
                }
            )
            try:
                resolved = await resolver.resolve_symbol(
                    symbol_raw=symbol,
                    symbol_normalized=symbol,
                    market="TSETMC",
                    display_name=symbol,
                    allow_create=ALLOW_ASSET_AUTO_CREATE,
                )
                symbol_to_asset[symbol] = resolved.asset
                if resolved.created:
                    created_symbols += 1
                    resolution_status = "created"
                else:
                    resolution_status = "resolved"
                symbol_resolution_diag[symbol] = {
                    "status": resolution_status,
                    "broker_symbol": broker_symbols[0] if broker_symbols else symbol,
                    "normalized_symbol": symbol,
                    "asset_id": str(resolved.asset.id),
                }
            except LookupError:
                unresolved_symbols += 1
                symbol_resolution_diag[symbol] = {
                    "status": "unresolved",
                    "broker_symbol": broker_symbols[0] if broker_symbols else symbol,
                    "normalized_symbol": symbol,
                    "asset_id": None,
                }

        membership_service = PortfolioMembershipService(self.db)
        asset_ids = {asset.id for asset in symbol_to_asset.values()}
        positions, _created = await membership_service.ensure_bulk_membership_with_status(
            portfolio_id=job.portfolio_id,
            asset_ids=asset_ids,
        )

        initial_available_by_symbol = {
            symbol: q8(positions[asset.id].total_quantity)
            for symbol, asset in symbol_to_asset.items()
            if asset.id in positions
        }

        candidate_trade_keys = {
            self._build_idempotency_key(
                portfolio_id=job.portfolio_id,
                broker=broker.value,
                row=row,
            )
            for row in ordered
            if row.transaction_type in ASSET_EVENT_TYPES
        }
        candidate_cash_keys = {
            self._build_idempotency_key(
                portfolio_id=job.portfolio_id,
                broker=broker.value,
                row=row,
            )
            for row in ordered
            if row.transaction_type in CASH_EVENT_TYPES
        }
        existing_trade_keys = set()
        existing_cash_keys = set()
        if candidate_trade_keys:
            existing_trade_result = await self.db.execute(
                select(Transaction.idempotency_key).where(
                    Transaction.portfolio_id == job.portfolio_id,
                    Transaction.idempotency_key.in_(candidate_trade_keys),
                )
            )
            existing_trade_keys = set(existing_trade_result.scalars().all())
        if candidate_cash_keys:
            existing_cash_result = await self.db.execute(
                select(PortfolioCashTransaction.idempotency_key).where(
                    PortfolioCashTransaction.portfolio_id == job.portfolio_id,
                    PortfolioCashTransaction.idempotency_key.in_(candidate_cash_keys),
                )
            )
            existing_cash_keys = set(existing_cash_result.scalars().all())

        failed_sell_symbols: dict[str, int] = {}
        buy_symbols_in_file = {row.symbol for row in ordered if row.transaction_type == NormalizedTransactionType.BUY and row.symbol}
        opening_balance_rows = [row for row in ordered if "مانده نقل از قبل" in row.normalized_description]

        for row in ordered:
            row_type = row.transaction_type
            symbol = row.symbol or ""
            idempotency_key = self._build_idempotency_key(
                portfolio_id=job.portfolio_id,
                broker=broker.value,
                row=row,
            )
            row_hash = self._build_row_hash(
                portfolio_id=job.portfolio_id,
                broker=broker.value,
                row=row,
            )
            duplicate_in_file = idempotency_key in seen_idempotency_keys
            if not duplicate_in_file:
                seen_idempotency_keys.add(idempotency_key)

            base_result = {
                "row_number": row.row_number,
                "normalized_type": row_type.value,
                "type": row_type.value,
                "symbol": symbol or None,
                "asset_id": None,
                "quantity": self._maybe_num(row.quantity),
                "unit_price": self._maybe_num(row.price_per_unit),
                "amount": self._maybe_num(row.total_amount),
                "gross_amount": (row.diagnostics or {}).get("extracted_gross_amount"),
                "net_amount": self._maybe_num(row.net_amount),
                "cash_effect": (row.diagnostics or {}).get("cash_effect"),
                "fee_or_adjustment": (row.diagnostics or {}).get("inferred_fee_or_adjustment"),
                "inferred_fee": self._maybe_num(row.fees),
                "raw_description": row.raw_text,
                "normalized_description": row.normalized_description or row.raw_text,
                "confidence_source": row.confidence_source,
                "parse_source": row.confidence_source,
                "debit": (row.diagnostics or {}).get("debit"),
                "credit": (row.diagnostics or {}).get("credit"),
                "debit_amount": (row.diagnostics or {}).get("debit_amount", (row.diagnostics or {}).get("debit")),
                "credit_amount": (row.diagnostics or {}).get("credit_amount", (row.diagnostics or {}).get("credit")),
                "balance_after": (row.diagnostics or {}).get("balance_after"),
                "extracted_quantity": (row.diagnostics or {}).get("extracted_quantity"),
                "extracted_symbol": (row.diagnostics or {}).get("extracted_symbol"),
                "extracted_unit_price": (row.diagnostics or {}).get("extracted_unit_price"),
                "extracted_gross_amount": (row.diagnostics or {}).get("extracted_gross_amount"),
                "symbol_resolution": symbol_resolution_diag.get(symbol, {}).get("status", "not_applicable"),
                "status": "warning",
                "message_code": "ROW_WARNING",
                "message": row.warning or "",
                "suggestion": None,
            }

            if row_type == NormalizedTransactionType.UNKNOWN:
                error_rows += 1
                row_results.append(
                    {
                        **base_result,
                        "status": "error",
                        "message_code": "UNKNOWN_TRANSACTION_TYPE",
                        "message": row.warning or "نوع تراکنش از روی ردیف قابل تشخیص نیست.",
                        "suggestion": "نوع ردیف را بررسی کنید یا قانون parser برای این الگو اضافه شود.",
                        "diagnostics": row.diagnostics or {},
                    }
                )
                continue

            if row_type in SKIPPABLE_TYPES:
                skipped_rows += 1
                if row.warning:
                    warning_rows += 1
                row_results.append(
                    {
                        **base_result,
                        "status": "skipped",
                        "message_code": "IGNORED_BY_CLASSIFIER",
                        "message": row.warning or "این ردیف توسط parser قابل چشم‌پوشی تشخیص داده شد.",
                    }
                )
                continue

            if row_type in ASSET_EVENT_TYPES:
                asset = symbol_to_asset.get(symbol)
                if asset is None:
                    error_rows += 1
                    symbol_diag = symbol_resolution_diag.get(
                        symbol,
                        {
                            "status": "unresolved",
                            "broker_symbol": (row.diagnostics or {}).get("broker_symbol") or symbol,
                            "normalized_symbol": symbol,
                            "asset_id": None,
                        },
                    )
                    row_results.append(
                        {
                            **base_result,
                            "status": "error",
                            "message_code": "SYMBOL_UNRESOLVED",
                            "message": "نماد این ردیف در جدول دارایی‌ها پیدا نشد.",
                            "suggestion": "نماد کارگزاری را به یک دارایی موجود متصل کنید یا ایجاد خودکار نماد را فعال کنید.",
                            "diagnostics": {"symbol_resolution": symbol_diag},
                        }
                    )
                    continue
                base_result["asset_id"] = str(asset.id)

                if duplicate_in_file or idempotency_key in existing_trade_keys:
                    duplicates += 1
                    skipped_rows += 1
                    row_results.append(
                        {
                            **base_result,
                            "status": "skipped",
                            "message_code": "DUPLICATE_ROW",
                            "message": "این ردیف قبلاً وارد شده و دوباره ذخیره نشد.",
                        }
                    )
                    continue

                position = positions[asset.id]
                old_qty = q8(position.total_quantity)
                old_wac = q8(position.weighted_avg_cost)
                quantity = q8(row.quantity)
                total_amount = q8(row.total_amount)
                unit_price = q8(row.price_per_unit)
                realized = ZERO
                txn_type = TransactionType.BUY

                if row_type == NormalizedTransactionType.BUY:
                    txn_type = TransactionType.BUY
                    if quantity <= ZERO:
                        error_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "error",
                                "message_code": "INVALID_BUY_QUANTITY",
                                "message": "برای ردیف خرید، تعداد باید مثبت باشد.",
                            }
                        )
                        continue
                    if unit_price <= ZERO:
                        error_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "error",
                                "message_code": "INVALID_BUY_UNIT_PRICE",
                                "message": "برای ردیف خرید، قیمت واحد باید مثبت باشد.",
                                "suggestion": "قیمت واحد را در شرح معامله یا ستون قیمت وارد کنید.",
                                "diagnostics": row.diagnostics or {},
                            }
                        )
                        continue
                    new_qty = q8(old_qty + quantity)
                    buy_cost_basis = total_amount if total_amount > ZERO else q8(quantity * unit_price)
                    new_wac = q8(((old_qty * old_wac) + buy_cost_basis) / new_qty) if new_qty > ZERO else ZERO
                    position.total_quantity = new_qty
                    position.weighted_avg_cost = new_wac
                elif row_type == NormalizedTransactionType.SELL:
                    txn_type = TransactionType.SELL
                    if quantity <= ZERO:
                        error_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "error",
                                "message_code": "INVALID_SELL_QUANTITY",
                                "message": "برای ردیف فروش، تعداد باید مثبت باشد.",
                            }
                        )
                        continue
                    if unit_price <= ZERO:
                        error_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "error",
                                "message_code": "INVALID_SELL_UNIT_PRICE",
                                "message": "برای ردیف فروش، قیمت واحد باید مثبت باشد.",
                                "suggestion": "قیمت واحد را در شرح معامله یا ستون قیمت وارد کنید.",
                                "diagnostics": row.diagnostics or {},
                            }
                        )
                        continue
                    is_sell_valid, sell_error = self.validate_sell_quantity(
                        available=old_qty,
                        requested=quantity,
                        strict=strict_sell_validation,
                        allow_short_selling=allow_short_selling,
                    )
                    if not is_sell_valid:
                        failed_sell_symbols[symbol] = failed_sell_symbols.get(symbol, 0) + 1
                        error_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "error",
                                "message_code": "SELL_QUANTITY_EXCEEDS_AVAILABLE",
                                "message": sell_error,
                                "suggestion": "خریدهای قبلی را import کنید یا موجودی اولیه سهم را تعریف کنید.",
                            }
                        )
                        continue
                    revenue = q8(quantity * unit_price)
                    cost = q8(quantity * old_wac)
                    realized = q8(revenue - cost)
                    new_qty = q8(old_qty - quantity)
                    position.total_quantity = new_qty
                    position.weighted_avg_cost = ZERO if new_qty == ZERO else old_wac
                    position.cumulative_realized_pnl = q8(position.cumulative_realized_pnl + realized)
                elif row_type == NormalizedTransactionType.BONUS:
                    txn_type = TransactionType.CAPITAL_INCREASE_BONUS
                    if quantity <= ZERO:
                        warning_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "warning",
                                "message_code": "BONUS_QUANTITY_MISSING",
                                "message": "BONUS row missing quantity; skipped.",
                                "suggestion": "Provide bonus quantity for this corporate action row.",
                            }
                        )
                        continue
                    new_qty = q8(old_qty + quantity)
                    # Bonus shares usually preserve cost basis amount and dilute average cost.
                    existing_cost_basis = q8(old_qty * old_wac)
                    new_wac = q8(existing_cost_basis / new_qty) if new_qty > ZERO else ZERO
                    position.total_quantity = new_qty
                    position.weighted_avg_cost = new_wac
                    total_amount = ZERO
                    unit_price = ZERO
                else:  # SPLIT
                    txn_type = TransactionType.STOCK_SPLIT
                    split_from = ZERO
                    split_to = ZERO
                    if isinstance(row.diagnostics, dict):
                        raw_from = row.diagnostics.get("split_from", ZERO)
                        raw_to = row.diagnostics.get("split_to", ZERO)
                        try:
                            split_from = q8(Decimal(str(raw_from or ZERO)))
                            split_to = q8(Decimal(str(raw_to or ZERO)))
                        except Exception:  # noqa: BLE001
                            split_from = ZERO
                            split_to = ZERO
                    if split_from <= ZERO or split_to <= ZERO:
                        warning_rows += 1
                        row_results.append(
                            {
                                **base_result,
                                "status": "warning",
                                "message_code": "SPLIT_RATIO_MISSING",
                                "message": "SPLIT row missing ratio; skipped.",
                                "suggestion": "Provide split ratio in row description (e.g. 1 به 2).",
                            }
                        )
                        continue
                    new_qty = q8((old_qty * split_to) / split_from) if old_qty > ZERO else ZERO
                    existing_cost_basis = q8(old_qty * old_wac)
                    new_wac = q8(existing_cost_basis / new_qty) if new_qty > ZERO else ZERO
                    position.total_quantity = new_qty
                    position.weighted_avg_cost = new_wac
                    total_amount = ZERO
                    unit_price = ZERO

                position.total_cost_basis = q8(position.total_quantity * position.weighted_avg_cost)
                position.trade_count += 1
                position.last_updated = datetime.now(UTC).replace(tzinfo=None)

                trade_mappings.append(
                    {
                        "portfolio_id": job.portfolio_id,
                        "asset_id": asset.id,
                        "transaction_type": txn_type,
                        "quantity": quantity,
                        "price_per_unit": unit_price,
                        "fees": q8(row.fees if row.fees > ZERO else ZERO),
                        "total_amount": total_amount,
                        "currency": "IRR",
                        "realized_pnl": q8(realized),
                        "wac_at_execution": q8(old_wac),
                        "reference_hash": row_hash,
                        "idempotency_key": idempotency_key,
                        "import_batch_id": job.id,
                        "source_broker": broker.value,
                        "source_file_hash": source_file_hash,
                        "source_row_number": row.row_number,
                        "raw_type": (row.diagnostics or {}).get("raw_type"),
                        "normalized_type": row_type.value,
                        "net_amount": q8(row.net_amount if row.net_amount != ZERO else total_amount),
                        "fee_or_adjustment": self._diag_decimal(row, "inferred_fee_or_adjustment"),
                        "cash_effect": self._diag_decimal(row, "cash_effect"),
                        "debit_amount": self._diag_decimal(row, "debit_amount", "debit"),
                        "credit_amount": self._diag_decimal(row, "credit_amount", "credit"),
                        "balance_after": self._diag_decimal(row, "balance_after"),
                        "executed_at": row.date,
                        "notes": row.raw_text,
                        "source_metadata": {
                            "import_batch_id": str(job.id),
                            "source_file": row.source_file,
                            "source_file_name": row.source_file,
                            "source_file_hash": source_file_hash,
                            "source_broker": broker.value,
                            "source_row_number": row.row_number,
                            "raw_type": (row.diagnostics or {}).get("raw_type"),
                            "normalized_type": row_type.value,
                            "side": txn_type.value,
                            "quantity": format(quantity, "f"),
                            "unit_price": format(unit_price, "f"),
                            "gross_amount": (row.diagnostics or {}).get("gross_amount")
                            or (row.diagnostics or {}).get("extracted_gross_amount"),
                            "net_amount": format(q8(row.net_amount if row.net_amount != ZERO else total_amount), "f"),
                            "fee_or_adjustment": (row.diagnostics or {}).get("inferred_fee_or_adjustment"),
                            "cash_effect": (row.diagnostics or {}).get("cash_effect"),
                            "debit_amount": (row.diagnostics or {}).get(
                                "debit_amount", (row.diagnostics or {}).get("debit")
                            ),
                            "credit_amount": (row.diagnostics or {}).get(
                                "credit_amount", (row.diagnostics or {}).get("credit")
                            ),
                            "balance_after": (row.diagnostics or {}).get("balance_after"),
                            "normalized_description": row.normalized_description or row.raw_text,
                            "raw_description": row.raw_text,
                            "row_hash": row_hash,
                            "fingerprint": row_hash,
                            "symbol_resolution": symbol_resolution_diag.get(symbol, {}).get("status", "resolved"),
                            "broker_symbol": (row.diagnostics or {}).get("broker_symbol"),
                            "normalized_symbol": symbol or None,
                        },
                        "external_ref": None,
                    }
                )
                inserted_reference_hashes.append(row_hash)
                inserted_trade_count += 1
                row_results.append(
                    {
                        **base_result,
                        "status": "inserted",
                        "message_code": "TRADE_INSERTED",
                        "message": "معامله در دفتر معاملات ثبت شد.",
                    }
                )
                continue

            if row_type in CASH_EVENT_TYPES:
                if duplicate_in_file or idempotency_key in existing_cash_keys:
                    duplicates += 1
                    skipped_rows += 1
                    row_results.append(
                        {
                            **base_result,
                            "status": "skipped",
                            "message_code": "DUPLICATE_ROW",
                            "message": "این گردش نقدی قبلاً وارد شده و دوباره ذخیره نشد.",
                        }
                    )
                    continue

                asset_id: uuid.UUID | None = None
                if symbol:
                    asset = symbol_to_asset.get(symbol)
                    if asset is not None:
                        asset_id = asset.id

                signed_amount = q8(row.total_amount)
                if row_type in {NormalizedTransactionType.WITHDRAWAL, NormalizedTransactionType.FEE, NormalizedTransactionType.TAX}:
                    signed_amount = q8(-abs(signed_amount))
                else:
                    signed_amount = q8(abs(signed_amount))

                cash_mappings.append(
                    {
                        "portfolio_id": job.portfolio_id,
                        "asset_id": asset_id,
                        "import_batch_id": job.id,
                        "source_broker": broker.value,
                        "source_row_number": row.row_number,
                        "raw_type": (row.diagnostics or {}).get("raw_type"),
                        "normalized_type": row_type.value,
                        "event_date": row.date.isoformat(),
                        "raw_description": row.raw_text,
                        "normalized_description": row.normalized_description or row.raw_text,
                        "amount": signed_amount,
                        "quantity": q8(row.quantity if row.quantity > ZERO else ZERO),
                        "price_per_unit": q8(row.price_per_unit if row.price_per_unit > ZERO else ZERO),
                        "gross_amount": q8(row.total_amount if row.total_amount > ZERO else ZERO),
                        "fees": q8(row.fees if row.fees > ZERO else ZERO),
                        "tax": q8(row.tax if row.tax > ZERO else ZERO),
                        "net_amount": q8(row.net_amount if row.net_amount != ZERO else signed_amount),
                        "fee_or_adjustment": self._diag_decimal(row, "inferred_fee_or_adjustment"),
                        "cash_effect": self._diag_decimal(row, "cash_effect") or signed_amount,
                        "debit_amount": self._diag_decimal(row, "debit_amount", "debit"),
                        "credit_amount": self._diag_decimal(row, "credit_amount", "credit"),
                        "balance_after": self._diag_decimal(row, "balance_after"),
                        "source_file_hash": source_file_hash,
                        "row_hash": row_hash,
                        "idempotency_key": idempotency_key,
                        "diagnostics": {
                            "import_batch_id": str(job.id),
                            "source_broker": broker.value,
                            "source_file_name": row.source_file,
                            "source_row_number": row.row_number,
                            "raw_type": (row.diagnostics or {}).get("raw_type"),
                            "normalized_type": row_type.value,
                            "cash_effect": (row.diagnostics or {}).get("cash_effect") or format(signed_amount, "f"),
                            "debit_amount": (row.diagnostics or {}).get(
                                "debit_amount", (row.diagnostics or {}).get("debit")
                            ),
                            "credit_amount": (row.diagnostics or {}).get(
                                "credit_amount", (row.diagnostics or {}).get("credit")
                            ),
                            "balance_after": (row.diagnostics or {}).get("balance_after"),
                            "confidence_source": row.confidence_source,
                            "warning": row.warning,
                            "symbol_resolution": symbol_resolution_diag.get(symbol, {}).get("status", "not_applicable"),
                            "broker_symbol": (row.diagnostics or {}).get("broker_symbol"),
                            "normalized_symbol": symbol or None,
                            "parsed_metadata": row.diagnostics or {},
                        },
                    }
                )
                inserted_cash_count += 1
                row_results.append(
                    {
                        **base_result,
                        "status": "inserted",
                        "message_code": "CASH_EVENT_INSERTED",
                        "asset_id": str(asset_id) if asset_id else None,
                        "message": "گردش نقدی در دفتر نقدی ثبت شد.",
                    }
                )
                continue

            warning_rows += 1
            row_results.append(
                {
                    **base_result,
                    "status": "warning",
                    "message_code": "UNHANDLED_NORMALIZED_TYPE",
                    "message": f"Detected {row_type.value} but no persistence handler is configured.",
                    "suggestion": "Add a persistence rule for this normalized type.",
                }
            )

        if trade_mappings:
            try:
                await self.db.run_sync(self._bulk_insert_transactions, trade_mappings)
            except IntegrityError:
                await self.db.rollback()
                logger.exception("Trade import integrity failure for job %s", job.id)
                errors.append(self._error(0, "", "ثبت تراکنش‌ها به دلیل داده تکراری یا ناسازگار انجام نشد."))
                error_rows += 1
                trade_mappings = []
        if cash_mappings:
            try:
                await self.db.run_sync(self._bulk_insert_cash_events, cash_mappings)
            except IntegrityError:
                await self.db.rollback()
                logger.exception("Cash import integrity failure for job %s", job.id)
                errors.append(self._error(0, "", "ثبت گردش نقدی به دلیل داده تکراری یا ناسازگار انجام نشد."))
                error_rows += 1
                cash_mappings = []

        await self.db.commit()

        if failed_sell_symbols and strict_sell_validation:
            zero_sell_failures = sum(failed_sell_symbols.values())
            had_existing_holdings_for_failed_sells = any(
                initial_available_by_symbol.get(symbol, ZERO) > ZERO for symbol in failed_sell_symbols
            )
            if (
                zero_sell_failures >= 1
                and not buy_symbols_in_file.intersection(failed_sell_symbols.keys())
                and not had_existing_holdings_for_failed_sells
            ):
                error_rows += 1
                row_results.append(
                    {
                        "row_number": None,
                        "status": "error",
                        "message_code": "PARTIAL_HISTORY_DETECTED",
                        "normalized_type": "UNKNOWN",
                        "type": "PARTIAL_HISTORY_HINT",
                        "symbol": None,
                        "asset_id": None,
                        "quantity": None,
                        "unit_price": None,
                        "amount": None,
                        "raw_description": "",
                        "normalized_description": "",
                        "message": "This file appears to be partial history. Import prior purchases or define opening positions.",
                        "suggestion": "Import prior purchases or define opening positions, then retry import.",
                    }
                )
            if opening_balance_rows:
                warning_rows += 1
                row_results.append(
                    {
                        "row_number": None,
                        "status": "warning",
                        "message_code": "OPENING_CASH_BALANCE_DETECTED",
                        "normalized_type": NormalizedTransactionType.OPENING_CASH_BALANCE.value,
                        "type": "OPENING_BALANCE_DETECTED",
                        "symbol": None,
                        "asset_id": None,
                        "quantity": None,
                        "unit_price": None,
                        "amount": None,
                        "raw_description": "",
                        "normalized_description": "",
                        "message": "Detected 'مانده نقل از قبل' row(s); treated as cash opening balance only.",
                        "suggestion": "Use opening positions import if you need initial asset quantities.",
                    }
                )

        diagnostics = {
            "import_batch_id": str(job.id),
            "broker": broker.value,
            "portfolio_id": str(job.portfolio_id),
            "source_file_name": job.source_filename,
            "file_hash": source_file_hash,
            "imported_at": datetime.now(UTC).isoformat(),
            "status": "completed_with_errors" if (error_rows > 0 or warning_rows > 0) else "completed",
            "summary": {
                "total_rows": len(rows),
                "inserted_trades": inserted_trade_count,
                "inserted_transactions": inserted_trade_count,
                "inserted_cash_events": inserted_cash_count,
                "inserted_rows": inserted_trade_count + inserted_cash_count,
                "imported_count": inserted_trade_count + inserted_cash_count,
                "imported": inserted_trade_count + inserted_cash_count,
                "duplicates_skipped": duplicates,
                "skipped_rows": skipped_rows,
                "skipped_count": skipped_rows,
                "skipped": skipped_rows,
                "warning_rows": warning_rows,
                "warning_count": warning_rows,
                "warnings": warning_rows,
                "error_rows": error_rows,
                "error_count": error_rows,
                "errors": error_rows,
                "duplicate_rows": duplicates,
            },
            "detected_by_type": detected_by_type,
            "symbol_resolution": {
                "resolved": len(
                    [x for x in symbol_resolution_diag.values() if x.get("status") == "resolved"]
                ),
                "created": created_symbols,
                "unresolved": unresolved_symbols,
                "ambiguous": 0,
                "aliases": symbol_resolution_diag,
            },
            "strict_validation": strict_sell_validation,
            "allow_short_selling": allow_short_selling,
            "row_results": row_results,
            "inserted_reference_hashes": inserted_reference_hashes,
        }

        return {
            "inserted_rows": inserted_trade_count + inserted_cash_count,
            "duplicates": duplicates,
            "errors": errors,
            "diagnostics": diagnostics,
        }

    async def _finalize_job(
        self,
        *,
        job: ImportJob,
        broker: BrokerType,
        total_rows: int,
        parsed_rows: int,
        inserted_rows: int,
        duplicates: int,
        errors: list[dict[str, Any]],
        diagnostics: dict[str, Any],
    ) -> None:
        summary = diagnostics.get("summary", {})
        job.status = ImportJobStatus.COMPLETED if inserted_rows > 0 or not errors else ImportJobStatus.FAILED
        job.completed_at = datetime.now(UTC)
        job.broker_format = broker.value
        job.total_rows = total_rows
        job.parsed_rows = parsed_rows
        job.inserted_rows = inserted_rows
        job.duplicates_skipped = duplicates
        job.failed_rows = int(summary.get("error_rows", len(errors)))
        job.error_details = errors
        job.diagnostics = diagnostics
        await self.db.commit()

    async def _mark_failed(
        self,
        *,
        job: ImportJob,
        errors: list[dict[str, Any]],
        broker: BrokerType | None,
        total_rows: int,
        parsed_rows: int,
        inserted_rows: int,
        diagnostics: dict[str, Any],
    ) -> None:
        job.status = ImportJobStatus.FAILED
        job.completed_at = datetime.now(UTC)
        job.broker_format = broker.value if broker is not None else None
        job.total_rows = total_rows
        job.parsed_rows = parsed_rows
        job.inserted_rows = inserted_rows
        job.failed_rows = len(errors)
        job.error_details = errors
        base_diag = {
            "import_batch_id": str(job.id),
            "broker": broker.value if broker is not None else None,
            "status": "failed",
            "summary": {
                "total_rows": total_rows,
                "inserted_trades": 0,
                "inserted_transactions": 0,
                "inserted_cash_events": 0,
                "inserted_rows": inserted_rows,
                "duplicates_skipped": 0,
                "skipped_rows": 0,
                "warning_rows": 0,
                "error_rows": len(errors),
                "duplicate_rows": 0,
            },
            "row_results": [],
        }
        base_diag.update(diagnostics)
        job.diagnostics = base_diag
        await self.db.commit()

    async def _assert_portfolio_owner(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> None:
        result = await self.db.execute(
            select(Portfolio).where(
                Portfolio.id == portfolio_id,
                Portfolio.user_id == user_id,
                Portfolio.is_active.is_(True),
            )
        )
        if result.scalar_one_or_none() is None:
            raise PortfolioOwnershipError("Portfolio not found for this user.")

    @staticmethod
    def _bulk_insert_transactions(sync_session: Session, mappings: list[dict[str, Any]]) -> None:
        sync_session.bulk_insert_mappings(Transaction, mappings)

    @staticmethod
    def _bulk_insert_cash_events(sync_session: Session, mappings: list[dict[str, Any]]) -> None:
        sync_session.bulk_insert_mappings(PortfolioCashTransaction, mappings)

    @staticmethod
    def _dataframe_to_rows(dataframe: pd.DataFrame) -> list[dict[str, Any]]:
        clean = dataframe.copy()
        clean.columns = [ExcelImportService._normalize_column_name(col) for col in clean.columns]
        clean = clean.astype(object).where(pd.notna(clean), None)
        records = clean.to_dict(orient="records")
        rows: list[dict[str, Any]] = []
        for index, item in enumerate(records, start=2):
            row = dict(item)
            row["__row_number__"] = index
            rows.append(row)
        return rows

    @staticmethod
    def _normalize_column_name(value: Any) -> str:
        text = str(value).strip().translate(str.maketrans({"ي": "ی", "ى": "ی", "ك": "ک"}))
        text = text.replace("\u200c", " ").replace("\u200f", " ").replace("\ufeff", " ")
        text = re.sub(r"\s+", " ", text)
        text = re.sub(r"\s*\(\s*", "(", text)
        text = re.sub(r"\s*\)\s*", ")", text)
        return text.strip()

    @staticmethod
    def _error(row_number: int, raw_text: str, reason: str) -> dict[str, Any]:
        return {
            "row_number": row_number,
            "raw_text": raw_text,
            "error_reason": reason,
        }

    @staticmethod
    def _decimal_str(value: Decimal) -> str:
        return format(q8(value), "f")

    @classmethod
    def _build_row_hash(
        cls,
        *,
        portfolio_id: uuid.UUID,
        broker: str,
        row: NormalizedImportTransaction,
    ) -> str:
        diagnostics = row.diagnostics or {}
        debit = diagnostics.get("debit", "0")
        credit = diagnostics.get("credit", "0")
        executed_at = row.date if row.date.tzinfo else row.date.replace(tzinfo=UTC)
        payload = "|".join(
            [
                str(portfolio_id),
                broker,
                row.transaction_type.value,
                executed_at.astimezone(UTC).isoformat(),
                (row.symbol or "").strip(),
                cls._decimal_str(row.quantity),
                cls._decimal_str(row.price_per_unit),
                cls._decimal_str(row.total_amount),
                cls._decimal_str(row.fees),
                cls._decimal_str(row.tax),
                str(debit).strip(),
                str(credit).strip(),
                (row.normalized_description or row.raw_text or str(row.row_number)).strip(),
            ]
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    @classmethod
    def _build_idempotency_key(
        cls,
        *,
        portfolio_id: uuid.UUID,
        broker: str,
        row: NormalizedImportTransaction,
    ) -> str:
        return f"excel:{cls._build_row_hash(portfolio_id=portfolio_id, broker=broker, row=row)}"

    @staticmethod
    def _maybe_num(value: Decimal) -> str | None:
        if value == ZERO:
            return None
        return format(q8(value), "f")

    @staticmethod
    def _diag_decimal(row: NormalizedImportTransaction, *keys: str) -> Decimal | None:
        diagnostics = row.diagnostics or {}
        for key in keys:
            value = diagnostics.get(key)
            if value in (None, ""):
                continue
            try:
                return q8(Decimal(str(value)))
            except Exception:  # noqa: BLE001
                continue
        return None

    @staticmethod
    def validate_sell_quantity(
        *,
        available: Decimal,
        requested: Decimal,
        strict: bool,
        allow_short_selling: bool = False,
    ) -> tuple[bool, str | None]:
        if requested <= available:
            return True, None
        if strict:
            req = format(q8(requested), "f")
            avail = format(q8(available), "f")
            return False, f"SELL quantity {req} exceeds available quantity {avail}."
        if allow_short_selling:
            return True, "SELL exceeds available quantity but is allowed because short selling is enabled."
        req = format(q8(requested), "f")
        avail = format(q8(available), "f")
        return False, f"SELL quantity {req} exceeds available quantity {avail}; short selling is disabled."
