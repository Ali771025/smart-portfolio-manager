class FundSummary {
  const FundSummary({
    required this.fundId,
    required this.name,
    required this.source,
    this.type,
    this.nav,
    this.navDate,
    this.return1m,
    this.return3m,
    this.return6m,
    this.return1y,
  });

  final String fundId;
  final String name;
  final String? type;
  final double? nav;
  final DateTime? navDate;
  final double? return1m;
  final double? return3m;
  final double? return6m;
  final double? return1y;
  final String source;

  factory FundSummary.fromJson(Map<String, dynamic> json) => FundSummary(
        fundId: json['fund_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString(),
        nav: _nullableDouble(json['nav']),
        navDate: _nullableDate(json['nav_date']),
        return1m: _nullableDouble(json['return_1m']),
        return3m: _nullableDouble(json['return_3m']),
        return6m: _nullableDouble(json['return_6m']),
        return1y: _nullableDouble(json['return_1y']),
        source: json['source']?.toString() ?? '',
      );
}

class FundNavSnapshot {
  const FundNavSnapshot({
    required this.fundId,
    required this.navDate,
    required this.source,
    this.subscriptionNav,
    this.redemptionNav,
    this.statisticalNav,
  });

  final String fundId;
  final DateTime navDate;
  final double? subscriptionNav;
  final double? redemptionNav;
  final double? statisticalNav;
  final String source;

  factory FundNavSnapshot.fromJson(Map<String, dynamic> json) =>
      FundNavSnapshot(
        fundId: json['fund_id']?.toString() ?? '',
        navDate: _nullableDate(json['nav_date'])!,
        subscriptionNav: _nullableDouble(json['subscription_nav']),
        redemptionNav: _nullableDouble(json['redemption_nav']),
        statisticalNav: _nullableDouble(json['statistical_nav']),
        source: json['source']?.toString() ?? '',
      );
}

class RiskFreeBenchmark {
  const RiskFreeBenchmark({
    required this.name,
    required this.annualReturnPercent,
    required this.source,
    required this.isValid,
    required this.fallbackUsed,
    this.fundId,
    this.nav,
    this.navDate,
  });

  final String name;
  final double annualReturnPercent;
  final String source;
  final bool isValid;
  final bool fallbackUsed;
  final String? fundId;
  final double? nav;
  final DateTime? navDate;

  factory RiskFreeBenchmark.fromJson(Map<String, dynamic> json) {
    final annualReturn = _nullableDouble(json['annual_return_percent']);
    final valid = json['is_valid'] == true && annualReturn != null;
    if (!valid) {
      throw const FormatException('Invalid risk-free benchmark response');
    }
    return RiskFreeBenchmark(
      name: json['name']?.toString() ?? '',
      annualReturnPercent: annualReturn,
      source: json['source']?.toString() ?? '',
      isValid: true,
      fallbackUsed: json['fallback_used'] == true,
      fundId: json['fund_id']?.toString(),
      nav: _nullableDouble(json['nav']),
      navDate: _nullableDate(json['nav_date']),
    );
  }
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
