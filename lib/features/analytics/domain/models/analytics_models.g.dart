// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnalyticsPerformancePoint _$AnalyticsPerformancePointFromJson(
        Map<String, dynamic> json) =>
    _AnalyticsPerformancePoint(
      date: _parseApiDate(json['date']),
      portfolioValue:
          json['market_value'] == null ? 0 : _safeDouble(json['market_value']),
      benchmarkValue: _safeNullableDouble(json['benchmark_value']),
      pnl: json['pnl'] == null ? 0 : _safeDouble(json['pnl']),
      roiPercent: json['roi'] == null ? 0 : _safeDouble(json['roi']),
    );

Map<String, dynamic> _$AnalyticsPerformancePointToJson(
        _AnalyticsPerformancePoint instance) =>
    <String, dynamic>{
      'date': _dateToJson(instance.date),
      'market_value': instance.portfolioValue,
      'benchmark_value': instance.benchmarkValue,
      'pnl': instance.pnl,
      'roi': instance.roiPercent,
    };

_AnalyticsPerformanceSeries _$AnalyticsPerformanceSeriesFromJson(
        Map<String, dynamic> json) =>
    _AnalyticsPerformanceSeries(
      portfolioId: json['portfolio_id'] as String,
      timeframe: _timeframeFromJson(json['timeframe']),
      baseCurrency: json['base_currency'] as String,
      points: (json['points'] as List<dynamic>?)
              ?.map((e) =>
                  AnalyticsPerformancePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AnalyticsPerformancePoint>[],
    );

Map<String, dynamic> _$AnalyticsPerformanceSeriesToJson(
        _AnalyticsPerformanceSeries instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'timeframe': _timeframeToJson(instance.timeframe),
      'base_currency': instance.baseCurrency,
      'points': instance.points,
    };

_AnalyticsMetrics _$AnalyticsMetricsFromJson(Map<String, dynamic> json) =>
    _AnalyticsMetrics(
      portfolioId: json['portfolio_id'] as String,
      timeframe: _timeframeFromJson(json['timeframe']),
      baseCurrency: json['base_currency'] as String,
      asOfDate: _parseApiDate(json['as_of_date']),
      riskFreeRate: json['risk_free_rate'] == null
          ? 0
          : _safeDouble(json['risk_free_rate']),
      pnl: json['pnl'] == null ? 0 : _safeDouble(json['pnl']),
      roiPercent: json['roi'] == null ? 0 : _safeDouble(json['roi']),
      volatility:
          json['volatility'] == null ? 0 : _safeDouble(json['volatility']),
      sharpeRatio:
          json['sharpe_ratio'] == null ? 0 : _safeDouble(json['sharpe_ratio']),
      riskAssessment: json['risk_assessment'] == null
          ? const AdvancedRiskMetricsResponse()
          : _riskAssessmentFromJson(json['risk_assessment']),
    );

Map<String, dynamic> _$AnalyticsMetricsToJson(_AnalyticsMetrics instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'timeframe': _timeframeToJson(instance.timeframe),
      'base_currency': instance.baseCurrency,
      'as_of_date': _dateToJson(instance.asOfDate),
      'risk_free_rate': instance.riskFreeRate,
      'pnl': instance.pnl,
      'roi': instance.roiPercent,
      'volatility': instance.volatility,
      'sharpe_ratio': instance.sharpeRatio,
      'risk_assessment': instance.riskAssessment,
    };

_AdvancedRiskMetricsResponse _$AdvancedRiskMetricsResponseFromJson(
        Map<String, dynamic> json) =>
    _AdvancedRiskMetricsResponse(
      sortinoRatio: _safeNullableDouble(json['sortino_ratio']),
      maximumDrawdown: _safeNullableDouble(json['maximum_drawdown']),
      beta: _safeNullableDouble(json['beta']),
      alpha: _safeNullableDouble(json['alpha']),
      valueAtRisk: json['value_at_risk'] == null
          ? const ValueAtRiskDistribution()
          : _valueAtRiskFromJson(json['value_at_risk']),
    );

Map<String, dynamic> _$AdvancedRiskMetricsResponseToJson(
        _AdvancedRiskMetricsResponse instance) =>
    <String, dynamic>{
      'sortino_ratio': instance.sortinoRatio,
      'maximum_drawdown': instance.maximumDrawdown,
      'beta': instance.beta,
      'alpha': instance.alpha,
      'value_at_risk': instance.valueAtRisk,
    };

_ValueAtRiskDistribution _$ValueAtRiskDistributionFromJson(
        Map<String, dynamic> json) =>
    _ValueAtRiskDistribution(
      historical: json['historical'] == null
          ? const ValueAtRiskBand()
          : _valueAtRiskBandFromJson(json['historical']),
      parametric: json['parametric'] == null
          ? const ValueAtRiskBand()
          : _valueAtRiskBandFromJson(json['parametric']),
    );

Map<String, dynamic> _$ValueAtRiskDistributionToJson(
        _ValueAtRiskDistribution instance) =>
    <String, dynamic>{
      'historical': instance.historical,
      'parametric': instance.parametric,
    };

_ValueAtRiskBand _$ValueAtRiskBandFromJson(Map<String, dynamic> json) =>
    _ValueAtRiskBand(
      confidence95: _safeNullableDouble(json['confidence_95']),
      confidence99: _safeNullableDouble(json['confidence_99']),
    );

Map<String, dynamic> _$ValueAtRiskBandToJson(_ValueAtRiskBand instance) =>
    <String, dynamic>{
      'confidence_95': instance.confidence95,
      'confidence_99': instance.confidence99,
    };

_AnalyticsAllocationSlice _$AnalyticsAllocationSliceFromJson(
        Map<String, dynamic> json) =>
    _AnalyticsAllocationSlice(
      ticker: json['ticker'] as String,
      percentage:
          json['percentage'] == null ? 0 : _safeDouble(json['percentage']),
      value: json['value'] == null ? 0 : _safeDouble(json['value']),
    );

Map<String, dynamic> _$AnalyticsAllocationSliceToJson(
        _AnalyticsAllocationSlice instance) =>
    <String, dynamic>{
      'ticker': instance.ticker,
      'percentage': instance.percentage,
      'value': instance.value,
    };
