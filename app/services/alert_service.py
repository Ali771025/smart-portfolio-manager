"""Alert evaluation service for watchlist price/volume monitoring.

Evaluates alert rules against current market data and creates
alert events when conditions are met.

Supported alert types:
  - PRICE_ABOVE: Current price >= threshold
  - PRICE_BELOW: Current price <= threshold
  - PRICE_CHANGE_PCT_ABOVE: Daily change >= threshold_pct
  - PRICE_CHANGE_PCT_BELOW: Daily change <= threshold_pct
  - VOLUME_ABOVE: Volume >= threshold
  - VOLUME_BELOW: Volume <= threshold
  - VOLUME_SPIKE: Volume >= average_volume * threshold_pct

Design:
  - Rules are evaluated in batch for efficiency
  - Expired rules are automatically paused
  - Frequency constraints are respected (once, daily, always)
  - Events are persisted for audit trail
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.market_cache import get_live_snapshot
from app.models.watchlist import AlertEvent, AlertRule, WatchlistItem
from app.repositories.market_data import MarketDataRepository
from app.repositories.watchlist import WatchlistRepository

logger = logging.getLogger("alert_service")


class AlertEvaluationService:
    """Service for evaluating alert rules against market data."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._watchlist_repo = WatchlistRepository(db)
        self._market_repo = MarketDataRepository(db)

    async def evaluate_all_active_alerts(
        self,
        *,
        user_id: uuid.UUID | None = None,
    ) -> list[dict[str, Any]]:
        """Evaluate all active alert rules.

        Args:
            user_id: Optional user ID to filter alerts.

        Returns:
            List of triggered alert event dicts.
        """
        logger.info("alert.evaluate.start user=%s", user_id)

        # Get active rules
        rules = await self._watchlist_repo.list_active_alert_rules(user_id=user_id)
        logger.info("alert.evaluate.rules_found count=%d", len(rules))

        triggered_events: list[dict[str, Any]] = []

        for rule in rules:
            try:
                event = await self._evaluate_single_rule(rule)
                if event is not None:
                    triggered_events.append(event)
            except Exception as exc:
                logger.warning(
                    "alert.evaluate.rule_failed rule_id=%s error=%s",
                    rule.id,
                    exc,
                )

        logger.info(
            "alert.evaluate.complete total=%d triggered=%d",
            len(rules),
            len(triggered_events),
        )

        return triggered_events

    async def evaluate_user_alerts(
        self,
        *,
        user_id: uuid.UUID,
    ) -> list[dict[str, Any]]:
        """Evaluate alerts for a specific user."""
        return await self.evaluate_all_active_alerts(user_id=user_id)

    async def _evaluate_single_rule(
        self,
        rule: AlertRule,
    ) -> dict[str, Any] | None:
        """Evaluate a single alert rule against current market data."""
        # Check if rule is expired
        if rule.expires_at and rule.expires_at < datetime.now(UTC):
            await self._watchlist_repo.update_alert_rule(
                rule_id=rule.id,
                user_id=rule.user_id,
                status="EXPIRED",
            )
            logger.info("alert.evaluate.expired rule_id=%s", rule.id)
            return None

        # Get watchlist item to find asset
        watchlist_item = await self._get_watchlist_item(rule.watchlist_item_id)
        if watchlist_item is None:
            logger.warning("alert.evaluate.item_not_found rule_id=%s", rule.id)
            return None

        # Get current market data from Redis cache
        asset = await self._market_repo.get_asset_by_id(watchlist_item.asset_id)
        if asset is None:
            return None

        current_price = float(asset.current_price) if asset.current_price else None
        if current_price is None or current_price <= 0:
            return None

        # Get live snapshot for additional data
        live_snapshot = None
        if asset.tsetmc_id:
            live_snapshot = await get_live_snapshot(asset.tsetmc_id)

        # Evaluate the rule
        is_triggered, change_pct = await self._check_condition(
            rule=rule,
            current_price=current_price,
            live_snapshot=live_snapshot,
        )

        if not is_triggered:
            return None

        # Check frequency constraint
        if not self._can_trigger(rule):
            logger.debug("alert.evaluate.frequency_blocked rule_id=%s", rule.id)
            return None

        # Create alert event
        event = await self._create_alert_event(
            rule=rule,
            price_at_trigger=current_price,
            change_pct=change_pct,
        )

        # Update rule trigger tracking
        await self._watchlist_repo.update_alert_trigger(rule_id=rule.id)

        return {
            "event_id": str(event.id),
            "alert_id": str(rule.id),
            "alert_type": rule.alert_type,
            "price": current_price,
            "threshold": rule.threshold,
            "triggered_at": event.triggered_at.isoformat(),
        }

    async def _check_condition(
        self,
        *,
        rule: AlertRule,
        current_price: float,
        live_snapshot: dict[str, Any] | None,
    ) -> tuple[bool, float | None]:
        """Check if alert condition is met.

        Returns:
            Tuple of (is_triggered, change_pct).
        """
        alert_type = rule.alert_type
        threshold = rule.threshold

        if alert_type == "PRICE_ABOVE":
            return current_price >= threshold, None

        elif alert_type == "PRICE_BELOW":
            return current_price <= threshold, None

        elif alert_type == "PRICE_CHANGE_PCT_ABOVE":
            if live_snapshot is None:
                return False, None
            change_pct = self._calculate_price_change(live_snapshot)
            if change_pct is None:
                return False, None
            return change_pct >= threshold, change_pct

        elif alert_type == "PRICE_CHANGE_PCT_BELOW":
            if live_snapshot is None:
                return False, None
            change_pct = self._calculate_price_change(live_snapshot)
            if change_pct is None:
                return False, None
            return change_pct <= -threshold, change_pct

        elif alert_type == "VOLUME_ABOVE":
            if live_snapshot is None:
                return False, None
            volume = live_snapshot.get("volume", 0)
            return volume >= threshold, None

        elif alert_type == "VOLUME_BELOW":
            if live_snapshot is None:
                return False, None
            volume = live_snapshot.get("volume", 0)
            return volume <= threshold, None

        elif alert_type == "VOLUME_SPIKE":
            if live_snapshot is None:
                return False, None
            volume = live_snapshot.get("volume", 0)
            # Assume threshold_pct is the multiplier (e.g., 2.0 = 2x average)
            average_volume = await self._get_average_volume(ins_code=live_snapshot.get("ins_code"))
            if average_volume is None or average_volume <= 0:
                return False, None
            spike_ratio = volume / average_volume
            return spike_ratio >= threshold, None

        return False, None

    def _calculate_price_change(
        self,
        live_snapshot: dict[str, Any],
    ) -> float | None:
        """Calculate daily price change percentage from snapshot."""
        close_price = live_snapshot.get("close_price")
        open_price = live_snapshot.get("open_price")

        if close_price is None or open_price is None:
            return None

        close = float(close_price)
        open_p = float(open_price)

        if open_p <= 0:
            return None

        return ((close - open_p) / open_p) * 100

    def _can_trigger(self, rule: AlertRule) -> bool:
        """Check if alert can trigger based on frequency constraint."""
        if rule.frequency == "always":
            return True

        if rule.frequency == "once":
            return rule.trigger_count == 0

        if rule.frequency == "daily":
            if rule.last_triggered_at is None:
                return True
            today = datetime.now(UTC).date()
            last_triggered_date = rule.last_triggered_at.date() if rule.last_triggered_at.tzinfo else rule.last_triggered_at.replace(tzinfo=UTC).date()
            return today > last_triggered_date

        return True

    async def _get_watchlist_item(
        self,
        item_id: uuid.UUID,
    ) -> WatchlistItem | None:
        """Get watchlist item by ID."""
        from sqlalchemy import select
        result = await self._db.execute(
            select(WatchlistItem).where(WatchlistItem.id == item_id)
        )
        return result.scalar_one_or_none()

    async def _get_average_volume(
        self,
        ins_code: str | None,
    ) -> float | None:
        """Get average volume for volume spike calculation."""
        # For now, return None - can be enhanced with historical average
        return None

    async def _create_alert_event(
        self,
        *,
        rule: AlertRule,
        price_at_trigger: float,
        change_pct: float | None = None,
    ) -> AlertEvent:
        """Create an alert event record."""
        return await self._watchlist_repo.create_alert_event(
            alert_id=rule.id,
            price_at_trigger=price_at_trigger,
            threshold_value=rule.threshold,
            change_pct=change_pct,
            notification_channels=rule.notification_channels,
        )
