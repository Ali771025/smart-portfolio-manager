class PositionWithMarketData {
  const PositionWithMarketData({
    required this.id,
    required this.assetId,
    required this.tickerSymbol,
    required this.assetName,
    required this.totalQuantity,
    required this.totalCostBasis,
    required this.currentPrice,
    required this.lastPrice,
    required this.closingPrice,
    required this.currentMarketValue,
    required this.dailyPnl,
    required this.unrealizedPnl,
    required this.unrealizedPnlPct,
    required this.weightPct,
    this.selectedValuationPrice,
    this.selectedPriceSource = 'missing',
    this.priceAsOf,
    this.isStale = true,
    this.isCurrentSession = false,
    this.status = 'unknown',
    this.lastMarketUpdate,
  });

  final String id;
  final String assetId;
  final String tickerSymbol;
  final String assetName;
  final double totalQuantity;
  final double totalCostBasis;
  final double currentPrice;
  final double lastPrice;
  final double closingPrice;
  final double currentMarketValue;
  final double dailyPnl;
  final double unrealizedPnl;
  final double unrealizedPnlPct;
  final double weightPct;
  final double? selectedValuationPrice;
  final String selectedPriceSource;
  final DateTime? priceAsOf;
  final bool isStale;
  final bool isCurrentSession;
  final String status;
  final DateTime? lastMarketUpdate;

  PositionWithMarketData copyWith({
    String? id,
    String? assetId,
    String? tickerSymbol,
    String? assetName,
    double? totalQuantity,
    double? totalCostBasis,
    double? currentPrice,
    double? lastPrice,
    double? closingPrice,
    double? currentMarketValue,
    double? dailyPnl,
    double? unrealizedPnl,
    double? unrealizedPnlPct,
    double? weightPct,
    double? selectedValuationPrice,
    String? selectedPriceSource,
    DateTime? priceAsOf,
    bool? isStale,
    bool? isCurrentSession,
    String? status,
    DateTime? lastMarketUpdate,
  }) {
    return PositionWithMarketData(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      tickerSymbol: tickerSymbol ?? this.tickerSymbol,
      assetName: assetName ?? this.assetName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalCostBasis: totalCostBasis ?? this.totalCostBasis,
      currentPrice: currentPrice ?? this.currentPrice,
      lastPrice: lastPrice ?? this.lastPrice,
      closingPrice: closingPrice ?? this.closingPrice,
      currentMarketValue: currentMarketValue ?? this.currentMarketValue,
      dailyPnl: dailyPnl ?? this.dailyPnl,
      unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
      unrealizedPnlPct: unrealizedPnlPct ?? this.unrealizedPnlPct,
      weightPct: weightPct ?? this.weightPct,
      selectedValuationPrice:
          selectedValuationPrice ?? this.selectedValuationPrice,
      selectedPriceSource: selectedPriceSource ?? this.selectedPriceSource,
      priceAsOf: priceAsOf ?? this.priceAsOf,
      isStale: isStale ?? this.isStale,
      isCurrentSession: isCurrentSession ?? this.isCurrentSession,
      status: status ?? this.status,
      lastMarketUpdate: lastMarketUpdate ?? this.lastMarketUpdate,
    );
  }

  factory PositionWithMarketData.fromJson(Map<String, dynamic> json) {
    final lastPrice = _asDouble(
      _read(json, 'last_price', 'lastPrice') ??
          _read(json, 'current_price', 'currentPrice') ??
          _read(json, 'latest_price', 'latestPrice'),
    );
    final closingPrice = _asDouble(
      _read(json, 'closing_price', 'closingPrice') ??
          _read(json, 'close_price', 'closePrice'),
    );
    final selectedPrice = _asNullableDouble(
      _read(json, 'selected_valuation_price', 'selectedValuationPrice') ??
          _read(json, 'current_price', 'currentPrice'),
    );
    final priceAsOf = _asDate(
      _read(json, 'price_as_of', 'priceAsOf') ??
          _read(json, 'last_market_update', 'lastMarketUpdate') ??
          _read(json, 'last_updated_at', 'lastUpdatedAt'),
    );
    return PositionWithMarketData(
      id: _read(json, 'id')?.toString() ?? '',
      assetId: _read(json, 'asset_id', 'assetId')?.toString() ?? '',
      tickerSymbol:
          _read(json, 'ticker_symbol', 'tickerSymbol')?.toString() ?? '',
      assetName: _read(json, 'asset_name', 'assetName')?.toString() ?? '',
      totalQuantity: _asDouble(
        _read(json, 'total_quantity', 'totalQuantity') ??
            _read(json, 'quantity'),
      ),
      totalCostBasis: _asDouble(
        _read(json, 'total_cost_basis', 'totalCostBasis') ??
            _read(json, 'total_cost', 'totalCost'),
      ),
      currentPrice: selectedPrice ?? 0,
      lastPrice: lastPrice,
      closingPrice: closingPrice,
      currentMarketValue: _asDouble(
        _read(json, 'current_market_value', 'currentMarketValue') ??
            _read(json, 'market_value', 'marketValue'),
      ),
      dailyPnl: _asDouble(_read(json, 'daily_pnl', 'dailyPnl')),
      unrealizedPnl: _asDouble(_read(json, 'unrealized_pnl', 'unrealizedPnl')),
      unrealizedPnlPct: _asDouble(
        _read(json, 'unrealized_pnl_pct', 'unrealizedPnlPct') ??
            _read(json, 'unrealized_pnl_percent', 'unrealizedPnlPercent'),
      ),
      weightPct: _asDouble(_read(json, 'weight_pct', 'weightPct')),
      selectedValuationPrice: selectedPrice,
      selectedPriceSource:
          _read(json, 'selected_price_source', 'selectedPriceSource')
                  ?.toString() ??
              'missing',
      priceAsOf: priceAsOf,
      isStale: _asBool(_read(json, 'is_stale', 'isStale'), fallback: true),
      isCurrentSession: _asBool(
        _read(json, 'is_current_session', 'isCurrentSession'),
      ),
      status: _read(json, 'status')?.toString() ?? 'unknown',
      lastMarketUpdate: priceAsOf,
    );
  }
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.portfolioId,
    required this.portfolioName,
    required this.baseCurrency,
    required this.totalCurrentValue,
    required this.totalInvestedValue,
    required this.totalUnrealizedPnl,
    required this.dailyPnl,
    required this.totalUnrealizedPnlPct,
    required this.totalRealizedPnl,
    required this.totalPnl,
    required this.roiPct,
    required this.activePositionsCount,
    required this.totalTradesCount,
    required this.positions,
    this.totalCostBasis,
    this.totalMarketValue,
    this.missingPriceCount = 0,
    this.stalePriceCount = 0,
    this.asOf,
    this.marketStatus = 'unknown',
    this.dataQualityStatus = 'unknown',
    this.currentPrice,
    this.closingPrice,
    this.lastMarketUpdate,
  });

  final String portfolioId;
  final String portfolioName;
  final String baseCurrency;
  final double totalCurrentValue;
  final double totalInvestedValue;
  final double totalUnrealizedPnl;
  final double dailyPnl;
  final double totalUnrealizedPnlPct;
  final double totalRealizedPnl;
  final double totalPnl;
  final double roiPct;
  final int activePositionsCount;
  final int totalTradesCount;
  final List<PositionWithMarketData> positions;
  final double? totalCostBasis;
  final double? totalMarketValue;
  final int missingPriceCount;
  final int stalePriceCount;
  final DateTime? asOf;
  final String marketStatus;
  final String dataQualityStatus;
  final double? currentPrice;
  final double? closingPrice;
  final DateTime? lastMarketUpdate;

  PortfolioSummary copyWith({
    String? portfolioId,
    String? portfolioName,
    String? baseCurrency,
    double? totalCurrentValue,
    double? totalInvestedValue,
    double? totalUnrealizedPnl,
    double? dailyPnl,
    double? totalUnrealizedPnlPct,
    double? totalRealizedPnl,
    double? totalPnl,
    double? roiPct,
    int? activePositionsCount,
    int? totalTradesCount,
    List<PositionWithMarketData>? positions,
    double? totalCostBasis,
    double? totalMarketValue,
    int? missingPriceCount,
    int? stalePriceCount,
    DateTime? asOf,
    String? marketStatus,
    String? dataQualityStatus,
    double? currentPrice,
    double? closingPrice,
    DateTime? lastMarketUpdate,
  }) {
    return PortfolioSummary(
      portfolioId: portfolioId ?? this.portfolioId,
      portfolioName: portfolioName ?? this.portfolioName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      totalCurrentValue: totalCurrentValue ?? this.totalCurrentValue,
      totalInvestedValue: totalInvestedValue ?? this.totalInvestedValue,
      totalUnrealizedPnl: totalUnrealizedPnl ?? this.totalUnrealizedPnl,
      dailyPnl: dailyPnl ?? this.dailyPnl,
      totalUnrealizedPnlPct:
          totalUnrealizedPnlPct ?? this.totalUnrealizedPnlPct,
      totalRealizedPnl: totalRealizedPnl ?? this.totalRealizedPnl,
      totalPnl: totalPnl ?? this.totalPnl,
      roiPct: roiPct ?? this.roiPct,
      activePositionsCount: activePositionsCount ?? this.activePositionsCount,
      totalTradesCount: totalTradesCount ?? this.totalTradesCount,
      positions: positions ?? this.positions,
      totalCostBasis: totalCostBasis ?? this.totalCostBasis,
      totalMarketValue: totalMarketValue ?? this.totalMarketValue,
      missingPriceCount: missingPriceCount ?? this.missingPriceCount,
      stalePriceCount: stalePriceCount ?? this.stalePriceCount,
      asOf: asOf ?? this.asOf,
      marketStatus: marketStatus ?? this.marketStatus,
      dataQualityStatus: dataQualityStatus ?? this.dataQualityStatus,
      currentPrice: currentPrice ?? this.currentPrice,
      closingPrice: closingPrice ?? this.closingPrice,
      lastMarketUpdate: lastMarketUpdate ?? this.lastMarketUpdate,
    );
  }

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    final positionsJson = (json['positions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return PortfolioSummary(
      portfolioId: _read(json, 'portfolio_id', 'portfolioId')?.toString() ?? '',
      portfolioName:
          _read(json, 'portfolio_name', 'portfolioName')?.toString() ?? '',
      baseCurrency:
          _read(json, 'base_currency', 'baseCurrency')?.toString() ?? 'IRR',
      totalCurrentValue: _asDouble(
        _read(json, 'total_current_value', 'totalCurrentValue') ??
            _read(json, 'total_market_value', 'totalMarketValue'),
      ),
      totalInvestedValue: _asDouble(
        _read(json, 'total_invested_value', 'totalInvestedValue') ??
            _read(json, 'total_cost_basis', 'totalCostBasis'),
      ),
      totalUnrealizedPnl:
          _asDouble(_read(json, 'total_unrealized_pnl', 'totalUnrealizedPnl')),
      dailyPnl: _asDouble(_read(json, 'daily_pnl', 'dailyPnl')),
      totalUnrealizedPnlPct: _asDouble(
          _read(json, 'total_unrealized_pnl_pct', 'totalUnrealizedPnlPct')),
      totalRealizedPnl:
          _asDouble(_read(json, 'total_realized_pnl', 'totalRealizedPnl')),
      totalPnl: _asDouble(_read(json, 'total_pnl', 'totalPnl')),
      roiPct: _asDouble(_read(json, 'roi_pct', 'roiPct')),
      activePositionsCount:
          (_read(json, 'active_positions_count', 'activePositionsCount')
                      as num?)
                  ?.toInt() ??
              0,
      totalTradesCount:
          (_read(json, 'total_trades_count', 'totalTradesCount') as num?)
                  ?.toInt() ??
              0,
      positions: positionsJson
          .map(PositionWithMarketData.fromJson)
          .toList(growable: false),
      totalCostBasis:
          _asNullableDouble(_read(json, 'total_cost_basis', 'totalCostBasis')),
      totalMarketValue: _asNullableDouble(
          _read(json, 'total_market_value', 'totalMarketValue')),
      missingPriceCount: _asInt(
        _read(json, 'missing_price_count', 'missingPriceCount'),
      ),
      stalePriceCount:
          _asInt(_read(json, 'stale_price_count', 'stalePriceCount')),
      asOf: _asDate(_read(json, 'as_of', 'asOf')),
      marketStatus:
          _read(json, 'market_status', 'marketStatus')?.toString() ?? 'unknown',
      dataQualityStatus:
          _read(json, 'data_quality_status', 'dataQualityStatus')?.toString() ??
              'unknown',
      currentPrice:
          _asNullableDouble(_read(json, 'current_price', 'currentPrice')),
      closingPrice:
          _asNullableDouble(_read(json, 'closing_price', 'closingPrice')),
      lastMarketUpdate: _asDate(
        _read(json, 'last_market_update', 'lastMarketUpdate') ??
            _read(json, 'last_updated_at', 'lastUpdatedAt'),
      ),
    );
  }
}

Object? _read(Map<String, dynamic> json, String key, [String? fallbackKey]) {
  if (json.containsKey(key)) {
    return json[key];
  }
  if (fallbackKey != null && json.containsKey(fallbackKey)) {
    return json[fallbackKey];
  }
  return null;
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase().trim();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value.toString());
  if (parsed == null || parsed.isNaN || !parsed.isFinite) {
    return null;
  }
  return parsed;
}

DateTime? _asDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toUtc();
}
