/// Repository for Watchlist and Alert API calls.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/watchlist_models.dart';

part 'watchlist_repository.g.dart';

/// Abstract repository interface for watchlist and alerts.
abstract class WatchlistRepository {
  /// List all watchlists for the user.
  Future<Either<AppFailure, List<Watchlist>>> listWatchlists();

  /// Create a new watchlist.
  Future<Either<AppFailure, Watchlist>> createWatchlist({
    required String name,
    String? description,
  });

  /// Get a specific watchlist.
  Future<Either<AppFailure, Watchlist>> getWatchlist({
    required String watchlistId,
  });

  /// Update a watchlist.
  Future<Either<AppFailure, Watchlist>> updateWatchlist({
    required String watchlistId,
    String? name,
    String? description,
  });

  /// Add or remove symbols in a watchlist.
  Future<Either<AppFailure, Watchlist>> updateWatchlistSymbols({
    required String watchlistId,
    List<String> addSymbols = const [],
    List<String> removeSymbols = const [],
  });

  /// Delete a watchlist.
  Future<Either<AppFailure, bool>> deleteWatchlist({
    required String watchlistId,
  });

  /// List alert rules.
  Future<Either<AppFailure, List<AlertRule>>> listAlertRules({
    String? status,
  });

  /// Create an alert rule.
  Future<Either<AppFailure, AlertRule>> createAlertRule({
    required String symbol,
    required String alertType,
    required double threshold,
    double? thresholdPct,
    String frequency = 'always',
    List<String> notificationChannels = const ['in_app'],
    String? messageTemplate,
    DateTime? expiresAt,
  });

  /// Update an alert rule.
  Future<Either<AppFailure, AlertRule>> updateAlertRule({
    required String ruleId,
    double? threshold,
    double? thresholdPct,
    String? status,
    String? frequency,
    List<String>? notificationChannels,
    String? messageTemplate,
    DateTime? expiresAt,
  });

  /// Delete an alert rule.
  Future<Either<AppFailure, bool>> deleteAlertRule({
    required String ruleId,
  });

  /// List alert events.
  Future<Either<AppFailure, List<AlertEvent>>> listAlertEvents({
    String? alertId,
    int limit = 50,
  });

  /// Acknowledge an alert event.
  Future<Either<AppFailure, bool>> acknowledgeAlertEvent({
    required String eventId,
  });

  /// Get alert summary.
  Future<Either<AppFailure, AlertSummaryResponse>> getAlertSummary();
}

/// API implementation of WatchlistRepository.
class WatchlistApiRepository implements WatchlistRepository {
  WatchlistApiRepository({
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
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  // ═══════════════════════════════════════════════════════════════
  // Watchlist Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, List<Watchlist>>> listWatchlists() async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist');
      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت لیست نمایش ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final watchlists = (json['watchlists'] as List?)
              ?.map((e) => Watchlist.fromJson(e))
              .toList() ??
          [];
      return Right(watchlists);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت لیست نمایش به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت لیست نمایش.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, Watchlist>> createWatchlist({
    required String name,
    String? description,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist');
      final body = jsonEncode({
        'name': name,
        if (description != null) 'description': description,
      });

      final response = await client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'ایجاد لیست نمایش ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(Watchlist.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت ایجاد لیست نمایش به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در ایجاد لیست نمایش.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, Watchlist>> getWatchlist({
    required String watchlistId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/$watchlistId');
      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        return const Left(AppFailure(
          message: 'لیست نمایش یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت لیست نمایش ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(Watchlist.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت لیست نمایش به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت لیست نمایش.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, Watchlist>> updateWatchlist({
    required String watchlistId,
    String? name,
    String? description,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/$watchlistId');
      final body = jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      });

      final response = await client
          .put(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'به‌روزرسانی لیست نمایش ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(Watchlist.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت به‌روزرسانی لیست نمایش به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در به‌روزرسانی لیست نمایش.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, Watchlist>> updateWatchlistSymbols({
    required String watchlistId,
    List<String> addSymbols = const [],
    List<String> removeSymbols = const [],
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/$watchlistId/symbols');
      final body = jsonEncode({
        'add_symbols': addSymbols,
        'remove_symbols': removeSymbols,
      });

      final response = await client
          .patch(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'به‌روزرسانی نمادهای دیده‌بان ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(Watchlist.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت به‌روزرسانی نمادهای دیده‌بان به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در به‌روزرسانی نمادهای دیده‌بان.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, bool>> deleteWatchlist({
    required String watchlistId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/$watchlistId');
      final response = await client
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'حذف لیست نمایش ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      return const Right(true);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت حذف لیست نمایش به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در حذف لیست نمایش.',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Alert Rule Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, List<AlertRule>>> listAlertRules({
    String? status,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/alerts').replace(
        queryParameters: {
          if (status != null) 'status': status,
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت قوانین هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final alerts = (json['alerts'] as List?)
              ?.map((e) => AlertRule.fromJson(e))
              .toList() ??
          [];
      return Right(alerts);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت قوانین هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت قوانین هشدار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, AlertRule>> createAlertRule({
    required String symbol,
    required String alertType,
    required double threshold,
    double? thresholdPct,
    String frequency = 'always',
    List<String> notificationChannels = const ['in_app'],
    String? messageTemplate,
    DateTime? expiresAt,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/alerts');
      final body = jsonEncode({
        'symbol': symbol,
        'alert_type': alertType,
        'threshold': threshold,
        if (thresholdPct != null) 'threshold_pct': thresholdPct,
        'frequency': frequency,
        'notification_channels': notificationChannels,
        if (messageTemplate != null) 'message_template': messageTemplate,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      });

      final response = await client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'ایجاد قانون هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(AlertRule.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت ایجاد قانون هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در ایجاد قانون هشدار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, AlertRule>> updateAlertRule({
    required String ruleId,
    double? threshold,
    double? thresholdPct,
    String? status,
    String? frequency,
    List<String>? notificationChannels,
    String? messageTemplate,
    DateTime? expiresAt,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/alerts/$ruleId');
      final body = jsonEncode({
        if (threshold != null) 'threshold': threshold,
        if (thresholdPct != null) 'threshold_pct': thresholdPct,
        if (status != null) 'status': status,
        if (frequency != null) 'frequency': frequency,
        if (notificationChannels != null)
          'notification_channels': notificationChannels,
        if (messageTemplate != null) 'message_template': messageTemplate,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      });

      final response = await client
          .put(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'به‌روزرسانی قانون هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(AlertRule.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت به‌روزرسانی قانون هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در به‌روزرسانی قانون هشدار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, bool>> deleteAlertRule({
    required String ruleId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/alerts/$ruleId');
      final response = await client
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'حذف قانون هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      return const Right(true);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت حذف قانون هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در حذف قانون هشدار.',
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Alert Event Endpoints
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<Either<AppFailure, List<AlertEvent>>> listAlertEvents({
    String? alertId,
    int limit = 50,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/events').replace(
        queryParameters: {
          if (alertId != null) 'alert_id': alertId,
          'limit': limit.toString(),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت رویدادهای هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final events = (json['events'] as List?)
              ?.map((e) => AlertEvent.fromJson(e))
              .toList() ??
          [];
      return Right(events);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت رویدادهای هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت رویدادهای هشدار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, bool>> acknowledgeAlertEvent({
    required String eventId,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/events/$eventId/acknowledge');
      final response = await client
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'تأیید رویداد هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      return const Right(true);
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت تأیید رویداد هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در تأیید رویداد هشدار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, AlertSummaryResponse>> getAlertSummary() async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/watchlist/summary');
      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت خلاصه هشدار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(AlertSummaryResponse.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت خلاصه هشدار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت خلاصه هشدار.',
      ));
    }
  }
}

/// Riverpod provider for watchlist repository.
@Riverpod(keepAlive: true)
WatchlistRepository watchlistRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return WatchlistApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () =>
        ref.read(authControllerProvider).value?.accessToken,
  );
}
