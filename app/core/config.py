"""Application settings for API, scheduler, and market sync."""

from __future__ import annotations

from functools import lru_cache

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    APP_NAME: str = "Smart Portfolio Manager"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    SECRET_KEY: str = "change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    TEST_ADMIN_BOOTSTRAP_ENABLED: bool = False
    TEST_ADMIN_EMAIL: str = "admin@test.local"
    TEST_ADMIN_PASSWORD: str = ""
    TEST_ADMIN_FULL_NAME: str = "Test Admin"

    DATABASE_URL: str = "postgresql+asyncpg://portfolio_user:replace-locally@localhost:5432/portfolio_demo"
    DB_ECHO: bool = False
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 1800

    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_PRICE_PREFIX: str = "price:"
    REDIS_PRICE_TTL_SECONDS: int = 300
    REDIS_LIVE_PRICE_TTL_SECONDS: int = 60
    REDIS_STARTUP_MAX_RETRIES: int = 3
    REDIS_STARTUP_RETRY_DELAY_SECONDS: float = 1.0

    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    CELERY_TIMEZONE: str = "Asia/Tehran"
    CELERY_MARKET_SYNC_CRON: str = "*/1 * * * *"
    CELERY_BENCHMARK_SYNC_CRON: str = "30 16 * * 1-5"
    CELERY_CODAL_SYNC_CRON: str = "*/15 * * * *"
    CELERY_TASK_SOFT_TIME_LIMIT_SECONDS: int = 45

    TSETMC_BASE_URL: str = "https://cdn.tsetmc.com/api"
    TSETMC_MAX_CONCURRENT: int = 10
    TSETMC_REQUEST_TIMEOUT: float = 15.0
    TSETMC_CONNECT_TIMEOUT: float = 5.0
    TSETMC_RETRY_ATTEMPTS: int = 3
    TSETMC_RETRY_BASE_DELAY: float = 1.0
    TSETMC_RETRY_MAX_DELAY: float = 30.0
    TSETMC_RETRY_BACKOFF_MULTIPLIER: float = 2.0
    TSETMC_SANITY_MAX_DROP_PCT: float = 50.0
    TSETMC_SANITY_MAX_RISE_PCT: float = 100.0
    TSETMC_SYNC_INTERVAL_MINUTES: int = 15
    TSETMC_HEALTH_CHECK_INTERVAL_SECONDS: float = 300.0
    TSETMC_CIRCUIT_BREAKER_FAILURE_THRESHOLD: int = 9
    TSETMC_CIRCUIT_BREAKER_RESET_SECONDS: float = 60.0

    CODAL_BASE_URL: str = "https://search.codal.ir"
    CODAL_SEARCH_PATH: str = "/api/search/v2/q"
    CODAL_REQUEST_TIMEOUT: float = 20.0
    CODAL_CRAWLER_PAGE_SIZE: int = 50
    CODAL_CACHE_LIMIT: int = 100

    FIPIRAN_PROVIDER_MODE: str = "auto"
    FIPIRAN_LIBRARY_MODULE: str = "fipiran"
    FIPIRAN_FUNDS_CALLABLE: str = ""
    FIPIRAN_NAV_CALLABLE: str = ""
    FIPIRAN_RETURNS_CALLABLE: str = ""
    FIPIRAN_SYNC_CRON: str = "15 17 * * *"

    BENCHMARK_GOLD18_API_URL: str = "https://api.example.com/iran/gold18k"
    BENCHMARK_USD_IRR_API_URL: str = "https://api.example.com/iran/usd-irr"
    TEDPIX_INS_CODE: str = "32097828799138957"
    TSETMC_TOTAL_INDEX_INS_CODE: str = "32097828799138957"
    TSETMC_EQUAL_WEIGHT_INDEX_INS_CODE: str = "67130298613737946"
    TEHRAN_MARKET_OPEN_TIME: str = "07:30"
    TEHRAN_MARKET_CLOSE_TIME: str = "13:00"
    TEHRAN_MARKET_HOLIDAYS: str = ""
    MARKET_CIRCUIT_BREAKER_FAILURE_THRESHOLD: int = 10
    MARKET_CIRCUIT_BREAKER_RESET_SECONDS: int = 120

    # Risk-free / Fixed-income benchmark configuration
    # Configurable risk-free rate for benchmark comparison
    # Default: 23% annual rate (Iranian bank deposit rate)
    RISK_FREE_ANNUAL_RATE: float = 23.0
    RISK_FREE_BENCHMARK_NAME: str = "نرخ سود بانکی"
    RISK_FREE_DESCRIPTION: str = "نرخ سود سپرده بانکی (قابل پیکربندی)"
    RISK_FREE_BENCHMARK_MODE: str = "configured_rate"
    RISK_FREE_FUND_ID: str = ""
    RISK_FREE_ALLOW_CONFIGURED_FALLBACK: bool = True

    # File Upload Storage
    UPLOAD_STORAGE_ROOT: str = "/tmp/portfolio_uploads"

    ALLOWED_ORIGINS: list[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080"],
        validation_alias=AliasChoices("ALLOWED_ORIGINS", "CORS_ORIGINS"),
    )
    ALLOWED_ORIGIN_REGEX: str = Field(
        default=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        validation_alias=AliasChoices("ALLOWED_ORIGIN_REGEX", "CORS_ORIGIN_REGEX"),
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
