// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_models.freezed.dart';
part 'analytics_models.g.dart';

enum AnalyticsTimeframe {
  @JsonValue('1M')
  oneMonth,
  @JsonValue('3M')
  threeMonths,
  @JsonValue('6M')
  sixMonths,
  @JsonValue('1Y')
  oneYear,
  @JsonValue('ALL')
  all,
}

extension AnalyticsTimeframeX on AnalyticsTimeframe {
  String get apiValue {
    return switch (this) {
      AnalyticsTimeframe.oneMonth => '1M',
      AnalyticsTimeframe.threeMonths => '3M',
      AnalyticsTimeframe.sixMonths => '6M',
      AnalyticsTimeframe.oneYear => '1Y',
      AnalyticsTimeframe.all => 'ALL',
    };
  }

  String get shortLabel {
    return switch (this) {
      AnalyticsTimeframe.oneMonth => '1M',
      AnalyticsTimeframe.threeMonths => '3M',
      AnalyticsTimeframe.sixMonths => '6M',
      AnalyticsTimeframe.oneYear => '1Y',
      AnalyticsTimeframe.all => 'همه',
    };
  }
}

AnalyticsTimeframe _timeframeFromJson(Object? raw) {
  final value = (raw ?? '').toString().toUpperCase();
  return AnalyticsTimeframe.values.firstWhere(
    (item) => item.apiValue == value,
    orElse: () => AnalyticsTimeframe.oneMonth,
  );
}

String _timeframeToJson(AnalyticsTimeframe value) => value.apiValue;

double _safeDouble(Object? raw, {double fallback = 0}) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse(raw?.toString() ?? '') ?? fallback;
}

double? _safeNullableDouble(Object? raw) {
  if (raw == null) {
    return null;
  }
  final parsed = _safeDouble(raw, fallback: double.nan);
  if (parsed.isNaN || !parsed.isFinite) {
    return null;
  }
  return parsed;
}

DateTime _parseApiDate(Object? raw) {
  final source = raw?.toString() ?? '';
  if (source.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  final parsed = DateTime.tryParse(source);
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String _dateToJson(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

AdvancedRiskMetricsResponse _riskAssessmentFromJson(Object? raw) {
  final payload = raw;
  if (payload is Map<String, dynamic>) {
    return AdvancedRiskMetricsResponse.fromJson(payload);
  }
  return const AdvancedRiskMetricsResponse();
}

ValueAtRiskDistribution _valueAtRiskFromJson(Object? raw) {
  final payload = raw;
  if (payload is Map<String, dynamic>) {
    return ValueAtRiskDistribution.fromJson(payload);
  }
  return const ValueAtRiskDistribution();
}

ValueAtRiskBand _valueAtRiskBandFromJson(Object? raw) {
  final payload = raw;
  if (payload is Map<String, dynamic>) {
    return ValueAtRiskBand.fromJson(payload);
  }
  return const ValueAtRiskBand();
}

@freezed
abstract class AnalyticsPerformancePoint with _$AnalyticsPerformancePoint {
  const factory AnalyticsPerformancePoint({
    @JsonKey(
      name: 'date',
      fromJson: _parseApiDate,
      toJson: _dateToJson,
    )
    required DateTime date,
    @JsonKey(
      name: 'market_value',
      fromJson: _safeDouble,
    )
    @Default(0)
    double portfolioValue,
    @JsonKey(
      name: 'benchmark_value',
      fromJson: _safeNullableDouble,
    )
    double? benchmarkValue,
    @JsonKey(
      name: 'pnl',
      fromJson: _safeDouble,
    )
    @Default(0)
    double pnl,
    @JsonKey(
      name: 'roi',
      fromJson: _safeDouble,
    )
    @Default(0)
    double roiPercent,
  }) = _AnalyticsPerformancePoint;

  factory AnalyticsPerformancePoint.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsPerformancePointFromJson(json);
}

@freezed
abstract class AnalyticsPerformanceSeries with _$AnalyticsPerformanceSeries {
  const factory AnalyticsPerformanceSeries({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(
      name: 'timeframe',
      fromJson: _timeframeFromJson,
      toJson: _timeframeToJson,
    )
    required AnalyticsTimeframe timeframe,
    @JsonKey(name: 'base_currency') required String baseCurrency,
    @Default(<AnalyticsPerformancePoint>[])
    @JsonKey(name: 'points')
    List<AnalyticsPerformancePoint> points,
  }) = _AnalyticsPerformanceSeries;

  factory AnalyticsPerformanceSeries.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsPerformanceSeriesFromJson(json);
}

@freezed
abstract class AnalyticsMetrics with _$AnalyticsMetrics {
  const factory AnalyticsMetrics({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(
      name: 'timeframe',
      fromJson: _timeframeFromJson,
      toJson: _timeframeToJson,
    )
    required AnalyticsTimeframe timeframe,
    @JsonKey(name: 'base_currency') required String baseCurrency,
    @JsonKey(
      name: 'as_of_date',
      fromJson: _parseApiDate,
      toJson: _dateToJson,
    )
    required DateTime asOfDate,
    @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
    @Default(0)
    double riskFreeRate,
    @JsonKey(name: 'pnl', fromJson: _safeDouble) @Default(0) double pnl,
    @JsonKey(name: 'roi', fromJson: _safeDouble) @Default(0) double roiPercent,
    @JsonKey(name: 'volatility', fromJson: _safeDouble)
    @Default(0)
    double volatility,
    @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
    @Default(0)
    double sharpeRatio,
    @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
    @Default(AdvancedRiskMetricsResponse())
    AdvancedRiskMetricsResponse riskAssessment,
  }) = _AnalyticsMetrics;

  factory AnalyticsMetrics.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsMetricsFromJson(json);
}

@freezed
abstract class AdvancedRiskMetricsResponse with _$AdvancedRiskMetricsResponse {
  const factory AdvancedRiskMetricsResponse({
    @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
    double? sortinoRatio,
    @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
    double? maximumDrawdown,
    @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
    @JsonKey(name: 'alpha', fromJson: _safeNullableDouble) double? alpha,
    @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
    @Default(ValueAtRiskDistribution())
    ValueAtRiskDistribution valueAtRisk,
  }) = _AdvancedRiskMetricsResponse;

  factory AdvancedRiskMetricsResponse.fromJson(Map<String, dynamic> json) =>
      _$AdvancedRiskMetricsResponseFromJson(json);
}

@freezed
abstract class ValueAtRiskDistribution with _$ValueAtRiskDistribution {
  const factory ValueAtRiskDistribution({
    @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
    @Default(ValueAtRiskBand())
    ValueAtRiskBand historical,
    @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
    @Default(ValueAtRiskBand())
    ValueAtRiskBand parametric,
  }) = _ValueAtRiskDistribution;

  factory ValueAtRiskDistribution.fromJson(Map<String, dynamic> json) =>
      _$ValueAtRiskDistributionFromJson(json);
}

@freezed
abstract class ValueAtRiskBand with _$ValueAtRiskBand {
  const factory ValueAtRiskBand({
    @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
    double? confidence95,
    @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
    double? confidence99,
  }) = _ValueAtRiskBand;

  factory ValueAtRiskBand.fromJson(Map<String, dynamic> json) =>
      _$ValueAtRiskBandFromJson(json);
}

@freezed
abstract class AnalyticsAllocationSlice with _$AnalyticsAllocationSlice {
  const factory AnalyticsAllocationSlice({
    required String ticker,
    @JsonKey(fromJson: _safeDouble) @Default(0) double percentage,
    @JsonKey(fromJson: _safeDouble) @Default(0) double value,
  }) = _AnalyticsAllocationSlice;

  factory AnalyticsAllocationSlice.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsAllocationSliceFromJson(json);
}

@freezed
abstract class AnalyticsViewState with _$AnalyticsViewState {
  const factory AnalyticsViewState({
    required AnalyticsTimeframe selectedTimeframe,
    required AnalyticsPerformanceSeries performanceSeries,
    required AnalyticsMetrics metrics,
    @Default(<AnalyticsAllocationSlice>[])
    List<AnalyticsAllocationSlice> allocation,
  }) = _AnalyticsViewState;
}

extension AnalyticsMetricsRiskX on AnalyticsMetrics {
  double? get riskScore {
    final maxVar = [
      riskAssessment.valueAtRisk.historical.confidence99,
      riskAssessment.valueAtRisk.parametric.confidence99,
      riskAssessment.valueAtRisk.historical.confidence95,
      riskAssessment.valueAtRisk.parametric.confidence95,
    ].whereType<double>().fold<double>(0, (a, b) => a > b ? a : b);

    final components = <({double value, double weight})>[];
    final volatilityPercent = _volatilityAsPercent(volatility);
    if (volatilityPercent != null && volatilityPercent > 0) {
      components.add(
        (value: (volatilityPercent / 40).clamp(0, 1).toDouble(), weight: 0.35),
      );
    }
    if (riskAssessment.maximumDrawdown != null) {
      components.add(
        (
          value: (riskAssessment.maximumDrawdown! / 0.35).clamp(0, 1).toDouble(),
          weight: 0.35,
        ),
      );
    }
    if (maxVar > 0) {
      components.add(
        (value: (maxVar / 0.08).clamp(0, 1).toDouble(), weight: 0.2),
      );
    }
    if (riskAssessment.beta != null) {
      components.add(
        (
          value: ((riskAssessment.beta! - 1).abs().clamp(0, 1.2) / 1.2).toDouble(),
          weight: 0.1,
        ),
      );
    }
    if (components.isEmpty) {
      return null;
    }

    final totalWeight = components.fold<double>(0, (sum, item) => sum + item.weight);
    if (totalWeight <= 0) {
      return null;
    }
    final weighted = components.fold<double>(
      0,
      (sum, item) => sum + (item.value * item.weight),
    ) /
        totalWeight;
    return (weighted * 100).clamp(0, 100);
  }

  String? get riskLevel {
    final score = riskScore;
    if (score == null) {
      return null;
    }
    if (score < 34) {
      return 'low';
    }
    if (score < 67) {
      return 'medium';
    }
    return 'high';
  }
}

double? _volatilityAsPercent(double? rawVolatility) {
  if (rawVolatility == null || !rawVolatility.isFinite) {
    return null;
  }
  // Backend sends annualized sigma in decimal form (e.g. 0.18 = 18%).
  if (rawVolatility <= 1.0) {
    return rawVolatility * 100;
  }
  return rawVolatility;
}
