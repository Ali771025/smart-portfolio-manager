/// Models for portfolio chart data, symbol analytics, PnL, and benchmark comparison.
///
/// All models use plain Dart classes with hand-written `fromJson` following
/// the established pattern (no freezed). Nullable doubles for financial values.
library;

double _parseDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? _parseNullableDouble(dynamic v) {
  if (v == null) return null;
  final parsed = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (parsed == null || parsed.isNaN || !parsed.isFinite) return null;
  return parsed;
}

bool _parseBool(dynamic value, {bool fallback = false}) {
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

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

Object? _read(Map<String, dynamic> json, String snakeKey, [String? camelKey]) {
  if (json.containsKey(snakeKey)) return json[snakeKey];
  if (camelKey != null && json.containsKey(camelKey)) return json[camelKey];
  return null;
}

/// ─── Chart Period Enum ────────────────────────────────────────

enum ChartPeriod {
  oneMonth('1M'),
  threeMonths('3M'),
  sixMonths('6M'),
  oneYear('1Y'),
  ytd('YTD'),
  all('ALL'),
  custom('CUSTOM');

  const ChartPeriod(this.apiValue);
  final String apiValue;
}

/// ─── Chart Metadata ───────────────────────────────────────────

class ChartMetadata {
  const ChartMetadata({
    required this.chartType,
    required this.title,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.asOfTimestamp,
    this.baseCurrency = 'IRR',
    this.totalDataPoints = 0,
    this.availableDataPoints = 0,
    this.completeness = 'complete',
    this.missingSymbols = const [],
  });

  final String chartType;
  final String title;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime asOfTimestamp;
  final String baseCurrency;
  final int totalDataPoints;
  final int availableDataPoints;
  final String completeness;
  final List<String> missingSymbols;

  factory ChartMetadata.fromJson(Map<String, dynamic> json) {
    return ChartMetadata(
      chartType: json['chart_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      period: json['period'] as String? ?? '',
      startDate: _parseDate(json['start_date']) ?? DateTime.now(),
      endDate: _parseDate(json['end_date']) ?? DateTime.now(),
      asOfTimestamp: _parseDate(json['as_of_timestamp']) ?? DateTime.now(),
      baseCurrency: json['base_currency'] as String? ?? 'IRR',
      totalDataPoints: (json['total_data_points'] as num?)?.toInt() ?? 0,
      availableDataPoints:
          (json['available_data_points'] as num?)?.toInt() ?? 0,
      completeness: json['completeness'] as String? ?? 'complete',
      missingSymbols: (json['missing_symbols'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// ─── Chart Series ─────────────────────────────────────────────

class ChartSeriesPoint {
  const ChartSeriesPoint({
    required this.date,
    this.value,
    this.secondaryValue,
  });

  final DateTime date;
  final double? value;
  final double? secondaryValue;

  factory ChartSeriesPoint.fromJson(Map<String, dynamic> json) {
    return ChartSeriesPoint(
      date: _parseDate(json['point_date'] ?? json['date']) ?? DateTime.now(),
      value: _parseNullableDouble(json['value']),
      secondaryValue: _parseNullableDouble(json['secondary_value']),
    );
  }
}

class ChartSeries {
  const ChartSeries({
    required this.key,
    required this.name,
    this.valueType = 'currency',
    this.dataPoints = const [],
    this.isBenchmark = false,
  });

  final String key;
  final String name;
  final String valueType;
  final List<ChartSeriesPoint> dataPoints;
  final bool isBenchmark;

  factory ChartSeries.fromJson(Map<String, dynamic> json) {
    return ChartSeries(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      valueType: json['value_type'] as String? ?? 'currency',
      dataPoints: (json['data_points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChartSeriesPoint.fromJson)
          .toList(),
      isBenchmark: json['is_benchmark'] as bool? ?? false,
    );
  }
}

/// ─── Generic Chart Response ───────────────────────────────────

class PortfolioChartResponse {
  const PortfolioChartResponse({
    required this.portfolioId,
    required this.metadata,
    this.series = const [],
  });

  final String portfolioId;
  final ChartMetadata metadata;
  final List<ChartSeries> series;

  factory PortfolioChartResponse.fromJson(Map<String, dynamic> json) {
    return PortfolioChartResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      metadata: ChartMetadata.fromJson(
          (json['metadata'] as Map<String, dynamic>? ?? {})),
      series: (json['series'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChartSeries.fromJson)
          .toList(),
    );
  }
}

/// ─── Capital Growth Response ──────────────────────────────────

class CapitalGrowthPoint {
  const CapitalGrowthPoint({
    required this.date,
    this.portfolioValue,
    this.costBasis,
    this.totalPnl,
    this.roiPct,
  });

  final DateTime date;
  final double? portfolioValue;
  final double? costBasis;
  final double? totalPnl;
  final double? roiPct;

  factory CapitalGrowthPoint.fromJson(Map<String, dynamic> json) {
    return CapitalGrowthPoint(
      date: _parseDate(json['point_date'] ?? json['date']) ?? DateTime.now(),
      portfolioValue: _parseNullableDouble(json['portfolio_value']),
      costBasis: _parseNullableDouble(json['cost_basis']),
      totalPnl: _parseNullableDouble(json['total_pnl']),
      roiPct: _parseNullableDouble(json['roi_pct']),
    );
  }
}

class CapitalGrowthResponse {
  const CapitalGrowthResponse({
    required this.portfolioId,
    required this.metadata,
    this.points = const [],
  });

  final String portfolioId;
  final ChartMetadata metadata;
  final List<CapitalGrowthPoint> points;

  factory CapitalGrowthResponse.fromJson(Map<String, dynamic> json) {
    return CapitalGrowthResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      metadata: ChartMetadata.fromJson(
          (json['metadata'] as Map<String, dynamic>? ?? {})),
      points: (json['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CapitalGrowthPoint.fromJson)
          .toList(),
    );
  }
}

/// ─── Monthly Returns Response ─────────────────────────────────

class MonthlyReturnPoint {
  const MonthlyReturnPoint({
    required this.year,
    required this.month,
    this.monthLabel = '',
    this.returnPct,
    this.cumulativePct,
  });

  final int year;
  final int month;
  final String monthLabel;
  final double? returnPct;
  final double? cumulativePct;

  factory MonthlyReturnPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyReturnPoint(
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      monthLabel: json['month_label'] as String? ?? '',
      returnPct: _parseNullableDouble(json['return_pct']),
      cumulativePct: _parseNullableDouble(json['cumulative_pct']),
    );
  }
}

class MonthlyReturnsResponse {
  const MonthlyReturnsResponse({
    required this.portfolioId,
    required this.metadata,
    this.symbols = const [],
    this.monthlyReturns = const {},
    this.portfolioMonthlyReturns = const [],
  });

  final String portfolioId;
  final ChartMetadata metadata;
  final List<String> symbols;
  final Map<String, List<MonthlyReturnPoint>> monthlyReturns;
  final List<MonthlyReturnPoint> portfolioMonthlyReturns;

  factory MonthlyReturnsResponse.fromJson(Map<String, dynamic> json) {
    final rawMonthly = json['monthly_returns'] as Map<String, dynamic>? ?? {};
    final parsed = <String, List<MonthlyReturnPoint>>{};
    rawMonthly.forEach((key, value) {
      if (value is List) {
        parsed[key] = value
            .whereType<Map<String, dynamic>>()
            .map(MonthlyReturnPoint.fromJson)
            .toList();
      }
    });

    return MonthlyReturnsResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      metadata: ChartMetadata.fromJson(
          (json['metadata'] as Map<String, dynamic>? ?? {})),
      symbols: (json['symbols'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      monthlyReturns: parsed,
      portfolioMonthlyReturns:
          (json['portfolio_monthly_returns'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(MonthlyReturnPoint.fromJson)
              .toList(),
    );
  }
}

/// ─── Portfolio Holdings (Symbol List) ─────────────────────────

class PortfolioHoldingItem {
  const PortfolioHoldingItem({
    required this.assetId,
    required this.tickerSymbol,
    this.assetName = '',
    this.quantity = 0,
    this.weightedAvgCost = 0,
    this.totalCostBasis = 0,
    this.currentPrice,
    this.lastPrice,
    this.closingPrice,
    this.selectedValuationPrice,
    this.selectedPriceSource = 'missing',
    this.currentValue,
    this.dailyPnl,
    this.priceChange,
    this.priceChangePercent,
    this.unrealizedPnl,
    this.unrealizedPnlPct,
    this.weightPct = 0,
    this.isPriceFresh = true,
    this.isStale = true,
    this.isCurrentSession = false,
    this.marketStatus = 'unknown',
    this.missingPrice = false,
    this.insufficientData = false,
    this.isTradeable = true,
    this.priceStatus = 'ok',
    this.priceAsOf,
    this.lastUpdatedAt,
  });

  final String assetId;
  final String tickerSymbol;
  final String assetName;
  final double quantity;
  final double weightedAvgCost;
  final double totalCostBasis;
  final double? currentPrice;
  final double? lastPrice;
  final double? closingPrice;
  final double? selectedValuationPrice;
  final String selectedPriceSource;
  final double? currentValue;
  final double? dailyPnl;
  final double? priceChange;
  final double? priceChangePercent;
  final double? unrealizedPnl;
  final double? unrealizedPnlPct;
  final double weightPct;
  final bool isPriceFresh;
  final bool isStale;
  final bool isCurrentSession;
  final String marketStatus;
  final bool missingPrice;
  final bool insufficientData;
  final bool isTradeable;
  final String priceStatus;
  final DateTime? priceAsOf;
  final DateTime? lastUpdatedAt;

  factory PortfolioHoldingItem.fromJson(Map<String, dynamic> json) {
    final lastPrice = _parseNullableDouble(
      _read(json, 'last_price', 'lastPrice') ??
          _read(json, 'current_price', 'currentPrice') ??
          _read(json, 'latest_price', 'latestPrice'),
    );
    final status = _read(json, 'price_status', 'priceStatus')?.toString() ??
        _read(json, 'data_status', 'dataStatus')?.toString() ??
        _read(json, 'status')?.toString() ??
        'ok';
    return PortfolioHoldingItem(
      assetId: _read(json, 'asset_id', 'assetId')?.toString() ?? '',
      tickerSymbol: _read(json, 'ticker_symbol', 'tickerSymbol')?.toString() ??
          _read(json, 'symbol')?.toString() ??
          '',
      assetName: _read(json, 'asset_name', 'assetName')?.toString() ??
          _read(json, 'name')?.toString() ??
          '',
      quantity: _parseDouble(_read(json, 'quantity')),
      weightedAvgCost: _parseDouble(
        _read(json, 'weighted_avg_cost', 'weightedAvgCost') ??
            _read(json, 'average_cost', 'averageCost'),
      ),
      totalCostBasis: _parseDouble(
        _read(json, 'total_cost_basis', 'totalCostBasis') ??
            _read(json, 'cost_basis', 'costBasis') ??
            _read(json, 'remaining_cost_basis', 'remainingCostBasis'),
      ),
      currentPrice: _parseNullableDouble(
        _read(json, 'current_price', 'currentPrice') ?? lastPrice,
      ),
      lastPrice: lastPrice,
      closingPrice: _parseNullableDouble(
        _read(json, 'closing_price', 'closingPrice') ??
            _read(json, 'close_price', 'closePrice'),
      ),
      selectedValuationPrice: _parseNullableDouble(
        _read(json, 'selected_valuation_price', 'selectedValuationPrice') ??
            _read(json, 'selected_price', 'selectedPrice') ??
            _read(json, 'current_price', 'currentPrice'),
      ),
      selectedPriceSource:
          _read(json, 'selected_price_source', 'selectedPriceSource')
                  ?.toString() ??
              _read(json, 'price_source', 'priceSource')?.toString() ??
              _read(json, 'current_price_source', 'currentPriceSource')
                  ?.toString() ??
              'missing',
      currentValue: _parseNullableDouble(
        _read(json, 'current_value', 'currentValue') ??
            _read(json, 'market_value', 'marketValue'),
      ),
      dailyPnl: _parseNullableDouble(_read(json, 'daily_pnl', 'dailyPnl')),
      priceChange:
          _parseNullableDouble(_read(json, 'price_change', 'priceChange')),
      priceChangePercent: _parseNullableDouble(
        _read(json, 'price_change_percent', 'priceChangePercent') ??
            _read(json, 'price_change_pct', 'priceChangePct'),
      ),
      unrealizedPnl:
          _parseNullableDouble(_read(json, 'unrealized_pnl', 'unrealizedPnl')),
      unrealizedPnlPct: _parseNullableDouble(
        _read(json, 'unrealized_pnl_pct', 'unrealizedPnlPct') ??
            _read(json, 'unrealized_pnl_percent', 'unrealizedPnlPercent'),
      ),
      weightPct: _parseDouble(_read(json, 'weight_pct', 'weightPct')),
      isPriceFresh:
          _read(json, 'is_price_fresh', 'isPriceFresh') as bool? ?? true,
      isStale: _parseBool(_read(json, 'is_stale', 'isStale'), fallback: true),
      isCurrentSession: _parseBool(
        _read(json, 'is_current_session', 'isCurrentSession'),
      ),
      marketStatus:
          _read(json, 'market_status', 'marketStatus')?.toString() ?? 'unknown',
      missingPrice: _parseBool(
        _read(json, 'missing_price', 'missingPrice'),
        fallback: status == 'missing_price' || status == 'missing_market_price',
      ),
      insufficientData: _parseBool(
        _read(json, 'insufficient_data', 'insufficientData'),
      ),
      isTradeable: _read(json, 'is_tradeable', 'isTradeable') as bool? ?? true,
      priceStatus: status,
      priceAsOf: _parseDate(
        _read(json, 'price_as_of', 'priceAsOf') ??
            _read(json, 'price_date', 'priceDate') ??
            _read(json, 'current_price_date', 'currentPriceDate'),
      ),
      lastUpdatedAt: _parseDate(
        _read(json, 'last_updated_at', 'lastUpdatedAt') ??
            _read(json, 'last_market_update', 'lastMarketUpdate') ??
            _read(json, 'price_as_of', 'priceAsOf') ??
            _read(json, 'price_date', 'priceDate') ??
            _read(json, 'price_timestamp', 'priceTimestamp'),
      ),
    );
  }
}

class PortfolioHoldingsListResponse {
  const PortfolioHoldingsListResponse({
    required this.portfolioId,
    this.totalCurrentValue = 0,
    this.holdings = const [],
    this.marketStatus = 'unknown',
    this.dataQualityStatus = 'unknown',
    this.missingPriceCount = 0,
    this.stalePriceCount = 0,
    this.asOfTimestamp,
  });

  final String portfolioId;
  final double totalCurrentValue;
  final List<PortfolioHoldingItem> holdings;
  final String marketStatus;
  final String dataQualityStatus;
  final int missingPriceCount;
  final int stalePriceCount;
  final DateTime? asOfTimestamp;

  factory PortfolioHoldingsListResponse.fromJson(Map<String, dynamic> json) {
    return PortfolioHoldingsListResponse(
      portfolioId: _read(json, 'portfolio_id', 'portfolioId')?.toString() ?? '',
      totalCurrentValue: _parseDouble(
        json['total_current_value'] ??
            json['total_market_value'] ??
            json['totalMarketValue'],
      ),
      holdings: ((json['holdings'] ?? json['items']) as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PortfolioHoldingItem.fromJson)
          .toList(),
      marketStatus:
          _read(json, 'market_status', 'marketStatus')?.toString() ?? 'unknown',
      dataQualityStatus:
          _read(json, 'data_quality_status', 'dataQualityStatus')?.toString() ??
              'unknown',
      missingPriceCount: (_read(
                  json, 'missing_price_count', 'missingPriceCount') as num?)
              ?.toInt() ??
          (_read(json, 'missing_market_price_count', 'missingMarketPriceCount')
                  as num?)
              ?.toInt() ??
          0,
      stalePriceCount:
          (_read(json, 'stale_price_count', 'stalePriceCount') as num?)
                  ?.toInt() ??
              0,
      asOfTimestamp: _parseDate(
        _read(json, 'as_of_timestamp', 'asOfTimestamp') ??
            _read(json, 'as_of', 'asOf'),
      ),
    );
  }
}

/// ─── Symbol Position Info ─────────────────────────────────────

class SymbolPositionInfo {
  const SymbolPositionInfo({
    required this.assetId,
    required this.tickerSymbol,
    this.assetName = '',
    this.quantity = 0,
    this.weightedAvgCost = 0,
    this.totalCostBasis = 0,
    this.currentPrice,
    this.lastPrice,
    this.closingPrice,
    this.currentValue,
    this.dailyPnl,
    this.priceChange,
    this.priceChangePercent,
    this.unrealizedPnl,
    this.unrealizedPnlPct,
    this.realizedPnl = 0,
    this.isPriceFresh = true,
    this.isTradeable = true,
    this.priceStatus = 'ok',
    this.priceTimestamp,
    this.lastUpdatedAt,
    this.dataFreshnessSeconds,
  });

  final String assetId;
  final String tickerSymbol;
  final String assetName;
  final double quantity;
  final double weightedAvgCost;
  final double totalCostBasis;
  final double? currentPrice;
  final double? lastPrice;
  final double? closingPrice;
  final double? currentValue;
  final double? dailyPnl;
  final double? priceChange;
  final double? priceChangePercent;
  final double? unrealizedPnl;
  final double? unrealizedPnlPct;
  final double realizedPnl;
  final bool isPriceFresh;
  final bool isTradeable;
  final String priceStatus;
  final DateTime? priceTimestamp;
  final DateTime? lastUpdatedAt;
  final int? dataFreshnessSeconds;

  factory SymbolPositionInfo.fromJson(Map<String, dynamic> json) {
    final lastPrice = _parseNullableDouble(
      _read(json, 'last_price', 'lastPrice') ??
          _read(json, 'current_price', 'currentPrice') ??
          _read(json, 'latest_price', 'latestPrice'),
    );
    return SymbolPositionInfo(
      assetId: _read(json, 'asset_id', 'assetId')?.toString() ?? '',
      tickerSymbol:
          _read(json, 'ticker_symbol', 'tickerSymbol')?.toString() ?? '',
      assetName: _read(json, 'asset_name', 'assetName')?.toString() ?? '',
      quantity: _parseDouble(_read(json, 'quantity')),
      weightedAvgCost:
          _parseDouble(_read(json, 'weighted_avg_cost', 'weightedAvgCost')),
      totalCostBasis:
          _parseDouble(_read(json, 'total_cost_basis', 'totalCostBasis')),
      currentPrice: _parseNullableDouble(
        _read(json, 'current_price', 'currentPrice') ?? lastPrice,
      ),
      lastPrice: lastPrice,
      closingPrice: _parseNullableDouble(
        _read(json, 'closing_price', 'closingPrice') ??
            _read(json, 'close_price', 'closePrice'),
      ),
      currentValue:
          _parseNullableDouble(_read(json, 'current_value', 'currentValue')),
      dailyPnl: _parseNullableDouble(_read(json, 'daily_pnl', 'dailyPnl')),
      priceChange:
          _parseNullableDouble(_read(json, 'price_change', 'priceChange')),
      priceChangePercent: _parseNullableDouble(
        _read(json, 'price_change_percent', 'priceChangePercent') ??
            _read(json, 'price_change_pct', 'priceChangePct'),
      ),
      unrealizedPnl:
          _parseNullableDouble(_read(json, 'unrealized_pnl', 'unrealizedPnl')),
      unrealizedPnlPct: _parseNullableDouble(
          _read(json, 'unrealized_pnl_pct', 'unrealizedPnlPct')),
      realizedPnl: _parseDouble(_read(json, 'realized_pnl', 'realizedPnl')),
      isPriceFresh:
          _read(json, 'is_price_fresh', 'isPriceFresh') as bool? ?? true,
      isTradeable: _read(json, 'is_tradeable', 'isTradeable') as bool? ?? true,
      priceStatus:
          _read(json, 'price_status', 'priceStatus')?.toString() ?? 'ok',
      priceTimestamp:
          _parseDate(_read(json, 'price_timestamp', 'priceTimestamp')),
      lastUpdatedAt: _parseDate(
        _read(json, 'last_updated_at', 'lastUpdatedAt') ??
            _read(json, 'last_market_update', 'lastMarketUpdate') ??
            _read(json, 'price_timestamp', 'priceTimestamp'),
      ),
      dataFreshnessSeconds:
          (_read(json, 'data_freshness_seconds', 'dataFreshnessSeconds')
                  as num?)
              ?.toInt(),
    );
  }
}

/// ─── Symbol Return Series ─────────────────────────────────────

class SymbolReturnPoint {
  const SymbolReturnPoint({
    required this.date,
    this.value,
    this.dailyReturnPct,
    this.cumulativeReturnPct,
  });

  final DateTime date;
  final double? value;
  final double? dailyReturnPct;
  final double? cumulativeReturnPct;

  factory SymbolReturnPoint.fromJson(Map<String, dynamic> json) {
    return SymbolReturnPoint(
      date: _parseDate(json['point_date'] ?? json['date']) ?? DateTime.now(),
      value: _parseNullableDouble(json['value']),
      dailyReturnPct: _parseNullableDouble(json['daily_return_pct']),
      cumulativeReturnPct: _parseNullableDouble(json['cumulative_return_pct']),
    );
  }
}

class SymbolReturnSeries {
  const SymbolReturnSeries({
    this.period = '1Y',
    required this.startDate,
    required this.endDate,
    this.totalReturnPct,
    this.annualizedReturnPct,
    this.dataQuality = 'complete',
    this.points = const [],
  });

  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double? totalReturnPct;
  final double? annualizedReturnPct;
  final String dataQuality;
  final List<SymbolReturnPoint> points;

  factory SymbolReturnSeries.fromJson(Map<String, dynamic> json) {
    return SymbolReturnSeries(
      period: json['period'] as String? ?? '1Y',
      startDate: _parseDate(json['start_date']) ?? DateTime.now(),
      endDate: _parseDate(json['end_date']) ?? DateTime.now(),
      totalReturnPct: _parseNullableDouble(json['total_return_pct']),
      annualizedReturnPct: _parseNullableDouble(json['annualized_return_pct']),
      dataQuality: json['data_quality'] as String? ?? 'complete',
      points: (json['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SymbolReturnPoint.fromJson)
          .toList(),
    );
  }
}

/// ─── Symbol Monthly Returns ───────────────────────────────────

class SymbolMonthlyReturns {
  const SymbolMonthlyReturns({
    required this.year,
    this.monthlyReturns = const [],
  });

  final int year;
  final List<MonthlyReturnPoint> monthlyReturns;

  factory SymbolMonthlyReturns.fromJson(Map<String, dynamic> json) {
    return SymbolMonthlyReturns(
      year: (json['year'] as num?)?.toInt() ?? 0,
      monthlyReturns: (json['monthly_returns'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MonthlyReturnPoint.fromJson)
          .toList(),
    );
  }
}

/// ─── Benchmark Comparison (Returns DTO) ───────────────────────

class SymbolBenchmarkComparison {
  const SymbolBenchmarkComparison({
    this.benchmarkCode = '',
    this.benchmarkName = '',
    this.benchmarkReturnPct,
    this.portfolioReturnPct,
    this.excessReturnPct,
    this.trackingError,
    this.informationRatio,
    this.beta,
    this.alpha,
    this.correlation,
  });

  final String benchmarkCode;
  final String benchmarkName;
  final double? benchmarkReturnPct;
  final double? portfolioReturnPct;
  final double? excessReturnPct;
  final double? trackingError;
  final double? informationRatio;
  final double? beta;
  final double? alpha;
  final double? correlation;

  factory SymbolBenchmarkComparison.fromJson(Map<String, dynamic> json) {
    return SymbolBenchmarkComparison(
      benchmarkCode: json['benchmark_code'] as String? ?? '',
      benchmarkName: json['benchmark_name'] as String? ?? '',
      benchmarkReturnPct: _parseNullableDouble(json['benchmark_return_pct']),
      portfolioReturnPct: _parseNullableDouble(json['portfolio_return_pct']),
      excessReturnPct: _parseNullableDouble(json['excess_return_pct']),
      trackingError: _parseNullableDouble(json['tracking_error']),
      informationRatio: _parseNullableDouble(json['information_ratio']),
      beta: _parseNullableDouble(json['beta']),
      alpha: _parseNullableDouble(json['alpha']),
      correlation: _parseNullableDouble(json['correlation']),
    );
  }
}

/// ─── Symbol Analytics Response ────────────────────────────────

class SymbolAnalyticsResponse {
  const SymbolAnalyticsResponse({
    required this.portfolioId,
    this.asOfTimestamp,
    required this.position,
    this.returnSeries,
    this.monthlyReturns,
    this.benchmarkComparison,
    this.dataQuality = 'complete',
    this.isStale = false,
    this.sanityFlags = const [],
  });

  final String portfolioId;
  final DateTime? asOfTimestamp;
  final SymbolPositionInfo position;
  final SymbolReturnSeries? returnSeries;
  final SymbolMonthlyReturns? monthlyReturns;
  final SymbolBenchmarkComparison? benchmarkComparison;
  final String dataQuality;
  final bool isStale;
  final List<String> sanityFlags;

  factory SymbolAnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return SymbolAnalyticsResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      asOfTimestamp: _parseDate(json['as_of_timestamp']),
      position: SymbolPositionInfo.fromJson(
          (json['position'] as Map<String, dynamic>? ?? {})),
      returnSeries: json['return_series'] != null
          ? SymbolReturnSeries.fromJson(
              json['return_series'] as Map<String, dynamic>)
          : null,
      monthlyReturns: json['monthly_returns'] != null
          ? SymbolMonthlyReturns.fromJson(
              json['monthly_returns'] as Map<String, dynamic>)
          : null,
      benchmarkComparison: json['benchmark_comparison'] != null
          ? SymbolBenchmarkComparison.fromJson(
              json['benchmark_comparison'] as Map<String, dynamic>)
          : null,
      dataQuality: json['data_quality'] as String? ?? 'complete',
      isStale: json['is_stale'] as bool? ?? false,
      sanityFlags: (json['sanity_flags'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// ─── Symbol Chart Response ────────────────────────────────────

class SymbolChartResponse {
  const SymbolChartResponse({
    required this.portfolioId,
    required this.symbol,
    required this.chartType,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.asOfTimestamp,
    this.seriesKey = '',
    this.seriesName = '',
    this.valueType = 'currency',
    this.dataPoints = const [],
    this.totalReturnPct,
    this.dataQuality = 'complete',
    this.isStale = false,
  });

  final String portfolioId;
  final String symbol;
  final String chartType;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? asOfTimestamp;
  final String seriesKey;
  final String seriesName;
  final String valueType;
  final List<Map<String, dynamic>> dataPoints;
  final double? totalReturnPct;
  final String dataQuality;
  final bool isStale;

  factory SymbolChartResponse.fromJson(Map<String, dynamic> json) {
    return SymbolChartResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      chartType: json['chart_type'] as String? ?? '',
      period: json['period'] as String? ?? '',
      startDate: _parseDate(json['start_date']) ?? DateTime.now(),
      endDate: _parseDate(json['end_date']) ?? DateTime.now(),
      asOfTimestamp: _parseDate(json['as_of_timestamp']),
      seriesKey: json['series_key'] as String? ?? '',
      seriesName: json['series_name'] as String? ?? '',
      valueType: json['value_type'] as String? ?? 'currency',
      dataPoints: (json['data_points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      totalReturnPct: _parseNullableDouble(json['total_return_pct']),
      dataQuality: json['data_quality'] as String? ?? 'complete',
      isStale: json['is_stale'] as bool? ?? false,
    );
  }
}

/// ─── PnL Summary (for /performance/summary) ──────────────────

class AssetPnLBreakdown {
  const AssetPnLBreakdown({
    required this.assetId,
    required this.tickerSymbol,
    this.quantity = 0,
    this.weightedAvgCost = 0,
    this.livePrice = 0,
    this.currentValue = 0,
    this.unrealizedPnl = 0,
    this.realizedPnl = 0,
    this.weight = 0,
    this.unrealizedPnlPercent = 0,
    this.dailyChange,
    this.dailyChangePercent,
    this.isPriceFresh = true,
    this.priceStatus = 'ok',
  });

  final String assetId;
  final String tickerSymbol;
  final double quantity;
  final double weightedAvgCost;
  final double livePrice;
  final double currentValue;
  final double unrealizedPnl;
  final double realizedPnl;
  final double weight;
  final double unrealizedPnlPercent;
  final double? dailyChange;
  final double? dailyChangePercent;
  final bool isPriceFresh;
  final String priceStatus;

  factory AssetPnLBreakdown.fromJson(Map<String, dynamic> json) {
    return AssetPnLBreakdown(
      assetId: json['asset_id'] as String? ?? '',
      tickerSymbol: json['ticker_symbol'] as String? ?? '',
      quantity: _parseDouble(json['quantity']),
      weightedAvgCost: _parseDouble(json['weighted_avg_cost']),
      livePrice: _parseDouble(json['live_price']),
      currentValue: _parseDouble(json['current_value']),
      unrealizedPnl: _parseDouble(json['unrealized_pnl']),
      realizedPnl: _parseDouble(json['realized_pnl']),
      weight: _parseDouble(json['weight']),
      unrealizedPnlPercent: _parseDouble(json['unrealized_pnl_percent']),
      dailyChange: _parseNullableDouble(json['daily_change']),
      dailyChangePercent: _parseNullableDouble(json['daily_change_percent']),
      isPriceFresh: json['is_price_fresh'] as bool? ?? true,
      priceStatus: json['price_status'] as String? ?? 'ok',
    );
  }
}

class PortfolioPnLSummary {
  const PortfolioPnLSummary({
    required this.portfolioId,
    this.totalCurrentValue = 0,
    this.totalInvested = 0,
    this.totalUnrealizedPnl = 0,
    this.totalRealizedPnl = 0,
    this.totalPnl = 0,
    this.roiPercent = 0,
    this.unrealizedPnlPercent = 0,
    this.assets = const [],
    this.asOfTimestamp,
    this.dataQualityStatus = 'ok',
    this.missingPriceAssets = const [],
    this.stalePriceAssets = const [],
    this.marketStatus = 'unknown',
    this.isCurrentSession = false,
    this.missingPriceCount = 0,
    this.stalePriceCount = 0,
  });

  final String portfolioId;
  final double totalCurrentValue;
  final double totalInvested;
  final double totalUnrealizedPnl;
  final double totalRealizedPnl;
  final double totalPnl;
  final double roiPercent;
  final double unrealizedPnlPercent;
  final List<AssetPnLBreakdown> assets;
  final DateTime? asOfTimestamp;
  final String dataQualityStatus;
  final List<String> missingPriceAssets;
  final List<String> stalePriceAssets;
  final String marketStatus;
  final bool isCurrentSession;
  final int missingPriceCount;
  final int stalePriceCount;

  factory PortfolioPnLSummary.fromJson(Map<String, dynamic> json) {
    final totalUnrealizedPnl = _parseDouble(
      json['total_unrealized_pnl'] ?? json['totalUnrealizedPnl'],
    );
    final totalRealizedPnl = _parseDouble(
      json['total_realized_pnl'] ?? json['totalRealizedPnl'],
    );
    return PortfolioPnLSummary(
      portfolioId: _read(json, 'portfolio_id', 'portfolioId')?.toString() ?? '',
      totalCurrentValue: _parseDouble(
        json['total_current_value'] ??
            json['totalCurrentValue'] ??
            json['total_portfolio_value'] ??
            json['totalPortfolioValue'] ??
            json['total_market_value'] ??
            json['totalMarketValue'],
      ),
      totalInvested: _parseDouble(
        json['total_invested'] ??
            json['totalInvested'] ??
            json['total_cost_basis'] ??
            json['totalCostBasis'],
      ),
      totalUnrealizedPnl: totalUnrealizedPnl,
      totalRealizedPnl: totalRealizedPnl,
      totalPnl: _parseDouble(
        json['total_pnl'] ?? json['totalPnl'],
        totalUnrealizedPnl + totalRealizedPnl,
      ),
      roiPercent: _parseDouble(
        json['roi_percent'] ??
            json['roiPercent'] ??
            json['total_unrealized_pnl_percent'] ??
            json['totalUnrealizedPnlPercent'],
      ),
      unrealizedPnlPercent: _parseDouble(
        json['unrealized_pnl_percent'] ??
            json['unrealizedPnlPercent'] ??
            json['total_unrealized_pnl_percent'] ??
            json['totalUnrealizedPnlPercent'],
      ),
      assets: ((json['assets'] ?? json['holdings']) as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AssetPnLBreakdown.fromJson)
          .toList(),
      asOfTimestamp: _parseDate(
        json['as_of_timestamp'] ?? json['asOfTimestamp'] ?? json['as_of'],
      ),
      dataQualityStatus: (json['data_quality_status'] as String?) ??
          (json['dataQualityStatus'] as String?) ??
          'ok',
      missingPriceAssets: ((json['missing_price_assets'] ??
                  json['missingPriceAssets']) as List<dynamic>? ??
              [])
          .whereType<String>()
          .toList(),
      stalePriceAssets: (json['stale_price_assets'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      marketStatus:
          (json['market_status'] ?? json['marketStatus'])?.toString() ??
              'unknown',
      isCurrentSession:
          _parseBool(json['is_current_session'] ?? json['isCurrentSession']),
      missingPriceCount: (json['missing_price_count'] as num?)?.toInt() ??
          (json['missingPriceCount'] as num?)?.toInt() ??
          (json['missing_market_price_count'] as num?)?.toInt() ??
          (json['missingMarketPriceCount'] as num?)?.toInt() ??
          0,
      stalePriceCount: (json['stale_price_count'] as num?)?.toInt() ??
          (json['stalePriceCount'] as num?)?.toInt() ??
          0,
    );
  }
}

/// ─── Performance Timeseries (for /performance/timeseries) ─────

class PerformanceTimeseriesPoint {
  const PerformanceTimeseriesPoint({
    required this.date,
    this.portfolioValue = 0,
    this.portfolioReturnPct = 0,
  });

  final DateTime date;
  final double portfolioValue;
  final double portfolioReturnPct;

  factory PerformanceTimeseriesPoint.fromJson(Map<String, dynamic> json) {
    return PerformanceTimeseriesPoint(
      date: _parseDate(json['date']) ?? DateTime.now(),
      portfolioValue: _parseDouble(json['portfolio_value']),
      portfolioReturnPct: _parseDouble(json['portfolio_return_pct']),
    );
  }
}

class PerformanceTimeseriesResponse {
  const PerformanceTimeseriesResponse({
    required this.portfolioId,
    this.points = const [],
  });

  final String portfolioId;
  final List<PerformanceTimeseriesPoint> points;

  factory PerformanceTimeseriesResponse.fromJson(Map<String, dynamic> json) {
    return PerformanceTimeseriesResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      points: (json['points'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PerformanceTimeseriesPoint.fromJson)
          .toList(),
    );
  }
}

/// ─── Portfolio Reports (/reports/monthly, /reports/yearly) ────

class ReportPeriodPerformance {
  const ReportPeriodPerformance({
    this.periodLabel = '',
    this.periodStart,
    this.periodEnd,
    this.startingValue,
    this.endingValue,
    this.netDeposits,
    this.realizedPnl,
    this.unrealizedPnl,
    this.totalPnl,
    this.totalReturnAmount,
    this.totalReturnPct,
    this.bestPerformerSymbol,
    this.bestPerformerReturnPct,
    this.worstPerformerSymbol,
    this.worstPerformerReturnPct,
    this.dataCompleteness = 'complete',
    this.isStale = false,
  });

  final String periodLabel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double? startingValue;
  final double? endingValue;
  final double? netDeposits;
  final double? realizedPnl;
  final double? unrealizedPnl;
  final double? totalPnl;
  final double? totalReturnAmount;
  final double? totalReturnPct;
  final String? bestPerformerSymbol;
  final double? bestPerformerReturnPct;
  final String? worstPerformerSymbol;
  final double? worstPerformerReturnPct;
  final String dataCompleteness;
  final bool isStale;

  factory ReportPeriodPerformance.fromJson(Map<String, dynamic> json) {
    return ReportPeriodPerformance(
      periodLabel: json['period_label'] as String? ?? '',
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      startingValue: _parseNullableDouble(json['starting_value']),
      endingValue: _parseNullableDouble(json['ending_value']),
      netDeposits: _parseNullableDouble(json['net_deposits']),
      realizedPnl: _parseNullableDouble(json['realized_pnl']),
      unrealizedPnl: _parseNullableDouble(json['unrealized_pnl']),
      totalPnl: _parseNullableDouble(json['total_pnl']),
      totalReturnAmount: _parseNullableDouble(json['total_return_amount']),
      totalReturnPct: _parseNullableDouble(json['total_return_pct']),
      bestPerformerSymbol: json['best_performer_symbol'] as String?,
      bestPerformerReturnPct:
          _parseNullableDouble(json['best_performer_return_pct']),
      worstPerformerSymbol: json['worst_performer_symbol'] as String?,
      worstPerformerReturnPct:
          _parseNullableDouble(json['worst_performer_return_pct']),
      dataCompleteness: json['data_completeness'] as String? ?? 'complete',
      isStale: json['is_stale'] as bool? ?? false,
    );
  }
}

class ReportReturnPoint {
  const ReportReturnPoint({
    this.periodDate,
    this.label = '',
    this.year,
    this.startingValue,
    this.endingValue,
    this.returnPct,
    this.cumulativeReturnPct,
    this.benchmarkReturnPct,
    this.bestPerformerSymbol,
    this.worstPerformerSymbol,
  });

  final DateTime? periodDate;
  final String label;
  final int? year;
  final double? startingValue;
  final double? endingValue;
  final double? returnPct;
  final double? cumulativeReturnPct;
  final double? benchmarkReturnPct;
  final String? bestPerformerSymbol;
  final String? worstPerformerSymbol;

  factory ReportReturnPoint.fromJson(Map<String, dynamic> json) {
    return ReportReturnPoint(
      periodDate: _parseDate(json['period_date']),
      label: json['label'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
      startingValue: _parseNullableDouble(json['starting_value']),
      endingValue: _parseNullableDouble(json['ending_value']),
      returnPct: _parseNullableDouble(json['return_pct']),
      cumulativeReturnPct: _parseNullableDouble(json['cumulative_return_pct']),
      benchmarkReturnPct: _parseNullableDouble(json['benchmark_return_pct']),
      bestPerformerSymbol: json['best_performer_symbol'] as String?,
      worstPerformerSymbol: json['worst_performer_symbol'] as String?,
    );
  }
}

class MonthlyPortfolioReportResponse {
  const MonthlyPortfolioReportResponse({
    required this.portfolioId,
    this.baseCurrency = 'IRR',
    this.year = 0,
    this.month = 0,
    this.periodStart,
    this.periodEnd,
    required this.performance,
    this.monthlyReturns = const [],
    this.dataCompleteness = 'complete',
    this.isStale = false,
    this.generatedAt,
  });

  final String portfolioId;
  final String baseCurrency;
  final int year;
  final int month;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ReportPeriodPerformance performance;
  final List<ReportReturnPoint> monthlyReturns;
  final String dataCompleteness;
  final bool isStale;
  final DateTime? generatedAt;

  factory MonthlyPortfolioReportResponse.fromJson(Map<String, dynamic> json) {
    return MonthlyPortfolioReportResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      baseCurrency: json['base_currency'] as String? ?? 'IRR',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      performance: ReportPeriodPerformance.fromJson(
        json['performance'] as Map<String, dynamic>? ?? const {},
      ),
      monthlyReturns: (json['monthly_returns'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportReturnPoint.fromJson)
          .toList(),
      dataCompleteness: json['data_completeness'] as String? ?? 'complete',
      isStale: json['is_stale'] as bool? ?? false,
      generatedAt: _parseDate(json['generated_at']),
    );
  }
}

class YearlyPortfolioReportResponse {
  const YearlyPortfolioReportResponse({
    required this.portfolioId,
    this.baseCurrency = 'IRR',
    this.year = 0,
    this.periodStart,
    this.periodEnd,
    required this.performance,
    this.monthlyBreakdown = const [],
    this.yearlyReturns = const [],
    this.dataCompleteness = 'complete',
    this.isStale = false,
    this.generatedAt,
  });

  final String portfolioId;
  final String baseCurrency;
  final int year;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ReportPeriodPerformance performance;
  final List<ReportReturnPoint> monthlyBreakdown;
  final List<ReportReturnPoint> yearlyReturns;
  final String dataCompleteness;
  final bool isStale;
  final DateTime? generatedAt;

  factory YearlyPortfolioReportResponse.fromJson(Map<String, dynamic> json) {
    return YearlyPortfolioReportResponse(
      portfolioId: json['portfolio_id'] as String? ?? '',
      baseCurrency: json['base_currency'] as String? ?? 'IRR',
      year: (json['year'] as num?)?.toInt() ?? 0,
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      performance: ReportPeriodPerformance.fromJson(
        json['performance'] as Map<String, dynamic>? ?? const {},
      ),
      monthlyBreakdown: (json['monthly_breakdown'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportReturnPoint.fromJson)
          .toList(),
      yearlyReturns: (json['yearly_returns'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReportReturnPoint.fromJson)
          .toList(),
      dataCompleteness: json['data_completeness'] as String? ?? 'complete',
      isStale: json['is_stale'] as bool? ?? false,
      generatedAt: _parseDate(json['generated_at']),
    );
  }
}
