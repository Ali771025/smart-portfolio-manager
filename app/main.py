"""
FastAPI application factory with lifespan management.
"""

from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

try:  # Cache is optional for local/dev startup.
    from fastapi_cache import FastAPICache
    from fastapi_cache.backends.redis import RedisBackend
except ModuleNotFoundError:  # pragma: no cover - depends on local environment
    FastAPICache = None  # type: ignore[assignment]
    RedisBackend = None  # type: ignore[assignment]

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.redis import init_redis, close_redis
from app.api.v1.router import api_router
from app.services.bootstrap_admin import ensure_test_admin_exists
from app.services.schema_bootstrap import ensure_market_price_columns

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-20s | %(levelname)-7s | %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup:
      1. Initialize Redis connection pool
    Shutdown:
      1. Close Redis pool
    """
    # ─── Startup ───────────────────────────────────────────────
    try:
        await ensure_market_price_columns(async_session_factory)
    except Exception as exc:  # noqa: BLE001 - startup should report schema drift clearly
        logger.exception("Market price schema bootstrap failed: %s", exc)
        raise

    try:
        await ensure_test_admin_exists(async_session_factory)
    except Exception as exc:  # noqa: BLE001 - bootstrapping must not block startup
        logger.warning("Test admin bootstrap failed: %s", exc)

    redis_client = None
    try:
        redis_client = await init_redis()
    except Exception as exc:  # noqa: BLE001 - Redis is optional in local/dev
        logger.warning(
            "Redis unavailable at startup after %s attempt(s): %s. Continuing without cache.",
            settings.REDIS_STARTUP_MAX_RETRIES,
            exc,
        )
    else:
        if FastAPICache is None or RedisBackend is None:
            logger.warning(
                "fastapi-cache2 is not installed. Continuing without API cache."
            )
        else:
            FastAPICache.init(
                RedisBackend(redis_client),
                prefix="spm-cache",
            )

    yield

    # ─── Shutdown ──────────────────────────────────────────────
    await close_redis()


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version="2.0.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_origin_regex=settings.ALLOWED_ORIGIN_REGEX,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
