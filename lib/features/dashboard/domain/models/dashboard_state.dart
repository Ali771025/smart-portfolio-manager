double _asDouble(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return const <String, dynamic>{};
}

class DashboardData {
  const DashboardData({
    required this.metrics,
    required this.currency,
    this.portfolioCount = 0,
    this.assetAllocation = const <AssetAllocation>[],
    this.growthChart = const <GrowthPoint>[],
    this.assets = const <DashboardAsset>[],
    this.topAssets = const <DashboardAsset>[],
    this.topMovers = const <TopMoverItem>[],
    this.topPortfoliosByPnl = const <PortfolioPnlItem>[],
  });

  final DashboardMetrics metrics;
  final String currency;
  final int portfolioCount;
  final List<AssetAllocation> assetAllocation;
  final List<GrowthPoint> growthChart;
  final List<DashboardAsset> assets;
  final List<DashboardAsset> topAssets;
  final List<TopMoverItem> topMovers;
  final List<PortfolioPnlItem> topPortfoliosByPnl;

  factory DashboardData.fromSummaryJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final assetsJson = (data['assets'] as List<dynamic>? ?? const [])
        .map(_asMap)
        .toList(growable: false);
    final historyJson = (data['history'] as List<dynamic>? ?? const [])
        .map(_asMap)
        .toList(growable: false);
    final moversJson = (data['top_movers'] as List<dynamic>? ?? const [])
        .map(_asMap)
        .toList(growable: false);
    final topAssetsJson = (data['top_assets'] as List<dynamic>? ?? const [])
        .map(_asMap)
        .toList(growable: false);
    final topPortfoliosJson =
        (data['top_portfolios_by_pnl'] as List<dynamic>? ?? const [])
            .map(_asMap)
            .toList(growable: false);

    final assets = assetsJson.map(DashboardAsset.fromJson).toList(growable: false);
    final topAssets = topAssetsJson.isEmpty
        ? assets.take(10).toList(growable: false)
        : topAssetsJson.map(DashboardAsset.fromJson).toList(growable: false);
    final allocations = assets
        .map(
          (asset) => AssetAllocation(
            ticker: asset.symbol,
            percentage: asset.allocationPercent,
            value: asset.marketValue,
            colorHint: asset.colorHint,
          ),
        )
        .toList(growable: false);

    return DashboardData(
      metrics: DashboardMetrics(
        totalCurrentValue: _asDouble(data['total_balance']),
        totalCostBasis: _asDouble(data['total_cost_basis']),
        totalProfitLoss: _asDouble(data['total_profit_loss']),
        overallRoiPercent: _asDouble(data['profit_loss_percent']),
      ),
      currency: (data['currency'] ?? 'IRR').toString(),
      portfolioCount: _asInt(data['portfolio_count']),
      assetAllocation: allocations,
      growthChart: historyJson.map(GrowthPoint.fromJson).toList(growable: false),
      assets: assets,
      topAssets: topAssets,
      topMovers: moversJson.map(TopMoverItem.fromJson).toList(growable: false),
      topPortfoliosByPnl:
          topPortfoliosJson.map(PortfolioPnlItem.fromJson).toList(growable: false),
    );
  }
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.totalCurrentValue,
    required this.totalCostBasis,
    required this.totalProfitLoss,
    required this.overallRoiPercent,
  });

  final double totalCurrentValue;
  final double totalCostBasis;
  final double totalProfitLoss;
  final double overallRoiPercent;
}

class DashboardAsset {
  const DashboardAsset({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.avgBuyPrice,
    required this.currentPrice,
    required this.marketValue,
    required this.allocationPercent,
    required this.profitLoss,
    required this.colorHint,
  });

  final String symbol;
  final String name;
  final double quantity;
  final double avgBuyPrice;
  final double currentPrice;
  final double marketValue;
  final double allocationPercent;
  final double profitLoss;
  final String colorHint;

  factory DashboardAsset.fromJson(Map<String, dynamic> json) {
    return DashboardAsset(
      symbol: (json['symbol'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      quantity: _asDouble(json['quantity']),
      avgBuyPrice: _asDouble(json['avg_buy_price']),
      currentPrice: _asDouble(json['current_price']),
      marketValue: _asDouble(json['market_value']),
      allocationPercent: _asDouble(json['allocation_percent']),
      profitLoss: _asDouble(json['profit_loss']),
      colorHint: (json['color_hint'] ?? '#4F8CFF').toString(),
    );
  }
}

class AssetAllocation {
  const AssetAllocation({
    required this.ticker,
    required this.percentage,
    required this.value,
    required this.colorHint,
  });

  final String ticker;
  final double percentage;
  final double value;
  final String colorHint;
}

class GrowthPoint {
  const GrowthPoint({
    required this.date,
    required this.totalValue,
  });

  final String date;
  final double totalValue;

  factory GrowthPoint.fromJson(Map<String, dynamic> json) {
    return GrowthPoint(
      date: (json['date'] ?? '').toString(),
      totalValue: _asDouble(json['total_value'] ?? json['totalValue']),
    );
  }
}

class TopMoverItem {
  const TopMoverItem({
    required this.symbol,
    required this.name,
    required this.profitLoss,
    required this.profitLossPercent,
  });

  final String symbol;
  final String name;
  final double profitLoss;
  final double profitLossPercent;

  factory TopMoverItem.fromJson(Map<String, dynamic> json) {
    return TopMoverItem(
      symbol: (json['symbol'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      profitLoss: _asDouble(json['profit_loss']),
      profitLossPercent: _asDouble(json['profit_loss_percent']),
    );
  }
}

class PortfolioPnlItem {
  const PortfolioPnlItem({
    required this.portfolioId,
    required this.portfolioName,
    required this.totalValue,
    required this.totalCostBasis,
    required this.profitLoss,
    required this.profitLossPercent,
  });

  final String portfolioId;
  final String portfolioName;
  final double totalValue;
  final double totalCostBasis;
  final double profitLoss;
  final double profitLossPercent;

  factory PortfolioPnlItem.fromJson(Map<String, dynamic> json) {
    return PortfolioPnlItem(
      portfolioId: (json['portfolio_id'] ?? '').toString(),
      portfolioName: (json['portfolio_name'] ?? '').toString(),
      totalValue: _asDouble(json['total_value']),
      totalCostBasis: _asDouble(json['total_cost_basis']),
      profitLoss: _asDouble(json['profit_loss']),
      profitLossPercent: _asDouble(json['profit_loss_percent']),
    );
  }
}

class Failure {
  const Failure({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
