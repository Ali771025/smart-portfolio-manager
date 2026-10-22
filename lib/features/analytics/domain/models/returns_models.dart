/// Domain models for historical returns API responses.
/// Returns summary for all standard periods.
class ReturnsSummary {
  const ReturnsSummary({
    required this.portfolioId,
    required this.baseCurrency,
    required this.asOfDate,
    this.inceptionDate,
    this.period1M,
    this.period3M,
    this.period6M,
    this.period1Y,
    this.periodYtd,
    this.periodInception,
    this.volatilityAnnualPct,
    this.sharpeRatio,
    this.sortinoRatio,
    this.maxDrawdownPct,
    this.benchmarkComparisons = const [],
    this.dataQuality = 'complete',
    this.isStale = false,
    this.lastComputedAt,
  });

  final String portfolioId;
  final String baseCurrency;
  final DateTime asOfDate;
  final DateTime? inceptionDate;
  final PeriodReturn? period1M;
  final PeriodReturn? period3M;
  final PeriodReturn? period6M;
  final PeriodReturn? period1Y;
  final PeriodReturn? periodYtd;
  final PeriodReturn? periodInception;
  final double? volatilityAnnualPct;
  final double? sharpeRatio;
  final double? sortinoRatio;
  final double? maxDrawdownPct;
  final List<BenchmarkComparison> benchmarkComparisons;
  final String dataQuality;
  final bool isStale;
  final DateTime? lastComputedAt;

  bool get hasData => period1M != null || period1Y != null;

  factory ReturnsSummary.fromJson(Map<String, dynamic> json) {
    return ReturnsSummary(
      portfolioId: json['portfolio_id']?.toString() ?? '',
      baseCurrency: json['base_currency']?.toString() ?? 'IRR',
      asOfDate: DateTime.parse(json['as_of_date'] ?? DateTime.now().toIso8601String()),
      inceptionDate: json['inception_date'] != null
          ? DateTime.parse(json['inception_date'])
          : null,
      period1M: json['period_1m'] != null
          ? PeriodReturn.fromJson(json['period_1m'])
          : null,
      period3M: json['period_3m'] != null
          ? PeriodReturn.fromJson(json['period_3m'])
          : null,
      period6M: json['period_6m'] != null
          ? PeriodReturn.fromJson(json['period_6m'])
          : null,
      period1Y: json['period_1y'] != null
          ? PeriodReturn.fromJson(json['period_1y'])
          : null,
      periodYtd: json['period_ytd'] != null
          ? PeriodReturn.fromJson(json['period_ytd'])
          : null,
      periodInception: json['period_inception'] != null
          ? PeriodReturn.fromJson(json['period_inception'])
          : null,
      volatilityAnnualPct: _parseDouble(json['volatility_annual_pct']),
      sharpeRatio: _parseDouble(json['sharpe_ratio']),
      sortinoRatio: _parseDouble(json['sortino_ratio']),
      maxDrawdownPct: _parseDouble(json['max_drawdown_pct']),
      benchmarkComparisons: (json['benchmark_comparisons'] as List?)
              ?.map((e) => BenchmarkComparison.fromJson(e))
              .toList() ??
          [],
      dataQuality: json['data_quality']?.toString() ?? 'complete',
      isStale: json['is_stale'] ?? false,
      lastComputedAt: json['last_computed_at'] != null
          ? DateTime.parse(json['last_computed_at'])
          : null,
    );
  }
}

/// Return for a single period.
class PeriodReturn {
  const PeriodReturn({
    required this.period,
    this.returnPct,
    this.annualizedReturnPct,
    this.startValue,
    this.endValue,
    required this.startDate,
    required this.endDate,
    this.tradingDays = 0,
    this.dataQuality = 'complete',
  });

  final String period;
  final double? returnPct;
  final double? annualizedReturnPct;
  final double? startValue;
  final double? endValue;
  final DateTime startDate;
  final DateTime endDate;
  final int tradingDays;
  final String dataQuality;

  bool get hasData => returnPct != null;

  factory PeriodReturn.fromJson(Map<String, dynamic> json) {
    return PeriodReturn(
      period: json['period']?.toString() ?? '',
      returnPct: _parseDouble(json['return_pct']),
      annualizedReturnPct: _parseDouble(json['annualized_return_pct']),
      startValue: _parseDouble(json['start_value']),
      endValue: _parseDouble(json['end_value']),
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      tradingDays: json['trading_days'] ?? 0,
      dataQuality: json['data_quality']?.toString() ?? 'complete',
    );
  }
}

/// Benchmark comparison result.
class BenchmarkComparison {
  const BenchmarkComparison({
    required this.benchmarkCode,
    required this.benchmarkName,
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

  factory BenchmarkComparison.fromJson(Map<String, dynamic> json) {
    return BenchmarkComparison(
      benchmarkCode: json['benchmark_code']?.toString() ?? '',
      benchmarkName: json['benchmark_name']?.toString() ?? '',
      benchmarkReturnPct: _parseDouble(json['benchmark_return_pct']),
      portfolioReturnPct: _parseDouble(json['portfolio_return_pct']),
      excessReturnPct: _parseDouble(json['excess_return_pct']),
      trackingError: _parseDouble(json['tracking_error']),
      informationRatio: _parseDouble(json['information_ratio']),
      beta: _parseDouble(json['beta']),
      alpha: _parseDouble(json['alpha']),
      correlation: _parseDouble(json['correlation']),
    );
  }
}

/// Return series point for charting.
class ReturnSeriesPoint {
  const ReturnSeriesPoint({
    required this.date,
    this.value,
    this.dailyReturnPct,
    this.cumulativeReturnPct,
    this.benchmarkValue,
  });

  final DateTime date;
  final double? value;
  final double? dailyReturnPct;
  final double? cumulativeReturnPct;
  final double? benchmarkValue;

  factory ReturnSeriesPoint.fromJson(Map<String, dynamic> json) {
    return ReturnSeriesPoint(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      value: _parseDouble(json['value']),
      dailyReturnPct: _parseDouble(json['daily_return_pct']),
      cumulativeReturnPct: _parseDouble(json['cumulative_return_pct']),
      benchmarkValue: _parseDouble(json['benchmark_value']),
    );
  }
}

/// Return series response for charting.
class ReturnSeriesResponse {
  const ReturnSeriesResponse({
    required this.portfolioId,
    required this.period,
    required this.frequency,
    required this.baseCurrency,
    required this.startDate,
    required this.endDate,
    this.points = const [],
    this.totalReturnPct,
    this.annualizedReturnPct,
    this.dataQuality = 'complete',
  });

  final String portfolioId;
  final String period;
  final String frequency;
  final String baseCurrency;
  final DateTime startDate;
  final DateTime endDate;
  final List<ReturnSeriesPoint> points;
  final double? totalReturnPct;
  final double? annualizedReturnPct;
  final String dataQuality;

  factory ReturnSeriesResponse.fromJson(Map<String, dynamic> json) {
    return ReturnSeriesResponse(
      portfolioId: json['portfolio_id']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? 'daily',
      baseCurrency: json['base_currency']?.toString() ?? 'IRR',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      points: (json['points'] as List?)
              ?.map((e) => ReturnSeriesPoint.fromJson(e))
              .toList() ??
          [],
      totalReturnPct: _parseDouble(json['total_return_pct']),
      annualizedReturnPct: _parseDouble(json['annualized_return_pct']),
      dataQuality: json['data_quality']?.toString() ?? 'complete',
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
