/// Domain models for benchmark comparison API responses.
/// Alignment metadata for date alignment between target and benchmark.
class AlignmentMetadata {
  const AlignmentMetadata({
    this.targetDataPoints = 0,
    this.benchmarkDataPoints = 0,
    this.alignedDataPoints = 0,
    this.alignmentQuality = 'insufficient',
    this.overlapStartDate,
    this.overlapEndDate,
    this.targetOnlyDates = 0,
    this.benchmarkOnlyDates = 0,
  });

  final int targetDataPoints;
  final int benchmarkDataPoints;
  final int alignedDataPoints;
  final String alignmentQuality;
  final DateTime? overlapStartDate;
  final DateTime? overlapEndDate;
  final int targetOnlyDates;
  final int benchmarkOnlyDates;

  factory AlignmentMetadata.fromJson(Map<String, dynamic> json) {
    return AlignmentMetadata(
      targetDataPoints: json['target_data_points'] ?? 0,
      benchmarkDataPoints: json['benchmark_data_points'] ?? 0,
      alignedDataPoints: json['aligned_data_points'] ?? 0,
      alignmentQuality: json['alignment_quality']?.toString() ?? 'insufficient',
      overlapStartDate: json['overlap_start_date'] != null
          ? DateTime.parse(json['overlap_start_date'])
          : null,
      overlapEndDate: json['overlap_end_date'] != null
          ? DateTime.parse(json['overlap_end_date'])
          : null,
      targetOnlyDates: json['target_only_dates'] ?? 0,
      benchmarkOnlyDates: json['benchmark_only_dates'] ?? 0,
    );
  }
}

/// Single benchmark comparison result.
class BenchmarkComparisonResult {
  const BenchmarkComparisonResult({
    required this.benchmarkId,
    required this.benchmarkName,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.asOfDate,
    this.targetReturnPct,
    this.benchmarkReturnPct,
    this.excessReturnPct,
    this.targetAnnualizedPct,
    this.benchmarkAnnualizedPct,
    this.excessAnnualizedPct,
    this.trackingErrorPct,
    this.informationRatio,
    this.beta,
    this.alphaPct,
    this.correlation,
    this.rSquared,
    this.alignment,
    this.isFresh = true,
    this.isStale = false,
    this.lastComputedAt,
  });

  final String benchmarkId;
  final String benchmarkName;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime asOfDate;
  final double? targetReturnPct;
  final double? benchmarkReturnPct;
  final double? excessReturnPct;
  final double? targetAnnualizedPct;
  final double? benchmarkAnnualizedPct;
  final double? excessAnnualizedPct;
  final double? trackingErrorPct;
  final double? informationRatio;
  final double? beta;
  final double? alphaPct;
  final double? correlation;
  final double? rSquared;
  final AlignmentMetadata? alignment;
  final bool isFresh;
  final bool isStale;
  final DateTime? lastComputedAt;

  factory BenchmarkComparisonResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkComparisonResult(
      benchmarkId: json['benchmark_id']?.toString() ?? '',
      benchmarkName: json['benchmark_name']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      asOfDate: DateTime.parse(json['as_of_date'] ?? DateTime.now().toIso8601String()),
      targetReturnPct: _parseDouble(json['target_return_pct']),
      benchmarkReturnPct: _parseDouble(json['benchmark_return_pct']),
      excessReturnPct: _parseDouble(json['excess_return_pct']),
      targetAnnualizedPct: _parseDouble(json['target_annualized_pct']),
      benchmarkAnnualizedPct: _parseDouble(json['benchmark_annualized_pct']),
      excessAnnualizedPct: _parseDouble(json['excess_annualized_pct']),
      trackingErrorPct: _parseDouble(json['tracking_error_pct']),
      informationRatio: _parseDouble(json['information_ratio']),
      beta: _parseDouble(json['beta']),
      alphaPct: _parseDouble(json['alpha_pct']),
      correlation: _parseDouble(json['correlation']),
      rSquared: _parseDouble(json['r_squared']),
      alignment: json['alignment'] != null
          ? AlignmentMetadata.fromJson(json['alignment'])
          : null,
      isFresh: json['is_fresh'] ?? true,
      isStale: json['is_stale'] ?? false,
      lastComputedAt: json['last_computed_at'] != null
          ? DateTime.parse(json['last_computed_at'])
          : null,
    );
  }
}

/// Multi-benchmark comparison summary.
class BenchmarkComparisonSummary {
  const BenchmarkComparisonSummary({
    required this.targetId,
    this.targetName,
    required this.asOfDate,
    required this.period,
    this.comparisons = const [],
    this.bestBenchmark,
    this.worstBenchmark,
    this.isFresh = true,
    this.isStale = false,
    this.lastComputedAt,
  });

  final String targetId;
  final String? targetName;
  final DateTime asOfDate;
  final String period;
  final List<BenchmarkComparisonResult> comparisons;
  final String? bestBenchmark;
  final String? worstBenchmark;
  final bool isFresh;
  final bool isStale;
  final DateTime? lastComputedAt;

  factory BenchmarkComparisonSummary.fromJson(Map<String, dynamic> json) {
    return BenchmarkComparisonSummary(
      targetId: json['target_id']?.toString() ?? '',
      targetName: json['target_name']?.toString(),
      asOfDate: DateTime.parse(json['as_of_date'] ?? DateTime.now().toIso8601String()),
      period: json['period']?.toString() ?? '',
      comparisons: (json['comparisons'] as List?)
              ?.map((e) => BenchmarkComparisonResult.fromJson(e))
              .toList() ??
          [],
      bestBenchmark: json['best_benchmark']?.toString(),
      worstBenchmark: json['worst_benchmark']?.toString(),
      isFresh: json['is_fresh'] ?? true,
      isStale: json['is_stale'] ?? false,
      lastComputedAt: json['last_computed_at'] != null
          ? DateTime.parse(json['last_computed_at'])
          : null,
    );
  }
}

/// Comparison series point for charting.
class ComparisonSeriesPoint {
  const ComparisonSeriesPoint({
    required this.date,
    this.targetCumulativePct,
    this.benchmarkCumulativePct,
    this.excessCumulativePct,
    this.targetValue,
    this.benchmarkValue,
  });

  final DateTime date;
  final double? targetCumulativePct;
  final double? benchmarkCumulativePct;
  final double? excessCumulativePct;
  final double? targetValue;
  final double? benchmarkValue;

  factory ComparisonSeriesPoint.fromJson(Map<String, dynamic> json) {
    return ComparisonSeriesPoint(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      targetCumulativePct: _parseDouble(json['target_cumulative_pct']),
      benchmarkCumulativePct: _parseDouble(json['benchmark_cumulative_pct']),
      excessCumulativePct: _parseDouble(json['excess_cumulative_pct']),
      targetValue: _parseDouble(json['target_value']),
      benchmarkValue: _parseDouble(json['benchmark_value']),
    );
  }
}

/// Comparison series response for charting.
class ComparisonSeriesResponse {
  const ComparisonSeriesResponse({
    required this.targetId,
    required this.benchmarkId,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.points = const [],
    this.finalTargetReturnPct,
    this.finalBenchmarkReturnPct,
    this.finalExcessReturnPct,
    this.alignment,
  });

  final String targetId;
  final String benchmarkId;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final List<ComparisonSeriesPoint> points;
  final double? finalTargetReturnPct;
  final double? finalBenchmarkReturnPct;
  final double? finalExcessReturnPct;
  final AlignmentMetadata? alignment;

  factory ComparisonSeriesResponse.fromJson(Map<String, dynamic> json) {
    return ComparisonSeriesResponse(
      targetId: json['target_id']?.toString() ?? '',
      benchmarkId: json['benchmark_id']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      points: (json['points'] as List?)
              ?.map((e) => ComparisonSeriesPoint.fromJson(e))
              .toList() ??
          [],
      finalTargetReturnPct: _parseDouble(json['final_target_return_pct']),
      finalBenchmarkReturnPct: _parseDouble(json['final_benchmark_return_pct']),
      finalExcessReturnPct: _parseDouble(json['final_excess_return_pct']),
      alignment: json['alignment'] != null
          ? AlignmentMetadata.fromJson(json['alignment'])
          : null,
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
