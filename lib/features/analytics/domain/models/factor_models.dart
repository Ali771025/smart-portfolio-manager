/// Domain models for factor summary API responses.
/// Single factor exposure.
class FactorExposure {
  const FactorExposure({
    required this.factorType,
    required this.factorName,
    this.exposure,
    this.tStatistic,
    this.pValue,
    this.isSignificant = false,
    this.contributionReturnPct,
    this.contributionRiskPct,
  });

  final String factorType;
  final String factorName;
  final double? exposure;
  final double? tStatistic;
  final double? pValue;
  final bool isSignificant;
  final double? contributionReturnPct;
  final double? contributionRiskPct;

  factory FactorExposure.fromJson(Map<String, dynamic> json) {
    return FactorExposure(
      factorType: json['factor_type']?.toString() ?? '',
      factorName: json['factor_name']?.toString() ?? '',
      exposure: _parseDouble(json['exposure']),
      tStatistic: _parseDouble(json['t_statistic']),
      pValue: _parseDouble(json['p_value']),
      isSignificant: json['is_significant'] ?? false,
      contributionReturnPct: _parseDouble(json['contribution_return_pct']),
      contributionRiskPct: _parseDouble(json['contribution_risk_pct']),
    );
  }
}

/// Regression diagnostics.
class RegressionDiagnostics {
  const RegressionDiagnostics({
    this.rSquared,
    this.adjustedRSquared,
    this.alphaAnnualPct,
    this.alphaTStatistic,
    this.alphaIsSignificant = false,
    this.residualVolatilityPct,
    this.informationRatio,
    this.status = 'success',
    this.errorMessage,
    this.observationsCount = 0,
  });

  final double? rSquared;
  final double? adjustedRSquared;
  final double? alphaAnnualPct;
  final double? alphaTStatistic;
  final bool alphaIsSignificant;
  final double? residualVolatilityPct;
  final double? informationRatio;
  final String status;
  final String? errorMessage;
  final int observationsCount;

  factory RegressionDiagnostics.fromJson(Map<String, dynamic> json) {
    return RegressionDiagnostics(
      rSquared: _parseDouble(json['r_squared']),
      adjustedRSquared: _parseDouble(json['adjusted_r_squared']),
      alphaAnnualPct: _parseDouble(json['alpha_annual_pct']),
      alphaTStatistic: _parseDouble(json['alpha_t_statistic']),
      alphaIsSignificant: json['alpha_is_significant'] ?? false,
      residualVolatilityPct: _parseDouble(json['residual_volatility_pct']),
      informationRatio: _parseDouble(json['information_ratio']),
      status: json['status']?.toString() ?? 'success',
      errorMessage: json['error_message']?.toString(),
      observationsCount: json['observations_count'] ?? 0,
    );
  }
}

/// Factor summary response.
class FactorSummary {
  const FactorSummary({
    required this.portfolioId,
    required this.baseCurrency,
    required this.asOfDate,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.factors = const [],
    this.regression,
    this.totalReturnAttributedPct,
    this.totalReturnUnattributedPct,
    this.isFresh = true,
    this.isStale = false,
    this.lastComputedAt,
  });

  final String portfolioId;
  final String baseCurrency;
  final DateTime asOfDate;
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final List<FactorExposure> factors;
  final RegressionDiagnostics? regression;
  final double? totalReturnAttributedPct;
  final double? totalReturnUnattributedPct;
  final bool isFresh;
  final bool isStale;
  final DateTime? lastComputedAt;

  bool get hasData => factors.isNotEmpty;

  factory FactorSummary.fromJson(Map<String, dynamic> json) {
    return FactorSummary(
      portfolioId: json['portfolio_id']?.toString() ?? '',
      baseCurrency: json['base_currency']?.toString() ?? 'IRR',
      asOfDate: DateTime.parse(json['as_of_date'] ?? DateTime.now().toIso8601String()),
      period: json['period']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      factors: (json['factors'] as List?)
              ?.map((e) => FactorExposure.fromJson(e))
              .toList() ??
          [],
      regression: json['regression'] != null
          ? RegressionDiagnostics.fromJson(json['regression'])
          : null,
      totalReturnAttributedPct: _parseDouble(json['total_return_attributed_pct']),
      totalReturnUnattributedPct: _parseDouble(json['total_return_unattributed_pct']),
      isFresh: json['is_fresh'] ?? true,
      isStale: json['is_stale'] ?? false,
      lastComputedAt: json['last_computed_at'] != null
          ? DateTime.parse(json['last_computed_at'])
          : null,
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
