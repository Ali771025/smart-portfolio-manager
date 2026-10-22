"""Bootstrap utilities for creating an optional local test admin account."""

from __future__ import annotations

import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User

logger = logging.getLogger(__name__)


async def ensure_test_admin_exists(session_factory: async_sessionmaker) -> None:
    """Create/update a dedicated test admin account for local environments."""

    if not settings.TEST_ADMIN_BOOTSTRAP_ENABLED:
        return

    email = settings.TEST_ADMIN_EMAIL.strip().lower()
    password = settings.TEST_ADMIN_PASSWORD
    full_name = settings.TEST_ADMIN_FULL_NAME.strip() or "Test Admin"

    if len(password) < 8:
        logger.warning("TEST_ADMIN_PASSWORD is too short. Skipping admin bootstrap.")
        return

    async with session_factory() as session:
        result = await session.execute(select(User).where(User.email == email))
        existing_user = result.scalar_one_or_none()

        if existing_user is None:
            session.add(
                User(
                    email=email,
                    hashed_password=hash_password(password),
                    full_name=full_name,
                    is_active=True,
                    is_verified=True,
                    is_superuser=True,
                )
            )
            await session.commit()
            logger.info("Bootstrapped local test admin account: %s", email)
            return

        changed = False
        if not existing_user.is_superuser:
            existing_user.is_superuser = True
            changed = True
        if not existing_user.is_active:
            existing_user.is_active = True
            changed = True
        if not existing_user.is_verified:
            existing_user.is_verified = True
            changed = True
        if existing_user.full_name != full_name:
            existing_user.full_name = full_name
            changed = True
        existing_user.hashed_password = hash_password(password)
        changed = True

        if changed:
            await session.commit()
            logger.info("Updated local test admin account flags: %s", email)
