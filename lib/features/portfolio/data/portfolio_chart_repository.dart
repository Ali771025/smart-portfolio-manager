import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/portfolio_chart_models.dart';

part 'portfolio_chart_repository.g.dart';

abstract class PortfolioChartRepository {
  Future<Either<AppFailure, PortfolioHoldingsListResponse>> getHoldings({
    required String portfolioId,
  });

  Future<Either<AppFailure, SymbolAnalyticsResponse>> getSymbolAnalytics({
    required String portfolioId,
    required String symbol,
    String period = '1Y',
    bool includeMonthly = false,
    int? monthlyYear,
    bool includeBenchmark = false,
    String? benchmarkId,
  });

  Future<Either<AppFailure, SymbolChartResponse>> getSymbolChart({
    required String portfolioId,
    required String symbol,
    String chartType = 'performance',
    String period = '1Y',
    String? startDate,
    String? endDate,
  });

  Future<Either<AppFailure, CapitalGrowthResponse>> getCapitalGrowth({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
  });

  Future<Either<AppFailure, PortfolioChartResponse>> getAssetValueChart({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
    List<String>? symbols,
  });

  Future<Either<AppFailure, PortfolioChartResponse>> getSymbolPerformanceChart({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
    List<String>? symbols,
  });

  Future<Either<AppFailure, MonthlyReturnsResponse>> getMonthlyReturns({
    required String portfolioId,
    int? year,
    List<String>? symbols,
  });

  Future<Either<AppFailure, PortfolioPnLSummary>> getPnLSummary({
    required String portfolioId,
  });

  Future<Either<AppFailure, PerformanceTimeseriesResponse>>
      getPerformanceTimeseries({
    required String portfolioId,
    String? startDate,
    String? endDate,
  });

  Future<Either<AppFailure, MonthlyPortfolioReportResponse>> getMonthlyReport({
    required String portfolioId,
    required int year,
    required int month,
  });

  Future<Either<AppFailure, YearlyPortfolioReportResponse>> getYearlyReport({
    required String portfolioId,
    required int year,
  });
}

class PortfolioChartApiRepository implements PortfolioChartRepository {
  PortfolioChartApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  Map<String, String> _headers(String token,
      [String accept = 'application/json']) {
    return <String, String>{
      'Accept': accept,
      'Authorization': 'Bearer $token',
    };
  }

  Either<AppFailure, String> _requireToken() {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری شما معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }
    return Right(token);
  }

  AppFailure? _tokenFailure(Either<AppFailure, String> result) {
    return result.fold((failure) => failure, (_) => null);
  }

  String _tokenValue(Either<AppFailure, String> result) {
    return result.fold((_) => '', (token) => token);
  }

  Map<String, String> _queryParams({
    String? period,
    String? startDate,
    String? endDate,
    List<String>? symbols,
    int? year,
    String? chartType,
    bool? includeMonthly,
    int? monthlyYear,
    bool? includeBenchmark,
    String? benchmarkId,
    String? timeframe,
  }) {
    final params = <String, String>{};
    if (period != null) params['period'] = period;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (symbols != null && symbols.isNotEmpty) {
      params['symbols'] = symbols.join(',');
    }
    if (year != null) params['year'] = year.toString();
    if (chartType != null) params['chart_type'] = chartType;
    if (includeMonthly == true) params['include_monthly'] = 'true';
    if (monthlyYear != null) params['monthly_year'] = monthlyYear.toString();
    if (includeBenchmark == true) params['include_benchmark'] = 'true';
    if (benchmarkId != null) params['benchmark_id'] = benchmarkId;
    if (timeframe != null) params['timeframe'] = timeframe;
    return params;
  }

  Future<http.Response> _get(
    String path,
    String token, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final finalUri = queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
    return client
        .get(finalUri, headers: _headers(token))
        .timeout(const Duration(seconds: 12));
  }

  @override
  Future<Either<AppFailure, PortfolioHoldingsListResponse>> getHoldings({
    required String portfolioId,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      var response = await _get('/portfolios/$portfolioId/holdings', token);
      if (response.statusCode == 404) {
        response = await _get('/portfolios/$portfolioId/symbols', token);
      }
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت لیست نمادها ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(PortfolioHoldingsListResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده نمادها قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت لیست نمادها به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت لیست نمادها.'));
    }
  }

  @override
  Future<Either<AppFailure, SymbolAnalyticsResponse>> getSymbolAnalytics({
    required String portfolioId,
    required String symbol,
    String period = '1Y',
    bool includeMonthly = false,
    int? monthlyYear,
    bool includeBenchmark = false,
    String? benchmarkId,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(
        period: period,
        includeMonthly: includeMonthly,
        monthlyYear: monthlyYear,
        includeBenchmark: includeBenchmark,
        benchmarkId: benchmarkId,
      );
      final response = await _get(
        '/portfolios/$portfolioId/symbols/$symbol/analytics',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت تحلیل نماد ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(SymbolAnalyticsResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده تحلیل نماد قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت تحلیل نماد به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت تحلیل نماد.'));
    }
  }

  @override
  Future<Either<AppFailure, SymbolChartResponse>> getSymbolChart({
    required String portfolioId,
    required String symbol,
    String chartType = 'performance',
    String period = '1Y',
    String? startDate,
    String? endDate,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(
        chartType: chartType,
        period: period,
        startDate: startDate,
        endDate: endDate,
      );
      final response = await _get(
        '/portfolios/$portfolioId/symbols/$symbol/charts',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت نمودار نماد ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(SymbolChartResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده نمودار نماد قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت نمودار نماد به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت نمودار نماد.'));
    }
  }

  @override
  Future<Either<AppFailure, CapitalGrowthResponse>> getCapitalGrowth({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params =
          _queryParams(period: period, startDate: startDate, endDate: endDate);
      final response = await _get(
        '/portfolios/$portfolioId/charts/capital-growth',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت نمودار رشد سرمایه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(CapitalGrowthResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده رشد سرمایه قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت رشد سرمایه به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت رشد سرمایه.'));
    }
  }

  @override
  Future<Either<AppFailure, PortfolioChartResponse>> getAssetValueChart({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
    List<String>? symbols,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(
          period: period,
          startDate: startDate,
          endDate: endDate,
          symbols: symbols);
      final response = await _get(
        '/portfolios/$portfolioId/charts/asset-value',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت نمودار ارزش دارایی‌ها ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(PortfolioChartResponse.fromJson(body));
      } catch (_) {
        return const Left(AppFailure(
            message: 'ساختار داده ارزش دارایی‌ها قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت ارزش دارایی‌ها به پایان رسید.',
          isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت ارزش دارایی‌ها.'));
    }
  }

  @override
  Future<Either<AppFailure, PortfolioChartResponse>> getSymbolPerformanceChart({
    required String portfolioId,
    String period = '1Y',
    String? startDate,
    String? endDate,
    List<String>? symbols,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(
          period: period,
          startDate: startDate,
          endDate: endDate,
          symbols: symbols);
      final response = await _get(
        '/portfolios/$portfolioId/charts/symbol-performance',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت نمودار عملکرد نمادها ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(PortfolioChartResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده عملکرد نمادها قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت عملکرد نمادها به پایان رسید.',
          isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت عملکرد نمادها.'));
    }
  }

  @override
  Future<Either<AppFailure, MonthlyReturnsResponse>> getMonthlyReturns({
    required String portfolioId,
    int? year,
    List<String>? symbols,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(year: year, symbols: symbols);
      final response = await _get(
        '/portfolios/$portfolioId/charts/monthly-returns',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت بازدهی ماهانه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(MonthlyReturnsResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده بازدهی ماهانه قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت بازدهی ماهانه به پایان رسید.',
          isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت بازدهی ماهانه.'));
    }
  }

  @override
  Future<Either<AppFailure, PortfolioPnLSummary>> getPnLSummary({
    required String portfolioId,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      var response =
          await _get('/portfolios/$portfolioId/summary/frontend', token);
      if (response.statusCode == 404) {
        response =
            await _get('/portfolios/$portfolioId/performance/summary', token);
      }
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت خلاصه سود و زیان ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(PortfolioPnLSummary.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده سود و زیان قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت سود و زیان به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت سود و زیان.'));
    }
  }

  @override
  Future<Either<AppFailure, PerformanceTimeseriesResponse>>
      getPerformanceTimeseries({
    required String portfolioId,
    String? startDate,
    String? endDate,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final params = _queryParams(startDate: startDate, endDate: endDate);
      final response = await _get(
        '/portfolios/$portfolioId/performance/timeseries',
        token,
        queryParams: params,
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت سری زمانی عملکرد ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(PerformanceTimeseriesResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده سری زمانی قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت سری زمانی به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت سری زمانی.'));
    }
  }

  @override
  Future<Either<AppFailure, MonthlyPortfolioReportResponse>> getMonthlyReport({
    required String portfolioId,
    required int year,
    required int month,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final response = await _get(
        '/reports/monthly',
        token,
        queryParams: <String, String>{
          'portfolio_id': portfolioId,
          'year': year.toString(),
          'month': month.toString(),
        },
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت گزارش ماهانه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(MonthlyPortfolioReportResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده گزارش ماهانه قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت گزارش ماهانه به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت گزارش ماهانه.'));
    }
  }

  @override
  Future<Either<AppFailure, YearlyPortfolioReportResponse>> getYearlyReport({
    required String portfolioId,
    required int year,
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure = _tokenFailure(tokenResult);
    if (tokenFailure != null) return Left(tokenFailure);
    final token = _tokenValue(tokenResult);

    try {
      final response = await _get(
        '/reports/yearly',
        token,
        queryParams: <String, String>{
          'portfolio_id': portfolioId,
          'year': year.toString(),
        },
      );
      if (response.statusCode != 200) {
        return Left(AppFailure(
          message: 'دریافت گزارش سالانه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Right(YearlyPortfolioReportResponse.fromJson(body));
      } catch (_) {
        return const Left(
            AppFailure(message: 'ساختار داده گزارش سالانه قابل خواندن نیست.'));
      }
    } on TimeoutException {
      return const Left(AppFailure(
          message: 'مهلت دریافت گزارش سالانه به پایان رسید.', isNetwork: true));
    } catch (_) {
      return const Left(
          AppFailure(message: 'خطای ناشناخته در دریافت گزارش سالانه.'));
    }
  }
}

@Riverpod(keepAlive: true)
PortfolioChartRepository portfolioChartRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PortfolioChartApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
}
