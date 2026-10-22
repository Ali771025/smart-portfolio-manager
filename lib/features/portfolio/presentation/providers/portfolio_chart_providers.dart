import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portfolio_chart_repository.dart';
import '../../domain/portfolio_chart_models.dart';

/// Portfolio holdings list provider (family by portfolioId).
final portfolioHoldingsProvider = FutureProvider.autoDispose
    .family<PortfolioHoldingsListResponse, String>((ref, portfolioId) async {
  final repo = ref.watch(portfolioChartRepositoryProvider);
  final result = await repo.getHoldings(portfolioId: portfolioId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Symbol analytics provider (family by portfolioId+symbol).
final symbolAnalyticsProvider = FutureProvider.autoDispose
    .family<SymbolAnalyticsResponse, ({String portfolioId, String symbol, String period, bool includeMonthly, bool includeBenchmark, String? benchmarkId})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getSymbolAnalytics(
      portfolioId: params.portfolioId,
      symbol: params.symbol,
      period: params.period,
      includeMonthly: params.includeMonthly,
      includeBenchmark: params.includeBenchmark,
      benchmarkId: params.benchmarkId,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// Symbol chart data provider (family by portfolioId+symbol+params).
final symbolChartDataProvider = FutureProvider.autoDispose
    .family<SymbolChartResponse, ({String portfolioId, String symbol, String chartType, String period})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getSymbolChart(
      portfolioId: params.portfolioId,
      symbol: params.symbol,
      chartType: params.chartType,
      period: params.period,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// Capital growth chart provider (family by portfolioId+period).
final capitalGrowthChartProvider = FutureProvider.autoDispose
    .family<CapitalGrowthResponse, ({String portfolioId, String period})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getCapitalGrowth(
      portfolioId: params.portfolioId,
      period: params.period,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// Asset value chart provider.
final assetValueChartProvider = FutureProvider.autoDispose
    .family<PortfolioChartResponse, ({String portfolioId, String period})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getAssetValueChart(
      portfolioId: params.portfolioId,
      period: params.period,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// Symbol performance chart provider.
final symbolPerformanceChartProvider = FutureProvider.autoDispose
    .family<PortfolioChartResponse, ({String portfolioId, String period})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getSymbolPerformanceChart(
      portfolioId: params.portfolioId,
      period: params.period,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// Monthly returns chart provider (family by portfolioId+year).
final monthlyReturnsChartProvider = FutureProvider.autoDispose
    .family<MonthlyReturnsResponse, ({String portfolioId, int? year})>(
  (ref, params) async {
    final repo = ref.watch(portfolioChartRepositoryProvider);
    final result = await repo.getMonthlyReturns(
      portfolioId: params.portfolioId,
      year: params.year,
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  },
);

/// PnL summary provider (family by portfolioId).
final portfolioPnLSummaryProvider = FutureProvider.autoDispose
    .family<PortfolioPnLSummary, String>((ref, portfolioId) async {
  final repo = ref.watch(portfolioChartRepositoryProvider);
  final result = await repo.getPnLSummary(portfolioId: portfolioId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Performance timeseries provider.
final performanceTimeseriesProvider = FutureProvider.autoDispose
    .family<PerformanceTimeseriesResponse, String>((ref, portfolioId) async {
  final repo = ref.watch(portfolioChartRepositoryProvider);
  final result = await repo.getPerformanceTimeseries(portfolioId: portfolioId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Monthly backend report provider.
final monthlyPortfolioReportProvider = FutureProvider.autoDispose
    .family<MonthlyPortfolioReportResponse,
        ({String portfolioId, int year, int month})>((ref, params) async {
  final repo = ref.watch(portfolioChartRepositoryProvider);
  final result = await repo.getMonthlyReport(
    portfolioId: params.portfolioId,
    year: params.year,
    month: params.month,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});

/// Yearly backend report provider.
final yearlyPortfolioReportProvider = FutureProvider.autoDispose
    .family<YearlyPortfolioReportResponse, ({String portfolioId, int year})>(
        (ref, params) async {
  final repo = ref.watch(portfolioChartRepositoryProvider);
  final result = await repo.getYearlyReport(
    portfolioId: params.portfolioId,
    year: params.year,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (data) => data,
  );
});
