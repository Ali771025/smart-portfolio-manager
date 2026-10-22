"""
Model registry — import all models so Alembic detects them.
"""

from app.core.database import Base                          # noqa: F401
from app.models.user import User                            # noqa: F401
from app.models.portfolio import Portfolio                  # noqa: F401
from app.models.asset import Asset                          # noqa: F401
from app.models.asset_position import AssetPosition         # noqa: F401
from app.models.asset_position import PortfolioAsset        # noqa: F401
from app.models.transaction import Transaction              # noqa: F401
from app.models.transaction import Trade                    # noqa: F401
from app.models.corporate_action import CorporateAction     # noqa: F401
from app.models.corporate_action import DividendTransaction # noqa: F401
from app.models.corporate_action import CorporateActionExecution  # noqa: F401
from app.models.market_data import DailyPrice              # noqa: F401
from app.models.market_data import AssetPriceHistory        # noqa: F401
from app.models.market_data import BenchmarkHistory         # noqa: F401
from app.models.market_data import PortfolioSnapshot        # noqa: F401
from app.models.market_data import Instrument               # noqa: F401
from app.models.market_data import MarketQuote              # noqa: F401
from app.models.market_data import ClientType               # noqa: F401
from app.models.market_data import OrderBook                # noqa: F401
from app.models.market_data import MarketIndex              # noqa: F401
from app.models.market_data import MarketOverview           # noqa: F401
from app.models.market_data import Disclosure               # noqa: F401
from app.models.market_data import Fund                     # noqa: F401
from app.models.market_data import FundNavHistory           # noqa: F401
from app.models.market_data import IngestionRun             # noqa: F401
from app.models.holding_snapshot import HoldingSnapshot     # noqa: F401
from app.models.manual_transaction import ManualTransaction  # noqa: F401
from app.models.analytics_engine import LedgerEventRecord   # noqa: F401
from app.models.analytics_engine import MarketTick          # noqa: F401
from app.models.analytics_engine import PortfolioAnalyticsSnapshot  # noqa: F401
from app.models.billing import SubscriptionPlan             # noqa: F401
from app.models.billing import UserSubscription             # noqa: F401
from app.models.billing import Invoice                      # noqa: F401
from app.models.import_job import ImportJob                 # noqa: F401
from app.models.uploaded_file import UploadedFile           # noqa: F401
from app.models.cash_transaction import PortfolioCashTransaction  # noqa: F401
from app.models.trade_reconciliation import (  # noqa: F401
    TradeReconciliation,
    TradeReconciliationAllocation,
    TradeReconciliationAuditEvent,
)
