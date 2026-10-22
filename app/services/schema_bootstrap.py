"""Small startup schema guards for local/dev database drift.

Alembic remains the source of truth. These guards only add backward-compatible
columns that the running app cannot operate without when a local database has
not yet been upgraded.
"""

from __future__ import annotations

import logging

from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession

logger = logging.getLogger(__name__)


async def ensure_market_price_columns(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    """Ensure market price columns from revision 20260618_01 exist."""
    async with session_factory() as session:
        await session.execute(
            text(
                """
                ALTER TABLE assets
                ADD COLUMN IF NOT EXISTS last_trade_price NUMERIC(24, 8)
                NOT NULL DEFAULT 0.00000000
                """
            )
        )
        await session.execute(
            text(
                """
                ALTER TABLE assets
                ADD COLUMN IF NOT EXISTS closing_price NUMERIC(24, 8)
                NOT NULL DEFAULT 0.00000000
                """
            )
        )
        await session.execute(
            text(
                """
                UPDATE assets
                SET
                    last_trade_price = COALESCE(NULLIF(last_trade_price, 0), current_price, 0),
                    closing_price = COALESCE(NULLIF(closing_price, 0), current_price, 0)
                """
            )
        )
        await session.execute(
            text(
                """
                ALTER TABLE daily_prices
                ADD COLUMN IF NOT EXISTS last_trade_price NUMERIC(24, 8)
                NOT NULL DEFAULT 0.00000000
                """
            )
        )
        await session.execute(
            text(
                """
                UPDATE daily_prices
                SET last_trade_price = COALESCE(NULLIF(last_trade_price, 0), close_price, 0)
                """
            )
        )
        await session.commit()
    logger.info("Market price schema guard completed.")
