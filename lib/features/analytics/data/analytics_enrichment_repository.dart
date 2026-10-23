/// Repository for Analytics Enrichment API calls.
///
/// Provides methods to fetch:
/// - Historical returns
/// - Benchmark comparisons
/// - Factor summaries
///
/// All methods return `Either<AppFailure, T>` for error handling.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/benchmark_comparison_models.dart';
import '../domain/models/factor_models.dart';
import '../domain/models/returns_models.dart';

part 'analytics_enrichment_repository.g.dart';

/// Abstract repository interface for analytics enrichment.
abstract class AnalyticsEnrichmentRepository {
  /// Get returns summary for an asset.
  Future<Either<AppFailure, ReturnsSummary>> getAssetReturnsSummary({
    required String assetId,
    DateTime? asOfDate,
  });

  /// Get returns summary by ticker symbol.
  Future<Either<AppFailure, ReturnsSummary>> getTickerReturnsSummary({
    required String ticker,
    DateTime? asOfDate,
  });

  /// Get return series for charting.
  Future<Either<AppFailure, ReturnSeriesResponse>> getAssetReturnSeries({
    required String assetId,
    required String period,
    DateTime? asOfDate,
  });

  /// Compare asset against multiple benchmarks.
  Future<Either<AppFailure, BenchmarkComparisonSummary>> compareAssetBenchmarks({
    required String assetId,
    String benchmarkIds = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  });

  /// Compare ticker against multiple benchmarks.
  Future<Either<AppFailure, BenchmarkComparisonSummary>> compareTickerBenchmarks({
    required String ticker,
    String benchmarkIds = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  });

  /// Compare asset against single benchmark.
  Future<Either<AppFailure, BenchmarkComparisonResult>> compareAssetSingleBenchmark({
    required String assetId,
    String benchmarkId = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  });

  /// Get comparison time series.
  Future<Either<AppFailure, ComparisonSeriesResponse>> getComparisonSeries({
    required String assetId,
    String benchmarkId = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  });

  /// Get factor summary for an asset.
  Future<Either<AppFailure, FactorSummary>> getAssetFactorSummary({
    required String assetId,
    String period = '1Y',
    DateTime? asOfDate,
  });

  /// Get factor summary by ticker symbol.
  Future<Either<AppFailure, FactorSummary>> getTickerFactorSummary({
    required String ticker,
    String period = '1Y',
    DateTime? asOfDate,
  });
}

/// API implementation of AnalyticsEnrichmentRepository.
class AnalyticsEnrichmentApiRepository implements AnalyticsEnrichmentRepository {
  AnalyticsEnrichmentApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  String? get _token => readAccessToken()?.trim();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  // ═══════════════════════════════════════════════════════════════
  // Returns Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, ReturnsSummary>> getAssetReturnsSummary({
    required String assetId,
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/returns/asset/$assetId/summary').replace(
        queryParameters: {
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت داده بازده ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(ReturnsSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت داده بازده به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت داده بازده.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, ReturnsSummary>> getTickerReturnsSummary({
    required String ticker,
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/returns/ticker/$ticker/summary').replace(
        queryParameters: {
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return Left(AppFailure(
          message: 'نماد $ticker یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت داده بازده ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(ReturnsSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت داده بازده به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت داده بازده.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, ReturnSeriesResponse>> getAssetReturnSeries({
    required String assetId,
    required String period,
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/returns/asset/$assetId/series').replace(
        queryParameters: {
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت سری بازده ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(ReturnSeriesResponse.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت سری بازده به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت سری بازده.',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Benchmark Comparison Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, BenchmarkComparisonSummary>> compareAssetBenchmarks({
    required String assetId,
    String benchmarkIds = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/benchmarks/compare/$assetId').replace(
        queryParameters: {
          'benchmark_ids': benchmarkIds,
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت مقایسه بنچمارک ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(BenchmarkComparisonSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت مقایسه بنچمارک به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت مقایسه بنچمارک.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, BenchmarkComparisonSummary>> compareTickerBenchmarks({
    required String ticker,
    String benchmarkIds = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/benchmarks/ticker/$ticker/compare').replace(
        queryParameters: {
          'benchmark_ids': benchmarkIds,
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        return Left(AppFailure(
          message: 'نماد $ticker یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت مقایسه بنچمارک ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(BenchmarkComparisonSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت مقایسه بنچمارک به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت مقایسه بنچمارک.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, BenchmarkComparisonResult>> compareAssetSingleBenchmark({
    required String assetId,
    String benchmarkId = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/benchmarks/compare/$assetId/single').replace(
        queryParameters: {
          'benchmark_id': benchmarkId,
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت مقایسه بنچمارک ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(BenchmarkComparisonResult.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت مقایسه بنچمارک به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت مقایسه بنچمارک.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, ComparisonSeriesResponse>> getComparisonSeries({
    required String assetId,
    String benchmarkId = 'TEDPIX',
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/benchmarks/compare/$assetId/series').replace(
        queryParameters: {
          'benchmark_id': benchmarkId,
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت سری مقایسه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(ComparisonSeriesResponse.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت سری مقایسه به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت سری مقایسه.',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Factor Summary Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, FactorSummary>> getAssetFactorSummary({
    required String assetId,
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/factors/asset/$assetId').replace(
        queryParameters: {
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت عوامل ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(FactorSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت عوامل به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت عوامل.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, FactorSummary>> getTickerFactorSummary({
    required String ticker,
    String period = '1Y',
    DateTime? asOfDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/factors/ticker/$ticker').replace(
        queryParameters: {
          'period': period,
          if (asOfDate != null) 'as_of_date': _formatDate(asOfDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return Left(AppFailure(
          message: 'نماد $ticker یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت عوامل ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(FactorSummary.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت عوامل به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت عوامل.',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

/// Riverpod provider for analytics enrichment repository.
@Riverpod(keepAlive: true)
AnalyticsEnrichmentRepository analyticsEnrichmentRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return AnalyticsEnrichmentApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () =>
        ref.read(authControllerProvider).value?.accessToken,
  );
}
