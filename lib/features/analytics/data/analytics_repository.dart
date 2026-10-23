import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/realtime_pnl_tick.dart';
import 'parsers/analytics_isolate_parser.dart';
import '../domain/models/analytics_models.dart';

part 'analytics_repository.g.dart';

abstract class AnalyticsRepository {
  Future<Either<AppFailure, AnalyticsPerformanceSeries>> fetchPerformance({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  });

  Future<Either<AppFailure, AnalyticsMetrics>> fetchMetrics({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  });

  Future<Either<AppFailure, List<AnalyticsAllocationSlice>>> fetchAllocation({
    required String portfolioId,
  });

  Future<Either<AppFailure, Uint8List>> fetchBenchmarkMsgPack({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  });

  Stream<Either<AppFailure, RealtimePnlTick>> watchRealtimePnl({
    required String portfolioId,
  });
}

class AnalyticsApiRepository implements AnalyticsRepository {
  AnalyticsApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  Future<Either<AppFailure, Uint8List>> _fetchBenchmarkJsonFallback({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
    required String token,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/benchmarking/portfolios/$portfolioId/twr-attribution',
      ).replace(
        queryParameters: _benchmarkQueryParams(
          timeframe: timeframe,
          responseFormat: 'json',
        ),
      );

      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchBenchmarkMsgPack.fallback',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
        );
        return Left(
          AppFailure(
            message: 'دریافت داده بنچمارک ناموفق بود.',
            statusCode: response.statusCode,
            isUnauthorized: response.statusCode == 401,
          ),
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchBenchmarkMsgPack.fallback',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: 0,
        );
        return const Left(
          AppFailure(message: 'پاسخ بنچمارک خالی بود.'),
        );
      }
      ImportAnalyticsRefreshTrace.logBackendResponse(
        traceId: traceId,
        providerName: 'analyticsRepository.fetchBenchmarkMsgPack.fallback',
        endpointPath: _uriPathWithQuery(uri),
        portfolioId: portfolioId,
        timeframe: timeframe.name,
        statusCode: response.statusCode,
        payloadSizeBytes: bytes.length,
        responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(bytes),
      );
      return Right(Uint8List.fromList(bytes));
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت داده بنچمارک به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در دریافت داده بنچمارک.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, AnalyticsPerformanceSeries>> fetchPerformance({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/analytics/performance').replace(
        queryParameters: <String, String>{
          'portfolio_id': portfolioId,
          'timeframe': timeframe.apiValue,
        },
      );

      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));
      final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchPerformance',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
        );
        return Left(
          AppFailure(
            message: 'دریافت داده نمودار عملکرد ناموفق بود.',
            statusCode: response.statusCode,
          ),
        );
      }

      final payloadResult = await parseJsonObjectPayload(response.body);
      return payloadResult.flatMap((payload) {
        try {
          final model = AnalyticsPerformanceSeries.fromJson(payload);
          final window = ImportAnalyticsRefreshTrace.dateWindow(
            model.points.map((point) => point.date),
          );
          ImportAnalyticsRefreshTrace.logBackendResponse(
            traceId: traceId,
            providerName: 'analyticsRepository.fetchPerformance',
            endpointPath: _uriPathWithQuery(uri),
            portfolioId: portfolioId,
            timeframe: timeframe.name,
            statusCode: response.statusCode,
            payloadSizeBytes: response.bodyBytes.length,
            responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
              response.bodyBytes,
            ),
            pointCount: model.points.length,
            seriesCount: 1,
            minDate: window.firstDate,
            maxDate: window.lastDate,
            updatedAt: _extractDateField(payload, const <String>['updated_at']),
            recomputedAt: _extractDateField(payload, const <String>[
              'recomputed_at',
              'analytics_updated_at',
            ]),
          );
          return Right(model);
        } catch (_) {
          return const Left(
            AppFailure(message: 'ساختار داده عملکرد قابل خواندن نیست.'),
          );
        }
      });
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت داده عملکرد به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در دریافت داده عملکرد.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, AnalyticsMetrics>> fetchMetrics({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/analytics/metrics').replace(
        queryParameters: <String, String>{
          'portfolio_id': portfolioId,
          'timeframe': timeframe.apiValue,
        },
      );

      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));
      final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchMetrics',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
        );
        return Left(
          AppFailure(
            message: 'دریافت شاخص‌های عملکرد ناموفق بود.',
            statusCode: response.statusCode,
          ),
        );
      }

      final payloadResult = await parseJsonObjectPayload(response.body);
      return payloadResult.flatMap((payload) {
        try {
          final model = AnalyticsMetrics.fromJson(payload);
          ImportAnalyticsRefreshTrace.logBackendResponse(
            traceId: traceId,
            providerName: 'analyticsRepository.fetchMetrics',
            endpointPath: _uriPathWithQuery(uri),
            portfolioId: portfolioId,
            timeframe: timeframe.name,
            statusCode: response.statusCode,
            payloadSizeBytes: response.bodyBytes.length,
            responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
              response.bodyBytes,
            ),
            pointCount: 1,
            seriesCount: 1,
            minDate: model.asOfDate,
            maxDate: model.asOfDate,
            updatedAt: _extractDateField(payload, const <String>['updated_at']),
            recomputedAt: _extractDateField(payload, const <String>[
              'recomputed_at',
              'analytics_updated_at',
            ]),
          );
          return Right(model);
        } catch (_) {
          return const Left(
            AppFailure(message: 'ساختار داده شاخص‌ها قابل خواندن نیست.'),
          );
        }
      });
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت شاخص‌های عملکرد به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در دریافت شاخص‌های عملکرد.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, List<AnalyticsAllocationSlice>>> fetchAllocation({
    required String portfolioId,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/dashboard/overview').replace(
        queryParameters: <String, String>{
          if (portfolioId.trim().isNotEmpty) 'portfolio_id': portfolioId,
        },
      );
      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));
      final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchAllocation',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
        );
        return Left(
          AppFailure(
            message: 'دریافت تخصیص دارایی ناموفق بود.',
            statusCode: response.statusCode,
          ),
        );
      }

      final payloadResult = await parseJsonObjectPayload(response.body);
      return payloadResult.flatMap((payload) {
        try {
          final rows = (payload['asset_allocation'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AnalyticsAllocationSlice.fromJson)
              .toList(growable: false);
          ImportAnalyticsRefreshTrace.logBackendResponse(
            traceId: traceId,
            providerName: 'analyticsRepository.fetchAllocation',
            endpointPath: _uriPathWithQuery(uri),
            portfolioId: portfolioId,
            statusCode: response.statusCode,
            payloadSizeBytes: response.bodyBytes.length,
            responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
              response.bodyBytes,
            ),
            pointCount: rows.length,
            seriesCount: rows.length,
            updatedAt: _extractDateField(payload, const <String>['updated_at']),
            recomputedAt: _extractDateField(payload, const <String>[
              'recomputed_at',
              'dashboard_updated_at',
            ]),
          );
          return Right(rows);
        } catch (_) {
          return const Left(
            AppFailure(message: 'ساختار داده تخصیص دارایی معتبر نیست.'),
          );
        }
      });
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت تخصیص دارایی به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در دریافت تخصیص دارایی.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, Uint8List>> fetchBenchmarkMsgPack({
    required String portfolioId,
    required AnalyticsTimeframe timeframe,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/benchmarking/portfolios/$portfolioId/twr-attribution',
      ).replace(
        queryParameters: _benchmarkQueryParams(
          timeframe: timeframe,
          responseFormat: 'msgpack',
        ),
      );

      final response = await client.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/msgpack',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchBenchmarkMsgPack',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
        );
        return _fetchBenchmarkJsonFallback(
          portfolioId: portfolioId,
          timeframe: timeframe,
          token: token,
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'analyticsRepository.fetchBenchmarkMsgPack',
          endpointPath: _uriPathWithQuery(uri),
          portfolioId: portfolioId,
          timeframe: timeframe.name,
          statusCode: response.statusCode,
          payloadSizeBytes: 0,
        );
        return _fetchBenchmarkJsonFallback(
          portfolioId: portfolioId,
          timeframe: timeframe,
          token: token,
        );
      }
      ImportAnalyticsRefreshTrace.logBackendResponse(
        traceId: traceId,
        providerName: 'analyticsRepository.fetchBenchmarkMsgPack',
        endpointPath: _uriPathWithQuery(uri),
        portfolioId: portfolioId,
        timeframe: timeframe.name,
        statusCode: response.statusCode,
        payloadSizeBytes: bytes.length,
        responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(bytes),
      );
      return Right(Uint8List.fromList(bytes));
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت داده بنچمارک به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در دریافت داده بنچمارک.'),
      );
    }
  }

  @override
  Stream<Either<AppFailure, RealtimePnlTick>> watchRealtimePnl({
    required String portfolioId,
  }) async* {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      yield const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      '$baseUrl/analytics-engine/portfolios/$portfolioId/pnl/stream',
    );
    final request = http.Request('GET', uri)
      ..headers.addAll(<String, String>{
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Authorization': 'Bearer $token',
      });

    late final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      yield const Left(
        AppFailure(
          message: 'اتصال بلادرنگ PNL با تاخیر مواجه شد.',
          isNetwork: true,
        ),
      );
      return;
    } catch (_) {
      yield const Left(
        AppFailure(
          message: 'برقراری استریم بلادرنگ PNL ناموفق بود.',
          isNetwork: true,
        ),
      );
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 503) {
        return;
      }
      yield Left(
        AppFailure(
          message: 'اتصال استریم PNL رد شد.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ),
      );
      return;
    }

    try {
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty || line.startsWith(':') || !line.startsWith('data:')) {
          continue;
        }

        final payloadResult = await parseServerSentEventLine(line);
        final Either<AppFailure, RealtimePnlTick> mapped =
            payloadResult.flatMap<RealtimePnlTick>((payload) {
          final isDegraded = payload['degraded'] == true;
          if (isDegraded) {
            return const Left<AppFailure, RealtimePnlTick>(
              AppFailure(message: 'degraded'),
            );
          }
          try {
            return Right<AppFailure, RealtimePnlTick>(
              RealtimePnlTick.fromJson(payload),
            );
          } catch (_) {
            return const Left<AppFailure, RealtimePnlTick>(
              AppFailure(
                message: 'پردازش پیام بلادرنگ PNL ناموفق بود.',
              ),
            );
          }
        });

        yield mapped;
      }
    } on http.ClientException {
      yield const Left(
        AppFailure(
          message: 'ارتباط بلادرنگ PNL قطع شد.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      yield const Left(
        AppFailure(
          message: 'خواندن استریم بلادرنگ PNL ناموفق بود.',
          isNetwork: true,
        ),
      );
    }
  }
}

String _benchmarkWindowFromTimeframe(AnalyticsTimeframe timeframe) {
  return switch (timeframe) {
    AnalyticsTimeframe.oneMonth => '1M',
    AnalyticsTimeframe.threeMonths => '3M',
    AnalyticsTimeframe.sixMonths => 'CUSTOM',
    AnalyticsTimeframe.oneYear => '1Y',
    AnalyticsTimeframe.all => '1Y',
  };
}

Map<String, String> _benchmarkQueryParams({
  required AnalyticsTimeframe timeframe,
  required String responseFormat,
}) {
  final window = _benchmarkWindowFromTimeframe(timeframe);
  final query = <String, String>{
    'window': window,
    'response_format': responseFormat,
  };

  if (window == 'CUSTOM') {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month - 6, now.day);
    query['window_start'] = _formatApiDate(start);
    query['window_end'] = _formatApiDate(now);
  }
  return query;
}

String _formatApiDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _uriPathWithQuery(Uri uri) {
  if (!uri.hasQuery || uri.query.trim().isEmpty) {
    return uri.path;
  }
  return '${uri.path}?${uri.query}';
}

DateTime? _extractDateField(
  Map<String, dynamic> payload,
  List<String> candidateKeys,
) {
  for (final key in candidateKeys) {
    final direct = payload[key];
    final directDate = _tryParseDate(direct);
    if (directDate != null) {
      return directDate;
    }
  }
  final nested = payload['data'];
  if (nested is Map<String, dynamic>) {
    for (final key in candidateKeys) {
      final value = nested[key];
      final date = _tryParseDate(value);
      if (date != null) {
        return date;
      }
    }
  }
  return null;
}

DateTime? _tryParseDate(Object? raw) {
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw.toString())?.toUtc();
}

@Riverpod(keepAlive: true)
AnalyticsRepository analyticsRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return AnalyticsApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () =>
        ref.read(authControllerProvider).value?.accessToken,
  );
}
