"""
Async SQLAlchemy 2.0 database engine, session factory, and declarative base.

Key design decisions:
  • asyncpg driver for high-throughput async I/O.
  • Connection-pool tuning exposed via Settings for ops-level control.
  • `get_db` is a FastAPI-compatible async generator dependency.
  • DeclarativeBase defined here — imported by all model files.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# ──────────────────────── Engine ────────────────────────────
# The engine manages the connection pool to PostgreSQL.
# `pool_pre_ping=True` issues a lightweight check before reusing
# a connection, preventing "server closed the connection" errors.

async_engine = create_async_engine(
    url=settings.DATABASE_URL,
    echo=settings.DB_ECHO,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_timeout=settings.DB_POOL_TIMEOUT,
    pool_recycle=settings.DB_POOL_RECYCLE,
    pool_pre_ping=True,
)

# ──────────────────── Session Factory ───────────────────────
# `expire_on_commit=False` is critical for async: prevents lazy-load
# attempts on detached objects after a commit inside an async context.

AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)
async_session_factory = AsyncSessionLocal


# ──────────────────── Declarative Base ──────────────────────

class Base(DeclarativeBase):
    """
    Root base class for every ORM model.

    All models inherit from this via mixins so that Alembic's
    `target_metadata = Base.metadata` discovers every table.
    """
    pass


# ──────────────────── Dependency ────────────────────────────

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI dependency that yields an async session and guarantees
    cleanup.  Usage:

        @router.get("/items")
        async def list_items(db: AsyncSession = Depends(get_db)):
            ...

    The session is committed only by service-layer code; the
    dependency merely opens and closes the session boundary.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
