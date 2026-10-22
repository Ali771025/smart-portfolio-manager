"""Additions to the existing enums file."""

import enum


class AssetType(str, enum.Enum):
    STOCK = "STOCK"
    ETF = "ETF"
    BOND = "BOND"
    MUTUAL_FUND = "MUTUAL_FUND"
    CRYPTO = "CRYPTO"
    COMMODITY = "COMMODITY"
    OPTION = "OPTION"
    FUTURES = "FUTURES"


class TransactionType(str, enum.Enum):
    BUY = "BUY"
    SELL = "SELL"
    CAPITAL_INCREASE_BONUS = "CAPITAL_INCREASE_BONUS"
    STOCK_SPLIT = "STOCK_SPLIT"
    PRE_EMPTIVE_RIGHTS = "PRE_EMPTIVE_RIGHTS"
    CASH_DIVIDEND = "CASH_DIVIDEND"
    ASSET_TRANSFER = "ASSET_TRANSFER"


class LedgerEventType(str, enum.Enum):
    TRADE_BUY = "TRADE_BUY"
    TRADE_SELL = "TRADE_SELL"
    CASH_DEPOSIT = "CASH_DEPOSIT"
    CASH_WITHDRAWAL = "CASH_WITHDRAWAL"
    CORPORATE_ACTION = "CORPORATE_ACTION"
    FEE = "FEE"


class InventoryAccountingMethod(str, enum.Enum):
    WAC = "WAC"
    FIFO = "FIFO"


class ReconciliationStatus(str, enum.Enum):
    SUGGESTED = "SUGGESTED"
    CONFIRMED = "CONFIRMED"
    REJECTED = "REJECTED"
    CANCELED = "CANCELED"
    EXPIRED = "EXPIRED"


class ReconciliationMatchingMethod(str, enum.Enum):
    AUTO = "AUTO"
    MANUAL = "MANUAL"


class ReconciliationAuditAction(str, enum.Enum):
    CREATED = "CREATED"
    ALLOCATION_ADDED = "ALLOCATION_ADDED"
    CONFIRMED = "CONFIRMED"
    REJECTED = "REJECTED"
    CANCELED = "CANCELED"


class ImportJobStatus(str, enum.Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class CorporateActionType(str, enum.Enum):
    STOCK_SPLIT = "STOCK_SPLIT"
    CASH_DIVIDEND = "CASH_DIVIDEND"
    STOCK_DIVIDEND = "STOCK_DIVIDEND"
    RIGHTS_ISSUE = "RIGHTS_ISSUE"
    CAPITAL_INCREASE = "CAPITAL_INCREASE"


class PortfolioCurrency(str, enum.Enum):
    IRR = "IRR"
    USD = "USD"
    EUR = "EUR"


class PortfolioManagerType(str, enum.Enum):
    AGAH = "AGAH"
    MOFID = "MOFID"
    BOURSIRAN = "BOURSIRAN"
    UNKNOWN = "UNKNOWN"


class SubscriptionTier(str, enum.Enum):
    FREE = "FREE"
    PRO = "PRO"
    ENTERPRISE = "ENTERPRISE"


class SubscriptionStatus(str, enum.Enum):
    TRIALING = "TRIALING"
    ACTIVE = "ACTIVE"
    PAST_DUE = "PAST_DUE"
    CANCELED = "CANCELED"
    EXPIRED = "EXPIRED"


class InvoiceStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    OPEN = "OPEN"
    PAID = "PAID"
    VOID = "VOID"
    UNCOLLECTIBLE = "UNCOLLECTIBLE"


class SyncStatus(str, enum.Enum):
    """Status of each ticker during a sync cycle."""
    SUCCESS = "SUCCESS"
    SKIPPED_SANITY = "SKIPPED_SANITY"
    SKIPPED_ZERO = "SKIPPED_ZERO"
    FAILED_TIMEOUT = "FAILED_TIMEOUT"
    FAILED_HTTP = "FAILED_HTTP"
    FAILED_PARSE = "FAILED_PARSE"


class BenchmarkType(str, enum.Enum):
    """Supported benchmark series for Iranian market comparison."""

    GOLD_18K = "GOLD_18K"
    USD_IRR = "USD_IRR"
    TEDPIX = "TEDPIX"
    RISK_FREE = "RISK_FREE"  # Configurable risk-free rate benchmark
