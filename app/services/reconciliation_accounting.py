"""Small accounting contract shared by persistence and WAC replay."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal


@dataclass(slots=True, frozen=True)
class ConfirmedReconciliationTransfer:
    allocation_id: uuid.UUID
    reconciliation_id: uuid.UUID
    asset_id: uuid.UUID
    buy_transaction_id: uuid.UUID
    sell_transaction_id: uuid.UUID
    source_portfolio_id: uuid.UUID
    destination_portfolio_id: uuid.UUID
    effective_at: datetime
    quantity: Decimal
    buy_cost: Decimal
    sell_proceeds: Decimal

    @property
    def realized_pnl(self) -> Decimal:
        return self.sell_proceeds - self.buy_cost
