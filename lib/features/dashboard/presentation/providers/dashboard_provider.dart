import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_base_url.dart';
import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/dashboard_state.dart';

const _defaultAccessToken = String.fromEnvironment(
  'ACCESS_TOKEN',
  defaultValue: '',
);
const _dashboardTracePortfolioId = 'ALL_PORTFOLIOS';

class DashboardFailureException implements Exception {
  const DashboardFailureException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.message;
}

abstract class DashboardRepository {
  Future<Either<Failure, DashboardData>> fetchDashboardData({
    String? portfolioId,
  });
}

class DashboardApiRepository implements DashboardRepository {
  DashboardApiRepository({
    required this.client,
    required this.baseUrl,
    required this.accessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String accessToken;

  @override
  Future<Either<Failure, DashboardData>> fetchDashboardData({
    String? portfolioId,
  }) async {
    if (accessToken.trim().isEmpty) {
      return const Left(
        Failure(
          message: 'توکن دسترسی تنظیم نشده است.',
          statusCode: 401,
        ),
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final normalizedPortfolioId = portfolioId?.trim() ?? '';
      final summaryUri = Uri.parse('$baseUrl/dashboard/summary').replace(
        queryParameters: normalizedPortfolioId.isEmpty
            ? null
            : <String, String>{'portfolio_id': normalizedPortfolioId},
      );
      final response = await client
          .get(summaryUri, headers: headers)
          .timeout(const Duration(seconds: 12));
      final traceId = normalizedPortfolioId.isEmpty
          ? null
          : ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (normalizedPortfolioId.isNotEmpty) {
          ImportAnalyticsRefreshTrace.logBackendResponse(
            traceId: traceId,
            providerName: 'dashboardControllerProvider',
            endpointPath: _uriPathWithQuery(summaryUri),
            portfolioId: normalizedPortfolioId,
            statusCode: response.statusCode,
            payloadSizeBytes: response.bodyBytes.length,
            responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
              response.bodyBytes,
            ),
          );
        }
        return Left(
          Failure(
            message: 'دریافت اطلاعات داشبورد با خطا مواجه شد.',
            statusCode: response.statusCode,
          ),
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const Left(
          Failure(message: 'ساختار پاسخ داشبورد معتبر نیست.'),
        );
      }
      final status = (payload['status'] ?? '').toString().toLowerCase();
      if (status != 'success') {
        return const Left(
          Failure(message: 'پاسخ داشبورد موفق نبود.'),
        );
      }

      final model = DashboardData.fromSummaryJson(payload);
      if (normalizedPortfolioId.isNotEmpty) {
        final dates = model.growthChart
            .map((item) => DateTime.tryParse(item.date))
            .whereType<DateTime>()
            .map((item) => item.toUtc());
        final window = ImportAnalyticsRefreshTrace.dateWindow(dates);
        ImportAnalyticsRefreshTrace.logBackendResponse(
          traceId: traceId,
          providerName: 'dashboardControllerProvider',
          endpointPath: _uriPathWithQuery(summaryUri),
          portfolioId: normalizedPortfolioId,
          statusCode: response.statusCode,
          payloadSizeBytes: response.bodyBytes.length,
          responseFingerprint: ImportAnalyticsRefreshTrace.fingerprintFromBytes(
            response.bodyBytes,
          ),
          pointCount: model.growthChart.length,
          seriesCount: model.assetAllocation.length,
          minDate: window.firstDate,
          maxDate: window.lastDate,
          updatedAt: _extractDateField(payload, const <String>['updated_at']),
          recomputedAt: _extractDateField(payload, const <String>[
            'recomputed_at',
            'dashboard_updated_at',
          ]),
        );
      }
      return Right(model);
    } on TimeoutException {
      return const Left(
        Failure(
          message: 'مهلت دریافت اطلاعات داشبورد به پایان رسید.',
        ),
      );
    } catch (_) {
      return const Left(
        Failure(
          message: 'خطای پیش‌بینی‌نشده در دریافت داشبورد رخ داد.',
        ),
      );
    }
  }
}

final dashboardApiBaseUrlProvider = Provider<String>(
  (ref) => defaultApiBaseUrl,
);

final dashboardAuthTokenProvider = StateProvider<String>(
  (ref) => _defaultAccessToken,
);

final dashboardHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final sessionToken =
      ref.watch(authControllerProvider).value?.accessToken.trim() ?? '';
  final fallbackToken = ref.watch(dashboardAuthTokenProvider).trim();
  final accessToken = sessionToken.isNotEmpty ? sessionToken : fallbackToken;

  return DashboardApiRepository(
    client: ref.watch(dashboardHttpClientProvider),
    baseUrl: ref.watch(dashboardApiBaseUrlProvider),
    accessToken: accessToken,
  );
});

class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final repository = ref.watch(dashboardRepositoryProvider);
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      providerName: 'dashboardControllerProvider',
      portfolioId: _dashboardTracePortfolioId,
      repositoryMethod: 'DashboardController.build',
      endpointPath: '/dashboard/summary',
    );
    final data = await _load(
      repository,
    );
    _logDashboardReady(data);
    return data;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      providerName: 'dashboardControllerProvider',
      portfolioId: _dashboardTracePortfolioId,
      repositoryMethod: 'DashboardController.reload',
      endpointPath: '/dashboard/summary',
    );
    state = await AsyncValue.guard(
      () => _load(
        ref.read(dashboardRepositoryProvider),
      ),
    );
    final data = state.value;
    if (data != null) {
      _logDashboardReady(data);
    }
  }

  Future<DashboardData> _load(
    DashboardRepository repository, {
    String? portfolioId,
  }) async {
    final result = await repository.fetchDashboardData(portfolioId: portfolioId);
    return result.match(
      (failure) => throw DashboardFailureException(failure),
      (data) => data,
    );
  }

  void _logDashboardReady(DashboardData data) {
    final dates = data.growthChart
        .map((item) => DateTime.tryParse(item.date))
        .whereType<DateTime>()
        .map((item) => item.toUtc());
    final window = ImportAnalyticsRefreshTrace.dateWindow(dates);
    final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
      <Object?>[
        data.portfolioCount,
        data.metrics.totalCurrentValue,
        data.metrics.totalProfitLoss,
        data.metrics.overallRoiPercent,
        data.assetAllocation.length,
        data.topPortfoliosByPnl.length,
        data.topAssets.length,
        data.growthChart.length,
        window.firstDate?.millisecondsSinceEpoch,
        window.lastDate?.millisecondsSinceEpoch,
      ],
    );
    ImportAnalyticsRefreshTrace.logProviderDataReady(
      providerName: 'dashboardControllerProvider',
      portfolioId: _dashboardTracePortfolioId,
      pointCount: data.growthChart.length,
      firstDate: window.firstDate,
      lastDate: window.lastDate,
      dataFingerprint: fingerprint,
    );
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
  DashboardController.new,
);

final assetAllocationChartDataProvider = Provider<List<AssetAllocation>>((ref) {
  return ref.watch(
    dashboardControllerProvider.select(
      (state) => state.value?.assetAllocation ?? const <AssetAllocation>[],
    ),
  );
});

class FallbackMonitoringSnapshot {
  const FallbackMonitoringSnapshot({
    required this.generatedAt,
    required this.sseDegradedTotal,
    required this.msgpackJsonFallbackTotal,
    required this.sseDegradedByChannel,
    required this.msgpackFallbackByRoute,
    required this.lastSseDegradedAt,
    required this.lastMsgpackFallbackAt,
  });

  final DateTime? generatedAt;
  final int sseDegradedTotal;
  final int msgpackJsonFallbackTotal;
  final Map<String, int> sseDegradedByChannel;
  final Map<String, int> msgpackFallbackByRoute;
  final DateTime? lastSseDegradedAt;
  final DateTime? lastMsgpackFallbackAt;

  factory FallbackMonitoringSnapshot.fromJson(Map<String, dynamic> json) {
    return FallbackMonitoringSnapshot(
      generatedAt: _tryParseDateTime(json['generated_at']),
      sseDegradedTotal: _asInt(json['sse_degraded_total']),
      msgpackJsonFallbackTotal: _asInt(json['msgpack_json_fallback_total']),
      sseDegradedByChannel: _asIntMap(json['sse_degraded_by_channel']),
      msgpackFallbackByRoute: _asIntMap(json['msgpack_fallback_by_route']),
      lastSseDegradedAt: _tryParseDateTime(json['last_sse_degraded_at']),
      lastMsgpackFallbackAt: _tryParseDateTime(json['last_msgpack_fallback_at']),
    );
  }
}

DateTime? _tryParseDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw.toString())?.toUtc();
}

int _asInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

Map<String, int> _asIntMap(Object? raw) {
  if (raw is! Map) {
    return const <String, int>{};
  }
  return raw.map<String, int>(
    (key, value) => MapEntry(key.toString(), _asInt(value)),
  );
}

final fallbackMonitoringProvider =
    FutureProvider.autoDispose<FallbackMonitoringSnapshot?>((ref) async {
  return _fetchFallbackMonitoring(ref);
});

final fallbackMonitoringLiveProvider =
    StreamProvider.autoDispose<FallbackMonitoringSnapshot?>((ref) async* {
  while (true) {
    try {
      yield await _fetchFallbackMonitoring(ref);
    } catch (_) {
      yield null;
    }
    await Future<void>.delayed(const Duration(seconds: 12));
  }
});

Future<FallbackMonitoringSnapshot?> _fetchFallbackMonitoring(Ref ref) async {
  final session = ref.watch(authControllerProvider).value;
  final token = session?.accessToken.trim() ?? '';
  if (token.isEmpty) {
    return null;
  }

  final client = ref.watch(dashboardHttpClientProvider);
  final uri = Uri.parse('${ref.watch(dashboardApiBaseUrlProvider)}/monitoring/fallbacks');
  final response = await client.get(
    uri,
    headers: <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode == 401 || response.statusCode == 403) {
    return null;
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw DashboardFailureException(
      Failure(
        message: 'دریافت مانیتورینگ Fallback ناموفق بود.',
        statusCode: response.statusCode,
      ),
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! Map<String, dynamic>) {
    throw const DashboardFailureException(
      Failure(message: 'ساختار داده مانیتورینگ معتبر نیست.'),
    );
  }
  return FallbackMonitoringSnapshot.fromJson(payload);
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
    final date = _tryParseDate(direct);
    if (date != null) {
      return date;
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
