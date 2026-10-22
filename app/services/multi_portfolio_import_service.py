"""Service layer for broker-aware multi-portfolio import preview and confirmation."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from io import BytesIO
import json
import logging
from typing import Any

import pandas as pd
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import get_redis
from app.models.asset import Asset
from app.models.asset_position import AssetPosition
from app.models.enums import ImportJobStatus, PortfolioManagerType, TransactionType
from app.models.holding_snapshot import HoldingSnapshot
from app.models.import_job import ImportJob
from app.models.manual_transaction import ManualTransaction
from app.models.market_data import PortfolioSnapshot
from app.models.portfolio import Portfolio
from app.models.transaction import Transaction
from app.schemas.multi_portfolio_import import (
    BrokerType,
    ImportPreviewResponse,
    ImportPreviewRow,
    ImportPreviewSummary,
    ImportResultResponse,
    ImportRowStatus,
    ImportType,
)
from app.services.file_storage_service import FileStorageService
from app.services.asset_resolver_service import AssetResolverService
from app.services.portfolio_membership_service import PortfolioMembershipService
from app.services.multi_portfolio_import_models import ParseContext, ParseOutput, ParsedRow, RowSemanticType
from app.services.multi_portfolio_import_parsers import ALL_PARSERS
from app.services.multi_portfolio_import_utils import normalize_header, sha256_hex
from app.services.portfolio_state_recompute_service import PortfolioStateRecomputeService
from app.services.trade_reconciliation_service import TradeReconciliationService

ZERO = Decimal("0")
logger = logging.getLogger(__name__)


@dataclass(slots=True)
class CachedPreview:
    portfolio_id: uuid.UUID
    source_filename: str
    source_hash: str
    generated_at: datetime
    parse_output: ParseOutput


class PortfolioOwnershipError(LookupError):
    """Raised when portfolio does not belong to current user."""


class PreviewNotFoundError(LookupError):
    """Raised when preview id is missing from in-memory cache."""


class UnsupportedBrokerTemplateError(ValueError):
    """Raised when headers do not match known broker templates."""


class ImportValidationError(ValueError):
    """Raised for import-time business validation failures."""


class MultiPortfolioImportService:
    _preview_cache: dict[uuid.UUID, CachedPreview] = {}
    _preview_ttl_seconds: int = 60 * 60

    def __init__(self, db: AsyncSession, *, storage_root: str = "/tmp/portfolio_uploads") -> None:
        self.db = db
        self.file_storage = FileStorageService(storage_root=storage_root)

    async def build_preview(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        file_bytes: bytes,
        source_filename: str,
    ) -> ImportPreviewResponse:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)
        self.file_storage.validate_excel_file(filename=source_filename, file_bytes=file_bytes)

        frame = pd.read_excel(BytesIO(file_bytes), dtype=object, keep_default_na=False)
        if frame.empty:
            raise ImportValidationError("فایل خالی است و قابل پردازش نیست.")

        original_headers = [str(column) for column in frame.columns.tolist()]
        normalized_headers = [normalize_header(header) for header in original_headers]
        header_mapping = {
            original: normalized
            for original, normalized in zip(original_headers, normalized_headers, strict=False)
        }
        frame = frame.rename(columns=header_mapping)

        parser = self._detect_parser(headers=normalized_headers)
        rows = frame.to_dict(orient="records")
        parse_output = parser.parse(
            rows,
            ParseContext(
                portfolio_id=portfolio_id,
                source_filename=source_filename,
                now_utc=datetime.now(UTC),
            ),
        )
        parse_output = await self._apply_duplicate_detection(
            portfolio_id=portfolio_id,
            parse_output=parse_output,
        )

        preview_id = uuid.uuid4()
        source_hash = sha256_hex(file_bytes.hex())
        cached = CachedPreview(
            portfolio_id=portfolio_id,
            source_filename=source_filename,
            source_hash=source_hash,
            generated_at=datetime.now(UTC),
            parse_output=parse_output,
        )
        await self._store_preview_cache(preview_id=preview_id, cached=cached)

        rows_payload = [
            ImportPreviewRow(
                row_no=row.row_no,
                status=row.status,
                raw=row.raw,
                normalized=row.normalized,
                messages=[*row.messages, f"semantic={row.semantic_type.value.lower()}"],
            )
            for row in parse_output.rows
        ]
        summary = self._build_summary(parse_output=parse_output)

        return ImportPreviewResponse(
            preview_id=preview_id,
            portfolio_id=portfolio_id,
            detected_broker=parse_output.broker,
            detected_import_type=parse_output.import_type,
            generated_at=cached.generated_at,
            summary=summary,
            rows=rows_payload,
        )

    async def confirm_import(
        self,
        *,
        user_id: uuid.UUID,
        preview_id: uuid.UUID,
    ) -> ImportResultResponse:
        cached = await self._load_preview_cache(preview_id)
        if cached is None:
            raise PreviewNotFoundError("Preview not found or expired.")

        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=cached.portfolio_id)
        invalid_rows = [row for row in cached.parse_output.rows if row.status == ImportRowStatus.INVALID]
        duplicate_rows = [row for row in cached.parse_output.rows if row.status == ImportRowStatus.DUPLICATE]
        valid_rows = [row for row in cached.parse_output.rows if row.status == ImportRowStatus.VALID]
        now_utc = datetime.now(UTC)
        resolved_assets = await self._resolve_assets_for_rows(rows=valid_rows)

        job = ImportJob(
            user_id=user_id,
            portfolio_id=cached.portfolio_id,
            source_filename=cached.source_filename,
            broker_format=cached.parse_output.broker.value,
            status=ImportJobStatus.PROCESSING,
            started_at=now_utc,
            created_at=now_utc,
            updated_at=now_utc,
            total_rows=len(cached.parse_output.rows),
            parsed_rows=len(valid_rows),
            inserted_rows=0,
            duplicates_skipped=len(duplicate_rows),
            failed_rows=len(invalid_rows),
            error_details=[
                {
                    "row_number": row.row_no,
                    "detail": "; ".join(row.messages) if row.messages else "Invalid row",
                    "status": 422,
                    "type": "validation_error",
                    "title": "Invalid Row",
                    "instance": f"/api/v1/imports/multi/jobs/{preview_id}",
                    "row_payload": row.raw,
                }
                for row in invalid_rows
            ],
        )
        self.db.add(job)
        await self.db.flush()

        imported_count = 0
        errors: list[str] = []
        imported_sell_ids: list[uuid.UUID] = []
        for row in valid_rows:
            try:
                async with self.db.begin_nested():
                    asset = self._resolve_asset_for_row(
                        normalized=row.normalized,
                        resolved_assets=resolved_assets,
                    )
                    if row.semantic_type == RowSemanticType.TRADE_ROW:
                        transaction = await self._persist_ledger_row(
                            portfolio_id=cached.portfolio_id,
                            asset=asset,
                            normalized=row.normalized,
                            fingerprint=row.duplicate_fingerprint or "",
                            source_filename=cached.source_filename,
                            source_broker=cached.parse_output.broker.value,
                            source_row_number=row.row_no,
                        )
                        if transaction.transaction_type == TransactionType.SELL:
                            imported_sell_ids.append(transaction.id)
                    elif row.semantic_type == RowSemanticType.HOLDING_SNAPSHOT_ROW:
                        await self._persist_snapshot_row(
                            portfolio_id=cached.portfolio_id,
                            asset=asset,
                            normalized=row.normalized,
                        )
                    else:
                        raise ValueError(f"Unsupported semantic row type: {row.semantic_type}")
                    await self.db.flush()
                imported_count += 1
            except Exception as ex:  # noqa: BLE001 - per-row error isolation
                errors.append(f"Row {row.row_no}: {ex}")

        job.status = ImportJobStatus.COMPLETED if not errors else ImportJobStatus.FAILED
        job.inserted_rows = imported_count
        job.failed_rows = len(invalid_rows) + len(errors)
        job.completed_at = datetime.now(UTC)
        if errors:
            job.error_details.extend(
                [
                    {
                        "row_number": None,
                        "detail": message,
                        "status": 500,
                        "type": "persist_error",
                        "title": "Persist Error",
                        "instance": f"/api/v1/imports/multi/jobs/{job.id}",
                    }
                    for message in errors
                ]
            )

        await self.db.commit()
        try:
            suggestions = await TradeReconciliationService(self.db).detect_candidates_for_transactions(
                user_id=user_id,
                transaction_ids=imported_sell_ids,
            )
            if suggestions:
                logger.info(
                    "multi_import_reconciliation_suggestions_created",
                    extra={
                        "job_id": str(job.id),
                        "count": len(suggestions),
                    },
                )
        except Exception as ex:  # noqa: BLE001 - detection must not invalidate imported ledger
            await self.db.rollback()
            logger.exception(
                "Multi-portfolio reconciliation detection failed",
                extra={"job_id": str(job.id), "exception_type": type(ex).__name__},
            )
        try:
            recompute_result = await PortfolioStateRecomputeService(self.db).recompute_portfolio_state(
                portfolio_id=cached.portfolio_id,
                rebuild_positions=True,
            )
            logger.info(
                "multi_import_recompute_completed",
                extra={
                    "job_id": str(job.id),
                    "portfolio_id": str(cached.portfolio_id),
                    "snapshot_date": recompute_result.snapshot_date.isoformat(),
                    "recomputed_at": recompute_result.completed_at.isoformat(),
                    "positions_rebuilt": recompute_result.positions_rebuilt,
                    "transactions_repriced": recompute_result.transactions_repriced,
                },
            )
        except Exception as ex:  # noqa: BLE001
            job.status = ImportJobStatus.FAILED
            job.error_details.append(
                {
                    "row_number": None,
                    "detail": f"Post-import recomputation failed: {ex}",
                    "status": 500,
                    "type": "recompute_error",
                    "title": "Post-Import Recompute Failed",
                    "instance": f"/api/v1/imports/multi/jobs/{job.id}",
                }
            )
            await self.db.commit()
            raise ImportValidationError(
                "Import persisted but portfolio state recomputation failed."
            ) from ex
        await self._delete_preview_cache(preview_id)

        return ImportResultResponse(
            job_id=job.id,
            portfolio_id=cached.portfolio_id,
            broker=cached.parse_output.broker,
            import_type=cached.parse_output.import_type,
            status=job.status.value,
            imported_rows=imported_count,
            duplicate_rows=len(duplicate_rows),
            invalid_rows=job.failed_rows,
            errors=errors,
        )

    async def _store_preview_cache(self, *, preview_id: uuid.UUID, cached: CachedPreview) -> None:
        self._preview_cache[preview_id] = cached

        redis = get_redis()
        if redis is None:
            return

        payload = {
            "portfolio_id": str(cached.portfolio_id),
            "source_filename": cached.source_filename,
            "source_hash": cached.source_hash,
            "generated_at": cached.generated_at.isoformat(),
            "parse_output": {
                "broker": cached.parse_output.broker.value,
                "import_type": cached.parse_output.import_type.value,
                "warnings": list(cached.parse_output.warnings),
                "rows": [
                    {
                        "row_no": row.row_no,
                        "raw": row.raw,
                        "normalized": row.normalized,
                        "status": row.status.value,
                        "semantic_type": row.semantic_type.value,
                        "messages": list(row.messages),
                        "duplicate_fingerprint": row.duplicate_fingerprint,
                    }
                    for row in cached.parse_output.rows
                ],
            },
        }
        try:
            await redis.setex(
                f"multi_import_preview:{preview_id}",
                self._preview_ttl_seconds,
                json.dumps(payload, ensure_ascii=False),
            )
        except Exception:  # noqa: BLE001
            return

    async def _load_preview_cache(self, preview_id: uuid.UUID) -> CachedPreview | None:
        in_memory = self._preview_cache.get(preview_id)
        if in_memory is not None:
            return in_memory

        redis = get_redis()
        if redis is None:
            return None

        try:
            raw = await redis.get(f"multi_import_preview:{preview_id}")
        except Exception:  # noqa: BLE001
            return None

        if not raw:
            return None

        try:
            payload = json.loads(raw)
            parse_payload = payload["parse_output"]
            rows = [
                ParsedRow(
                    row_no=int(row["row_no"]),
                    raw=dict(row.get("raw", {})),
                    normalized=dict(row.get("normalized", {})),
                    semantic_type=RowSemanticType(row.get("semantic_type", RowSemanticType.TRADE_ROW.value)),
                    status=ImportRowStatus(str(row["status"])),
                    messages=list(row.get("messages", [])),
                    duplicate_fingerprint=row.get("duplicate_fingerprint"),
                )
                for row in parse_payload.get("rows", [])
            ]
            cached = CachedPreview(
                portfolio_id=uuid.UUID(str(payload["portfolio_id"])),
                source_filename=str(payload["source_filename"]),
                source_hash=str(payload["source_hash"]),
                generated_at=datetime.fromisoformat(str(payload["generated_at"])),
                parse_output=ParseOutput(
                    broker=BrokerType(str(parse_payload["broker"])),
                    import_type=ImportType(str(parse_payload["import_type"])),
                    rows=rows,
                    warnings=list(parse_payload.get("warnings", [])),
                ),
            )
            self._preview_cache[preview_id] = cached
            return cached
        except Exception:  # noqa: BLE001
            return None

    async def _delete_preview_cache(self, preview_id: uuid.UUID) -> None:
        self._preview_cache.pop(preview_id, None)
        redis = get_redis()
        if redis is None:
            return
        try:
            await redis.delete(f"multi_import_preview:{preview_id}")
        except Exception:  # noqa: BLE001
            return

    async def add_manual_transaction(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        symbol: str,
        transaction_type: TransactionType,
        quantity: Decimal,
        price: Decimal,
        notes: str | None = None,
    ) -> ManualTransaction:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)
        payload_hash = sha256_hex(
            "|".join(
                [
                    str(user_id),
                    str(portfolio_id),
                    symbol.strip().upper(),
                    transaction_type.value,
                    str(quantity),
                    str(price),
                    datetime.now(UTC).date().isoformat(),
                ]
            )
        )
        manual = ManualTransaction(
            portfolio_id=portfolio_id,
            created_by_user_id=user_id,
            symbol=symbol.strip().upper(),
            transaction_type=transaction_type,
            transaction_date=datetime.now(UTC).date(),
            quantity=quantity,
            price=price,
            commission=ZERO,
            total_value=(quantity * price),
            event_metadata={},
            idempotency_key=payload_hash[:64],
            idempotency_fingerprint=payload_hash,
            notes=notes,
        )
        self.db.add(manual)
        await self.db.commit()
        await self.db.refresh(manual)
        return manual

    async def _assert_portfolio_owner(self, *, user_id: uuid.UUID, portfolio_id: uuid.UUID) -> None:
        query = select(Portfolio.id).where(
            Portfolio.id == portfolio_id,
            Portfolio.user_id == user_id,
        )
        result = await self.db.execute(query)
        if result.scalar_one_or_none() is None:
            raise PortfolioOwnershipError("Portfolio not found for current user.")

    def _detect_parser(self, *, headers: list[str]):
        for parser in ALL_PARSERS:
            if parser.can_handle(headers):
                return parser
        raise UnsupportedBrokerTemplateError("قالب فایل برای کارگزارهای پشتیبانی‌شده شناسایی نشد.")

    async def _apply_duplicate_detection(self, *, portfolio_id: uuid.UUID, parse_output: ParseOutput) -> ParseOutput:
        seen_in_file: set[str] = set()
        rows = []

        for row in parse_output.rows:
            if row.status != ImportRowStatus.VALID or not row.duplicate_fingerprint:
                rows.append(row)
                continue

            fingerprint = row.duplicate_fingerprint
            duplicate = fingerprint in seen_in_file
            if not duplicate:
                duplicate = await self._exists_duplicate_db(
                    portfolio_id=portfolio_id,
                    import_type=parse_output.import_type,
                    fingerprint=fingerprint,
                    normalized=row.normalized,
                )

            if duplicate:
                rows.append(
                    type(row)(
                        row_no=row.row_no,
                        raw=row.raw,
                        normalized=row.normalized,
                        status=ImportRowStatus.DUPLICATE,
                        messages=[*row.messages, "رکورد تکراری تشخیص داده شد."],
                        duplicate_fingerprint=row.duplicate_fingerprint,
                    )
                )
            else:
                seen_in_file.add(fingerprint)
                rows.append(row)

        return ParseOutput(
            broker=parse_output.broker,
            import_type=parse_output.import_type,
            rows=rows,
            warnings=parse_output.warnings,
        )

    async def _exists_duplicate_db(
        self,
        *,
        portfolio_id: uuid.UUID,
        import_type: ImportType,
        fingerprint: str,
        normalized: dict[str, Any],
    ) -> bool:
        if import_type == ImportType.LEDGER_TRANSACTIONS:
            if not fingerprint:
                return False
            query = select(Transaction.id).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.reference_hash == fingerprint,
            )
            result = await self.db.execute(query)
            return result.scalar_one_or_none() is not None

        snapshot_at = str(normalized.get("snapshot_at") or "")
        snapshot_date = None
        if snapshot_at:
            try:
                snapshot_date = datetime.fromisoformat(snapshot_at).date()
            except ValueError:
                snapshot_date = None

        query = select(PortfolioSnapshot).where(
            PortfolioSnapshot.portfolio_id == portfolio_id,
            PortfolioSnapshot.holdings_breakdown.is_not(None),
        )
        if snapshot_date is not None:
            query = query.where(PortfolioSnapshot.snapshot_date == snapshot_date)
        result = await self.db.execute(query)
        snapshots = list(result.scalars().all())
        symbol = str(normalized.get("symbol") or "")
        quantity = str(normalized.get("quantity") or "")
        market_value = str(normalized.get("market_value_today") or "")
        key = f"{symbol}|{quantity}|{market_value}"
        for snapshot in snapshots:
            breakdown = snapshot.holdings_breakdown or {}
            if isinstance(breakdown, dict):
                rows = breakdown.get("rows", [])
                if any(str(item.get("dup_key", "")) == key for item in rows if isinstance(item, dict)):
                    return True
        return False

    def _build_summary(self, *, parse_output: ParseOutput) -> ImportPreviewSummary:
        total_rows = len(parse_output.rows)
        valid_rows = sum(row.status == ImportRowStatus.VALID for row in parse_output.rows)
        invalid_rows = sum(row.status == ImportRowStatus.INVALID for row in parse_output.rows)
        duplicate_rows = sum(row.status == ImportRowStatus.DUPLICATE for row in parse_output.rows)
        return ImportPreviewSummary(
            total_rows=total_rows,
            valid_rows=valid_rows,
            invalid_rows=invalid_rows,
            duplicate_rows=duplicate_rows,
            warnings=list(parse_output.warnings),
        )

    async def _persist_ledger_row(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset: Asset,
        normalized: dict[str, Any],
        fingerprint: str,
        source_filename: str,
        source_broker: str,
        source_row_number: int,
    ) -> Transaction:
        symbol = str(normalized.get("symbol") or "").strip().upper()
        if not symbol:
            raise ValueError("Ledger row missing symbol.")
        quantity = Decimal(str(normalized.get("quantity") or "0"))
        unit_price = Decimal(str(normalized.get("unit_price") or "0"))
        if quantity <= ZERO:
            raise ValueError("Ledger row quantity must be positive.")
        if unit_price <= ZERO:
            raise ValueError("Ledger row unit price must be positive.")
        trade_at = datetime.fromisoformat(str(normalized["trade_at"]))
        debit = Decimal(str(normalized.get("debit") or "0"))
        credit = Decimal(str(normalized.get("credit") or "0"))
        is_buy = debit > ZERO
        signed_total = (quantity * unit_price)
        trade_side = TransactionType.BUY if is_buy else TransactionType.SELL

        membership_service = PortfolioMembershipService(self.db)
        await membership_service.ensure_membership(
            portfolio_id=portfolio_id,
            asset_id=asset.id,
        )

        position_result = await self.db.execute(
            select(AssetPosition)
            .where(
                AssetPosition.portfolio_id == portfolio_id,
                AssetPosition.asset_id == asset.id,
            )
            .with_for_update()
        )
        position = position_result.scalar_one_or_none()
        if position is None:
            position = AssetPosition(
                portfolio_id=portfolio_id,
                asset_id=asset.id,
                total_quantity=ZERO,
                weighted_avg_cost=ZERO,
                total_cost_basis=ZERO,
                cumulative_realized_pnl=ZERO,
                trade_count=0,
                last_updated=datetime.now(UTC),
            )
            self.db.add(position)
            await self.db.flush()

        trade_date = trade_at.date()
        duplicate_query = select(Transaction.id).where(
            Transaction.portfolio_id == portfolio_id,
            Transaction.asset_id == asset.id,
            Transaction.transaction_type == trade_side,
            func.date(Transaction.executed_at) == trade_date,
            Transaction.quantity == quantity,
            Transaction.price_per_unit == unit_price,
        )
        duplicate_result = await self.db.execute(duplicate_query)
        if duplicate_result.scalar_one_or_none() is not None:
            raise ValueError("Duplicate trade signature detected for this portfolio/asset/side/date/quantity/price.")

        old_quantity = Decimal(str(position.total_quantity or ZERO))
        old_wac = Decimal(str(position.weighted_avg_cost or ZERO))
        old_cost_basis = Decimal(str(position.total_cost_basis or ZERO))
        realized_pnl = ZERO
        requires_reconciliation = False
        if trade_side == TransactionType.BUY:
            trade_total = Decimal(str(signed_total))
            new_quantity = old_quantity + quantity
            new_cost_basis = old_cost_basis + trade_total
            new_wac = ZERO if new_quantity <= ZERO else (new_cost_basis / new_quantity)
        else:
            if quantity > old_quantity:
                # Preserve the immutable broker row. The unmatched quantity is
                # deliberately non-impacting until a cross-portfolio
                # reconciliation is confirmed and the canonical replay runs.
                requires_reconciliation = True
                proceeds = Decimal(str(signed_total))
                new_quantity = old_quantity
                new_cost_basis = old_cost_basis
                new_wac = old_wac
                trade_total = proceeds
            else:
                proceeds = Decimal(str(signed_total))
                cost_of_sold = quantity * old_wac
                realized_pnl = proceeds - cost_of_sold
                new_quantity = old_quantity - quantity
                new_cost_basis = ZERO if new_quantity <= ZERO else (old_cost_basis - cost_of_sold)
                new_wac = ZERO if new_quantity <= ZERO else old_wac
                trade_total = proceeds

        position.total_quantity = new_quantity
        position.total_cost_basis = new_cost_basis
        position.weighted_avg_cost = new_wac
        if trade_side == TransactionType.SELL:
            position.cumulative_realized_pnl = Decimal(str(position.cumulative_realized_pnl or ZERO)) + realized_pnl
        if not requires_reconciliation:
            position.trade_count = int(position.trade_count or 0) + 1
        position.last_updated = datetime.now(UTC)

        transaction = Transaction(
            portfolio_id=portfolio_id,
            asset_id=asset.id,
            transaction_type=trade_side,
            quantity=quantity,
            price_per_unit=unit_price,
            fees=ZERO,
            total_amount=trade_total,
            currency="IRR",
            realized_pnl=realized_pnl,
            wac_at_execution=old_wac,
            reference_hash=fingerprint,
            idempotency_key=fingerprint[:255],
            executed_at=trade_at,
            notes=str(normalized.get("description") or ""),
            source_metadata={
                "import_flow": "multi_portfolio",
                "source_file": source_filename,
                "source_broker": source_broker,
                "source_row_number": source_row_number,
                "raw_description": str(normalized.get("description") or ""),
                "requires_reconciliation": requires_reconciliation,
            },
            external_ref=None,
        )
        self.db.add(transaction)
        await self.db.flush()
        return transaction

    async def _persist_snapshot_row(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset: Asset,
        normalized: dict[str, Any],
    ) -> None:
        snapshot_at = datetime.fromisoformat(str(normalized["snapshot_at"])).date()
        symbol = str(normalized.get("symbol") or "").strip().upper()
        quantity = Decimal(str(normalized.get("quantity") or "0"))
        market_value = Decimal(str(normalized.get("market_value_today") or "0"))
        cost_basis = Decimal(str(normalized.get("cost_basis") or "0"))
        weight_pct = Decimal(str(normalized.get("weight_pct") or "0")) if normalized.get("weight_pct") else None
        dup_key = f"{symbol}|{quantity}|{market_value}"

        query = select(PortfolioSnapshot).where(
            PortfolioSnapshot.portfolio_id == portfolio_id,
            PortfolioSnapshot.snapshot_date == snapshot_at,
        )
        result = await self.db.execute(query)
        snapshot = result.scalar_one_or_none()

        row_payload = {
            "symbol": symbol,
            "quantity": str(quantity),
            "market_value_today": str(market_value),
            "cost_basis": str(cost_basis),
            "weight_pct": str(weight_pct) if weight_pct is not None else None,
            "dup_key": dup_key,
        }

        if snapshot is None:
            snapshot = PortfolioSnapshot(
                portfolio_id=portfolio_id,
                snapshot_date=snapshot_at,
                total_market_value=market_value,
                total_cost_basis=cost_basis,
                total_gain_loss=market_value - cost_basis,
                total_gain_loss_pct=ZERO if cost_basis == ZERO else ((market_value - cost_basis) / cost_basis) * Decimal("100"),
                cash_balance=ZERO,
                holdings_breakdown={"rows": [row_payload]},
            )
            self.db.add(snapshot)
            await self._upsert_asset_position_from_snapshot(
                portfolio_id=portfolio_id,
                asset=asset,
                quantity=quantity,
                cost_basis=cost_basis,
            )
            await self._upsert_holding_snapshot_row(
                portfolio_id=portfolio_id,
                asset=asset,
                snapshot_date=snapshot_at,
                quantity=quantity,
                average_cost=ZERO if quantity <= ZERO else (cost_basis / quantity),
                cost_basis=cost_basis,
                market_value=market_value,
                weight_pct=weight_pct,
            )
            return

        breakdown = snapshot.holdings_breakdown or {"rows": []}
        if not isinstance(breakdown, dict):
            breakdown = {"rows": []}
        rows = breakdown.get("rows")
        if not isinstance(rows, list):
            rows = []

        rows.append(row_payload)
        total_market_value = sum(Decimal(str(item.get("market_value_today") or "0")) for item in rows if isinstance(item, dict))
        total_cost_basis = sum(Decimal(str(item.get("cost_basis") or "0")) for item in rows if isinstance(item, dict))
        total_gain = total_market_value - total_cost_basis
        total_gain_pct = ZERO if total_cost_basis == ZERO else (total_gain / total_cost_basis) * Decimal("100")

        snapshot.holdings_breakdown = {"rows": rows}
        snapshot.total_market_value = total_market_value
        snapshot.total_cost_basis = total_cost_basis
        snapshot.total_gain_loss = total_gain
        snapshot.total_gain_loss_pct = total_gain_pct
        await self._upsert_asset_position_from_snapshot(
            portfolio_id=portfolio_id,
            asset=asset,
            quantity=quantity,
            cost_basis=cost_basis,
        )
        await self._upsert_holding_snapshot_row(
            portfolio_id=portfolio_id,
            asset=asset,
            snapshot_date=snapshot_at,
            quantity=quantity,
            average_cost=ZERO if quantity <= ZERO else (cost_basis / quantity),
            cost_basis=cost_basis,
            market_value=market_value,
            weight_pct=weight_pct,
        )

    async def _upsert_asset_position_from_snapshot(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset: Asset,
        quantity: Decimal,
        cost_basis: Decimal,
    ) -> None:
        query = select(AssetPosition).where(
            AssetPosition.portfolio_id == portfolio_id,
            AssetPosition.asset_id == asset.id,
        )
        result = await self.db.execute(query)
        position = result.scalar_one_or_none()

        weighted_avg_cost = ZERO
        if quantity > ZERO:
            weighted_avg_cost = cost_basis / quantity
        if weighted_avg_cost < ZERO:
            weighted_avg_cost = ZERO

        if position is None:
            position = AssetPosition(
                portfolio_id=portfolio_id,
                asset_id=asset.id,
                total_quantity=quantity,
                weighted_avg_cost=weighted_avg_cost,
                total_cost_basis=cost_basis,
                cumulative_realized_pnl=ZERO,
                trade_count=0,
                last_updated=datetime.now(UTC),
            )
            self.db.add(position)
            return

        position.total_quantity = quantity
        position.total_cost_basis = cost_basis
        position.weighted_avg_cost = weighted_avg_cost
        position.last_updated = datetime.now(UTC)

    async def _upsert_holding_snapshot_row(
        self,
        *,
        portfolio_id: uuid.UUID,
        asset: Asset,
        snapshot_date: date,
        quantity: Decimal,
        average_cost: Decimal,
        cost_basis: Decimal,
        market_value: Decimal | None,
        weight_pct: Decimal | None,
    ) -> None:
        query = select(HoldingSnapshot).where(
            HoldingSnapshot.portfolio_id == portfolio_id,
            HoldingSnapshot.asset_id == asset.id,
            HoldingSnapshot.snapshot_date == snapshot_date,
        )
        result = await self.db.execute(query)
        row = result.scalar_one_or_none()

        market_price = None
        if market_value is not None and quantity > ZERO:
            market_price = market_value / quantity

        if row is None:
            row = HoldingSnapshot(
                portfolio_id=portfolio_id,
                asset_id=asset.id,
                snapshot_date=snapshot_date,
                quantity=quantity,
                average_cost=average_cost,
                cost_basis=cost_basis,
                market_price=market_price,
                market_value=market_value,
                unrealized_pnl=(market_value - cost_basis) if market_value is not None else None,
                weight_pct=weight_pct,
                source_metadata={"import_flow": "multi_portfolio"},
            )
            self.db.add(row)
            return

        row.quantity = quantity
        row.average_cost = average_cost
        row.cost_basis = cost_basis
        row.market_price = market_price
        row.market_value = market_value
        row.unrealized_pnl = (market_value - cost_basis) if market_value is not None else None
        row.weight_pct = weight_pct
        row.source_metadata = {"import_flow": "multi_portfolio"}

    async def _resolve_assets_for_rows(
        self,
        *,
        rows: list[ParsedRow],
    ) -> dict[tuple[str, str], Asset]:
        resolver = AssetResolverService(self.db)
        resolved_assets: dict[tuple[str, str], Asset] = {}
        for row in rows:
            symbol = str(row.normalized.get("symbol") or "").strip().upper()
            if not symbol:
                continue
            market = str(row.normalized.get("market") or "TSETMC").strip().upper() or "TSETMC"
            display_name = str(row.normalized.get("display_name") or "").strip() or symbol
            key = (symbol, market)
            if key in resolved_assets:
                continue
            resolved = await resolver.resolve_symbol(
                symbol_raw=symbol,
                symbol_normalized=symbol,
                market=market,
                display_name=display_name,
            )
            resolved_assets[key] = resolved.asset

        return resolved_assets

    def _resolve_asset_for_row(
        self,
        *,
        normalized: dict[str, Any],
        resolved_assets: dict[tuple[str, str], Asset],
    ) -> Asset:
        symbol = str(normalized.get("symbol") or "").strip().upper()
        if not symbol:
            raise ValueError("ردیف فاقد نماد معتبر است.")
        market = str(normalized.get("market") or "TSETMC").strip().upper() or "TSETMC"
        key = (symbol, market)
        asset = resolved_assets.get(key)
        if asset is None:
            raise ValueError(f"دارایی برای نماد {symbol} در بازار {market} قابل resolve نیست.")
        return asset

    async def get_portfolio_performance(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
    ) -> dict[str, Any]:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)
        portfolio_row = await self.db.execute(
            select(Portfolio).where(Portfolio.id == portfolio_id, Portfolio.user_id == user_id)
        )
        portfolio = portfolio_row.scalar_one()

        invested_result = await self.db.execute(
            select(func.coalesce(func.sum(Transaction.total_amount), 0)).where(
                Transaction.portfolio_id == portfolio_id,
                Transaction.transaction_type == TransactionType.BUY,
            )
        )
        invested = Decimal(str(invested_result.scalar_one() or 0))

        latest_snapshot_result = await self.db.execute(
            select(PortfolioSnapshot)
            .where(PortfolioSnapshot.portfolio_id == portfolio_id)
            .order_by(PortfolioSnapshot.snapshot_date.desc())
            .limit(1)
        )
        snapshot = latest_snapshot_result.scalar_one_or_none()
        current_value = snapshot.total_market_value if snapshot is not None else ZERO
        pnl = current_value - invested
        roi = ZERO if invested == ZERO else (pnl / invested) * Decimal("100")

        manager = await self._get_portfolio_manager(portfolio_id=portfolio_id)
        return {
            "portfolio_id": portfolio.id,
            "portfolio_name": portfolio.name,
            "manager": manager,
            "total_invested": invested,
            "total_current_value": current_value,
            "total_pnl": pnl,
            "roi_percent": roi,
        }

    async def get_aggregate_performance(self, *, user_id: uuid.UUID) -> dict[str, Any]:
        portfolio_ids_result = await self.db.execute(
            select(Portfolio.id).where(Portfolio.user_id == user_id, Portfolio.is_active.is_(True))
        )
        portfolio_ids = list(portfolio_ids_result.scalars().all())
        total_invested = ZERO
        total_current_value = ZERO

        for portfolio_id in portfolio_ids:
            perf = await self.get_portfolio_performance(user_id=user_id, portfolio_id=portfolio_id)
            total_invested += Decimal(str(perf["total_invested"]))
            total_current_value += Decimal(str(perf["total_current_value"]))

        total_pnl = total_current_value - total_invested
        roi = ZERO if total_invested == ZERO else (total_pnl / total_invested) * Decimal("100")
        return {
            "portfolio_count": len(portfolio_ids),
            "total_invested": total_invested,
            "total_current_value": total_current_value,
            "total_pnl": total_pnl,
            "roi_percent": roi,
        }

    async def compare_managers(self, *, user_id: uuid.UUID) -> list[dict[str, Any]]:
        portfolio_rows = await self.db.execute(
            select(Portfolio.id).where(Portfolio.user_id == user_id, Portfolio.is_active.is_(True))
        )
        portfolio_ids = list(portfolio_rows.scalars().all())
        grouped: dict[str, dict[str, Any]] = {}

        for portfolio_id in portfolio_ids:
            perf = await self.get_portfolio_performance(user_id=user_id, portfolio_id=portfolio_id)
            manager_value = perf["manager"]
            manager = manager_value.value if isinstance(manager_value, BrokerType) else str(manager_value)
            bucket = grouped.setdefault(
                manager,
                {
                    "manager": manager,
                    "portfolios": 0,
                    "total_invested": ZERO,
                    "total_current_value": ZERO,
                    "total_pnl": ZERO,
                    "roi_percent": ZERO,
                },
            )
            bucket["portfolios"] += 1
            bucket["total_invested"] += Decimal(str(perf["total_invested"]))
            bucket["total_current_value"] += Decimal(str(perf["total_current_value"]))

        rows = []
        for bucket in grouped.values():
            bucket["total_pnl"] = bucket["total_current_value"] - bucket["total_invested"]
            bucket["roi_percent"] = (
                ZERO
                if bucket["total_invested"] == ZERO
                else (bucket["total_pnl"] / bucket["total_invested"]) * Decimal("100")
            )
            rows.append(bucket)
        return rows

    async def assign_portfolio_manager(
        self,
        *,
        user_id: uuid.UUID,
        portfolio_id: uuid.UUID,
        manager: BrokerType,
    ) -> None:
        await self._assert_portfolio_owner(user_id=user_id, portfolio_id=portfolio_id)
        query = select(Portfolio).where(Portfolio.id == portfolio_id, Portfolio.user_id == user_id)
        result = await self.db.execute(query)
        portfolio = result.scalar_one()

        mapping = {
            BrokerType.AGAH: PortfolioManagerType.AGAH,
            BrokerType.MOFID: PortfolioManagerType.MOFID,
            BrokerType.BOURSIRAN: PortfolioManagerType.BOURSIRAN,
            BrokerType.UNKNOWN: PortfolioManagerType.UNKNOWN,
        }
        portfolio.manager_type = mapping.get(manager, PortfolioManagerType.UNKNOWN)
        await self.db.commit()

    async def _get_portfolio_manager(self, *, portfolio_id: uuid.UUID) -> BrokerType:
        query = select(Portfolio.manager_type).where(Portfolio.id == portfolio_id)
        result = await self.db.execute(query)
        manager_type = result.scalar_one_or_none() or PortfolioManagerType.UNKNOWN
        mapping = {
            PortfolioManagerType.AGAH: BrokerType.AGAH,
            PortfolioManagerType.MOFID: BrokerType.MOFID,
            PortfolioManagerType.BOURSIRAN: BrokerType.BOURSIRAN,
            PortfolioManagerType.UNKNOWN: BrokerType.UNKNOWN,
        }
        return mapping.get(manager_type, BrokerType.UNKNOWN)
