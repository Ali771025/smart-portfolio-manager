"""Repository for watchlist and alert CRUD operations.

Provides:
  - Watchlist CRUD (create, read, update, delete)
  - WatchlistItem management (add/remove symbols)
  - AlertRule CRUD (create, read, update, pause/resume)
  - AlertEvent persistence (create, list, acknowledge)
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import inspect, select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.watchlist import (
    AlertEvent,
    AlertRule,
    Watchlist,
    WatchlistItem,
)
from app.models.asset import Asset

logger = logging.getLogger("watchlist_repository")


class WatchlistRepository:
    """Repository for watchlist and alert operations."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self._existing_tables: set[str] | None = None

    async def _table_exists(self, table_name: str) -> bool:
        """Return whether a table exists in the connected database."""
        if self._existing_tables is None:
            self._existing_tables = await self.db.run_sync(
                lambda sync_session: set(inspect(sync_session.bind).get_table_names())
            )
        return table_name in self._existing_tables

    # ═══════════════════════════════════════════════════════════════
    # Watchlist CRUD
    # ═══════════════════════════════════════════════════════════════

    async def create_watchlist(
        self,
        *,
        user_id: uuid.UUID,
        name: str,
        description: str | None = None,
    ) -> Watchlist:
        """Create a new watchlist."""
        if not await self._table_exists("watchlists"):
            raise RuntimeError("watchlists table is missing; run database migrations")

        watchlist = Watchlist(
            user_id=user_id,
            name=name,
            description=description,
        )
        self.db.add(watchlist)
        await self.db.flush()
        return watchlist

    async def get_watchlist(
        self,
        *,
        watchlist_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Watchlist | None:
        """Get a watchlist by ID, ensuring user ownership."""
        if not await self._table_exists("watchlists"):
            return None

        result = await self.db.execute(
            select(Watchlist)
            .where(
                Watchlist.id == watchlist_id,
                Watchlist.user_id == user_id,
            )
            .options(selectinload(Watchlist.items))
        )
        return result.scalar_one_or_none()

    async def list_watchlists(
        self,
        *,
        user_id: uuid.UUID,
    ) -> list[Watchlist]:
        """List all watchlists for a user."""
        if not await self._table_exists("watchlists"):
            return []

        result = await self.db.execute(
            select(Watchlist)
            .where(Watchlist.user_id == user_id)
            .options(selectinload(Watchlist.items))
            .order_by(Watchlist.name)
        )
        return list(result.scalars().all())

    async def update_watchlist(
        self,
        *,
        watchlist_id: uuid.UUID,
        user_id: uuid.UUID,
        name: str | None = None,
        description: str | None = None,
    ) -> Watchlist | None:
        """Update a watchlist."""
        watchlist = await self.get_watchlist(
            watchlist_id=watchlist_id,
            user_id=user_id,
        )
        if watchlist is None:
            return None

        if name is not None:
            watchlist.name = name
        if description is not None:
            watchlist.description = description

        await self.db.flush()
        return watchlist

    async def delete_watchlist(
        self,
        *,
        watchlist_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> bool:
        """Delete a watchlist and all its items/alerts."""
        result = await self.db.execute(
            delete(Watchlist).where(
                Watchlist.id == watchlist_id,
                Watchlist.user_id == user_id,
            )
        )
        return result.rowcount > 0

    # ═══════════════════════════════════════════════════════════════
    # WatchlistItem CRUD
    # ═══════════════════════════════════════════════════════════════

    async def add_item(
        self,
        *,
        watchlist_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> WatchlistItem:
        """Add a symbol to a watchlist."""
        if not await self._table_exists("watchlist_items"):
            raise RuntimeError("watchlist tables are missing; run database migrations")

        item = WatchlistItem(
            watchlist_id=watchlist_id,
            asset_id=asset_id,
            added_at=datetime.now(UTC),
        )
        self.db.add(item)
        await self.db.flush()
        return item

    async def remove_item(
        self,
        *,
        watchlist_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> bool:
        """Remove a symbol from a watchlist."""
        if not await self._table_exists("watchlist_items"):
            return False

        result = await self.db.execute(
            delete(WatchlistItem).where(
                WatchlistItem.watchlist_id == watchlist_id,
                WatchlistItem.asset_id == asset_id,
            )
        )
        return result.rowcount > 0

    async def get_item(
        self,
        *,
        watchlist_id: uuid.UUID,
        asset_id: uuid.UUID,
    ) -> WatchlistItem | None:
        """Get a specific watchlist item."""
        if not await self._table_exists("watchlist_items"):
            return None

        result = await self.db.execute(
            select(WatchlistItem).where(
                WatchlistItem.watchlist_id == watchlist_id,
                WatchlistItem.asset_id == asset_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_items_for_watchlist(
        self,
        *,
        watchlist_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> list[tuple[WatchlistItem, Asset]]:
        """List watchlist items with asset metadata after ownership check."""
        if not await self._table_exists("watchlist_items"):
            return []

        result = await self.db.execute(
            select(WatchlistItem, Asset)
            .join(Watchlist, Watchlist.id == WatchlistItem.watchlist_id)
            .join(Asset, Asset.id == WatchlistItem.asset_id)
            .where(
                WatchlistItem.watchlist_id == watchlist_id,
                Watchlist.user_id == user_id,
            )
            .order_by(WatchlistItem.added_at.desc(), Asset.ticker_symbol.asc())
        )
        return list(result.all())

    async def get_asset_by_symbol(self, symbol: str) -> Asset | None:
        """Resolve a watchlist symbol to an active asset."""
        normalized = symbol.strip().upper()
        if not normalized:
            return None
        result = await self.db.execute(
            select(Asset)
            .where(
                Asset.is_active.is_(True),
                Asset.normalized_symbol == normalized,
            )
            .limit(1)
        )
        asset = result.scalar_one_or_none()
        if asset is not None:
            return asset

        result = await self.db.execute(
            select(Asset)
            .where(
                Asset.is_active.is_(True),
                Asset.ticker_symbol == normalized,
            )
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def sync_symbols(
        self,
        *,
        watchlist_id: uuid.UUID,
        user_id: uuid.UUID,
        add_symbols: list[str],
        remove_symbols: list[str],
    ) -> Watchlist | None:
        """Add and remove symbols for a watchlist owned by the user."""
        watchlist = await self.get_watchlist(
            watchlist_id=watchlist_id,
            user_id=user_id,
        )
        if watchlist is None:
            return None

        for symbol in remove_symbols:
            asset = await self.get_asset_by_symbol(symbol)
            if asset is not None:
                await self.remove_item(
                    watchlist_id=watchlist_id,
                    asset_id=asset.id,
                )

        for symbol in add_symbols:
            asset = await self.get_asset_by_symbol(symbol)
            if asset is None:
                continue
            existing = await self.get_item(
                watchlist_id=watchlist_id,
                asset_id=asset.id,
            )
            if existing is None:
                await self.add_item(
                    watchlist_id=watchlist_id,
                    asset_id=asset.id,
                )

        await self.db.flush()
        return await self.get_watchlist(watchlist_id=watchlist_id, user_id=user_id)

    # ═══════════════════════════════════════════════════════════════
    # AlertRule CRUD
    # ═══════════════════════════════════════════════════════════════

    async def create_alert_rule(
        self,
        *,
        user_id: uuid.UUID,
        watchlist_item_id: uuid.UUID,
        alert_type: str,
        threshold: float,
        threshold_pct: float | None = None,
        frequency: str = "always",
        notification_channels: list[str] | None = None,
        message_template: str | None = None,
        expires_at: datetime | None = None,
    ) -> AlertRule:
        """Create a new alert rule."""
        if not await self._table_exists("alert_rules"):
            raise RuntimeError("alert rule tables are missing; run database migrations")

        rule = AlertRule(
            user_id=user_id,
            watchlist_item_id=watchlist_item_id,
            alert_type=alert_type,
            threshold=threshold,
            threshold_pct=threshold_pct,
            status="ACTIVE",
            frequency=frequency,
            notification_channels=notification_channels or ["in_app"],
            message_template=message_template,
            expires_at=expires_at,
        )
        self.db.add(rule)
        await self.db.flush()
        return rule

    async def get_alert_rule(
        self,
        *,
        rule_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> AlertRule | None:
        """Get an alert rule by ID, ensuring user ownership."""
        if not await self._table_exists("alert_rules"):
            return None

        result = await self.db.execute(
            select(AlertRule).where(
                AlertRule.id == rule_id,
                AlertRule.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_alert_rules(
        self,
        *,
        user_id: uuid.UUID,
        status: str | None = None,
    ) -> list[AlertRule]:
        """List alert rules for a user, optionally filtered by status."""
        if not await self._table_exists("alert_rules"):
            return []

        query = select(AlertRule).where(AlertRule.user_id == user_id)
        if status:
            query = query.where(AlertRule.status == status)
        query = query.order_by(AlertRule.created_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_active_alert_rules(
        self,
        *,
        user_id: uuid.UUID | None = None,
    ) -> list[AlertRule]:
        """List all active alert rules for evaluation."""
        if not await self._table_exists("alert_rules"):
            return []

        query = select(AlertRule).where(AlertRule.status == "ACTIVE")
        if user_id:
            query = query.where(AlertRule.user_id == user_id)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def update_alert_rule(
        self,
        *,
        rule_id: uuid.UUID,
        user_id: uuid.UUID,
        threshold: float | None = None,
        threshold_pct: float | None = None,
        status: str | None = None,
        frequency: str | None = None,
        notification_channels: list[str] | None = None,
        message_template: str | None = None,
        expires_at: datetime | None = None,
    ) -> AlertRule | None:
        """Update an alert rule."""
        rule = await self.get_alert_rule(rule_id=rule_id, user_id=user_id)
        if rule is None:
            return None

        if threshold is not None:
            rule.threshold = threshold
        if threshold_pct is not None:
            rule.threshold_pct = threshold_pct
        if status is not None:
            rule.status = status
        if frequency is not None:
            rule.frequency = frequency
        if notification_channels is not None:
            rule.notification_channels = notification_channels
        if message_template is not None:
            rule.message_template = message_template
        if expires_at is not None:
            rule.expires_at = expires_at

        await self.db.flush()
        return rule

    async def delete_alert_rule(
        self,
        *,
        rule_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> bool:
        """Delete an alert rule."""
        result = await self.db.execute(
            delete(AlertRule).where(
                AlertRule.id == rule_id,
                AlertRule.user_id == user_id,
            )
        )
        return result.rowcount > 0

    # ═══════════════════════════════════════════════════════════════
    # AlertEvent CRUD
    # ═══════════════════════════════════════════════════════════════

    async def create_alert_event(
        self,
        *,
        alert_id: uuid.UUID,
        price_at_trigger: float,
        threshold_value: float,
        change_pct: float | None = None,
        notification_channels: list[str] | None = None,
    ) -> AlertEvent:
        """Create an alert event record."""
        event = AlertEvent(
            alert_id=alert_id,
            triggered_at=datetime.now(UTC),
            price_at_trigger=price_at_trigger,
            threshold_value=threshold_value,
            change_pct=change_pct,
            notification_sent=False,
            notification_channels=notification_channels,
        )
        self.db.add(event)
        await self.db.flush()
        return event

    async def list_alert_events(
        self,
        *,
        user_id: uuid.UUID,
        alert_id: uuid.UUID | None = None,
        limit: int = 50,
    ) -> list[AlertEvent]:
        """List alert events for a user."""
        if not await self._table_exists("alert_events"):
            return []

        query = (
            select(AlertEvent)
            .join(AlertRule, AlertEvent.alert_id == AlertRule.id)
            .where(AlertRule.user_id == user_id)
        )
        if alert_id:
            query = query.where(AlertEvent.alert_id == alert_id)
        query = query.order_by(AlertEvent.triggered_at.desc()).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def acknowledge_alert_event(
        self,
        *,
        event_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> bool:
        """Acknowledge an alert event."""
        # Verify user ownership
        event = await self.db.execute(
            select(AlertEvent)
            .join(AlertRule, AlertEvent.alert_id == AlertRule.id)
            .where(
                AlertEvent.id == event_id,
                AlertRule.user_id == user_id,
            )
        )
        event_record = event.scalar_one_or_none()
        if event_record is None:
            return False

        event_record.acknowledged_at = datetime.now(UTC)
        await self.db.flush()
        return True

    async def mark_notification_sent(
        self,
        *,
        event_id: uuid.UUID,
    ) -> None:
        """Mark that notifications were sent for an event."""
        await self.db.execute(
            update(AlertEvent)
            .where(AlertEvent.id == event_id)
            .values(notification_sent=True)
        )
        await self.db.flush()

    async def update_alert_trigger(
        self,
        *,
        rule_id: uuid.UUID,
    ) -> None:
        """Update alert rule trigger tracking."""
        await self.db.execute(
            update(AlertRule)
            .where(AlertRule.id == rule_id)
            .values(
                last_triggered_at=datetime.now(UTC),
                trigger_count=AlertRule.trigger_count + 1,
            )
        )
        await self.db.flush()

    # ═══════════════════════════════════════════════════════════════
    # Summary Queries
    # ═══════════════════════════════════════════════════════════════

    async def get_alert_summary(
        self,
        *,
        user_id: uuid.UUID,
    ) -> dict[str, Any]:
        """Get alert summary statistics."""
        if not await self._table_exists("alert_rules"):
            return {
                "total_active_alerts": 0,
                "total_triggered_today": 0,
                "total_unacknowledged": 0,
            }

        # Count active alerts
        active_result = await self.db.execute(
            select(func.count(AlertRule.id)).where(
                AlertRule.user_id == user_id,
                AlertRule.status == "ACTIVE",
            )
        )
        active_count = active_result.scalar() or 0

        # Count triggered today
        today_start = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0)
        triggered_result = await self.db.execute(
            select(func.count(AlertEvent.id))
            .join(AlertRule, AlertEvent.alert_id == AlertRule.id)
            .where(
                AlertRule.user_id == user_id,
                AlertEvent.triggered_at >= today_start,
            )
        )
        triggered_today = triggered_result.scalar() or 0

        # Count unacknowledged
        unack_result = await self.db.execute(
            select(func.count(AlertEvent.id))
            .join(AlertRule, AlertEvent.alert_id == AlertRule.id)
            .where(
                AlertRule.user_id == user_id,
                AlertEvent.acknowledged_at.is_(None),
            )
        )
        unacknowledged = unack_result.scalar() or 0

        return {
            "total_active_alerts": active_count,
            "total_triggered_today": triggered_today,
            "total_unacknowledged": unacknowledged,
        }

    # ═══════════════════════════════════════════════════════════════
    # Transaction Support
    # ═══════════════════════════════════════════════════════════════

    async def commit(self) -> None:
        """Commit the current transaction."""
        await self.db.commit()

    async def rollback(self) -> None:
        """Rollback the current transaction."""
        await self.db.rollback()
