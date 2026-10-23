/// Repository for Market API calls.
///
/// Provides methods to fetch:
/// - Live market snapshots
/// - Symbol history
/// - Market status
/// - Index snapshots
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
import '../domain/models/market_models.dart';

part 'market_repository.g.dart';

/// Abstract repository interface for market data.
abstract class MarketRepository {
  Future<Either<AppFailure, MarketOverview>> getMarketOverview();

  Future<Either<AppFailure, MarketWatchResponse>> getMarketWatch({
    int page = 1,
    int pageSize = 100,
    bool compact = true,
  });

  Future<Either<AppFailure, List<IndexSnapshot>>> getMarketIndices();

  Future<Either<AppFailure, List<String>>> getSymbols();

  Future<Either<AppFailure, MarketQuote>> getSymbolQuote({
    required String symbol,
  });

  /// Get live market snapshot for a single instrument.
  Future<Either<AppFailure, LiveMarketSnapshot>> getLiveSnapshot({
    required String insCode,
  });

  /// Get live market snapshots for multiple instruments.
  Future<Either<AppFailure, LiveMarketBatch>> getLiveBatch({
    required List<String> insCodes,
  });

  /// Get historical price data for a symbol.
  Future<Either<AppFailure, SymbolHistory>> getSymbolHistory({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get market status and freshness metadata.
  Future<Either<AppFailure, MarketStatus>> getMarketStatus();

  /// Get market index snapshot.
  Future<Either<AppFailure, IndexSnapshot>> getIndexSnapshot({
    required String indexCode,
  });

  Future<Either<AppFailure, List<MarketDisclosure>>> getDisclosures({
    String? symbol,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
    bool? hasAttachment,
  });

  Future<Either<AppFailure, MarketDisclosure>> getDisclosure({
    required String trackingNumber,
  });
}

/// API implementation of MarketRepository.
class MarketApiRepository implements MarketRepository {
  MarketApiRepository({
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

  Either<AppFailure, String> _requireToken() {
    final token = _token;
    if (token == null || token.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }
    return Right(token);
  }

  Future<Either<AppFailure, T>> _getJson<T>(
    Uri uri,
    T Function(Object? decoded) decode, {
    String failureMessage = 'دریافت داده بازار ناموفق بود.',
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final tokenResult = _requireToken();
    final tokenFailure =
        tokenResult.fold<AppFailure?>((failure) => failure, (_) => null);
    if (tokenFailure != null) return Left(tokenFailure);

    try {
      final response =
          await client.get(uri, headers: _headers).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: failureMessage,
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      return Right(decode(jsonDecode(response.body)));
    } on TimeoutException {
      return Left(AppFailure(
        message: 'مهلت $failureMessage به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return Left(AppFailure(message: 'پاسخ $failureMessage معتبر نیست.'));
    }
  }

  @override
  Future<Either<AppFailure, MarketOverview>> getMarketOverview() {
    return _getJson(
      Uri.parse('$baseUrl/market/overview'),
      (decoded) => MarketOverview.fromJson(decoded as Map<String, dynamic>),
      failureMessage: 'دریافت نمای کلی بازار ناموفق بود.',
    );
  }

  @override
  Future<Either<AppFailure, MarketWatchResponse>> getMarketWatch({
    int page = 1,
    int pageSize = 100,
    bool compact = true,
  }) {
    final uri = Uri.parse('$baseUrl/market/watch').replace(
      queryParameters: {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'compact': compact.toString(),
      },
    );
    return _getJson(
      uri,
      (decoded) =>
          MarketWatchResponse.fromJson(decoded as Map<String, dynamic>),
      failureMessage: 'دریافت دیده‌بان بازار ناموفق بود.',
      timeout: const Duration(seconds: 15),
    );
  }

  @override
  Future<Either<AppFailure, List<IndexSnapshot>>> getMarketIndices() {
    return _getJson(
      Uri.parse('$baseUrl/market/indices'),
      (decoded) {
        if (decoded is Map<String, dynamic>) {
          final raw = decoded['indices'] ?? decoded['items'] ?? decoded['data'];
          if (raw is List) {
            return raw
                .whereType<Map>()
                .map((item) =>
                    IndexSnapshot.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false);
          }
        }
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) =>
                  IndexSnapshot.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false);
        }
        throw const FormatException('Invalid indices response');
      },
      failureMessage: 'دریافت شاخص‌ها ناموفق بود.',
    );
  }

  @override
  Future<Either<AppFailure, List<String>>> getSymbols() {
    return _getJson(
      Uri.parse('$baseUrl/symbols'),
      (decoded) {
        final raw =
            decoded is Map ? decoded['items'] ?? decoded['symbols'] : decoded;
        if (raw is! List) {
          throw const FormatException('Invalid symbols response');
        }
        return raw
            .map((item) {
              if (item is String) return item;
              if (item is Map) return item['symbol']?.toString() ?? '';
              return '';
            })
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);
      },
      failureMessage: 'دریافت نمادها ناموفق بود.',
    );
  }

  @override
  Future<Either<AppFailure, MarketQuote>> getSymbolQuote({
    required String symbol,
  }) {
    return _getJson(
      Uri.parse('$baseUrl/symbols/${Uri.encodeComponent(symbol)}/quote'),
      (decoded) => MarketQuote.fromJson(decoded as Map<String, dynamic>),
      failureMessage: 'دریافت قیمت نماد ناموفق بود.',
    );
  }

  @override
  Future<Either<AppFailure, LiveMarketSnapshot>> getLiveSnapshot({
    required String insCode,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri =
          Uri.parse('$baseUrl/symbols/${Uri.encodeComponent(insCode)}/quote');

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        return Left(AppFailure(
          message: 'داده‌ای برای نماد $insCode یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت داده بازار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(LiveMarketSnapshot.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت داده بازار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت داده بازار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, LiveMarketBatch>> getLiveBatch({
    required List<String> insCodes,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    if (insCodes.isEmpty) {
      return const Left(AppFailure(
        message: 'لیست نمادها خالی است.',
        statusCode: 400,
      ));
    }

    if (insCodes.length > 50) {
      return const Left(AppFailure(
        message: 'حداکثر 50 نماد در هر درخواست مجاز است.',
        statusCode: 400,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/market/watch').replace(
        queryParameters: {
          'page': '1',
          'page_size': insCodes.length.toString(),
          'compact': 'true',
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت داده بازار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final watch = MarketWatchResponse.fromJson(json);
      return Right(LiveMarketBatch(
        snapshots: watch.items.map((item) {
          return LiveMarketSnapshot.fromJson({
            'symbol': item.symbol,
            'instrument_id': item.instrumentId,
            'last_price': item.lastPrice,
            'closing_price': item.closingPrice,
            'volume': item.volume,
            'event_time': item.eventTime?.toIso8601String(),
            'received_at': item.receivedAt?.toIso8601String(),
            'is_stale': item.isStale,
          });
        }).toList(growable: false),
        count: watch.count,
        fetchedAt: watch.serverTime ?? DateTime.now().toUtc(),
      ));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت داده بازار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت داده بازار.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, SymbolHistory>> getSymbolHistory({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri =
          Uri.parse('$baseUrl/symbols/${Uri.encodeComponent(symbol)}/history')
              .replace(
        queryParameters: {
          'from_date': _formatDate(startDate),
          'to_date': _formatDate(endDate),
        },
      );

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return Left(AppFailure(
          message: 'نماد $symbol یافت نشد.',
          statusCode: 404,
        ));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت تاریخچه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(SymbolHistory.fromJson(json));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت تاریخچه به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت تاریخچه.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, MarketStatus>> getMarketStatus() async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final uri = Uri.parse('$baseUrl/market/status');

      final response = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت وضعیت بازار ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return Right(_fallbackMarketStatus());
      }
      return Right(MarketStatus.fromJson(decoded));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت وضعیت بازار به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return Right(_fallbackMarketStatus());
    }
  }

  @override
  Future<Either<AppFailure, IndexSnapshot>> getIndexSnapshot({
    required String indexCode,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }

    try {
      final indicesResult = await getMarketIndices();
      return indicesResult.fold(
        (failure) => Left(failure),
        (indices) {
          final match = indices.where((item) => item.indexCode == indexCode);
          if (match.isEmpty) {
            return Left(AppFailure(
              message: 'داده‌ای برای شاخص $indexCode یافت نشد.',
              statusCode: 404,
            ));
          }
          return Right(match.first);
        },
      );
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت داده شاخص به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت داده شاخص.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, List<MarketDisclosure>>> getDisclosures({
    String? symbol,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
    bool? hasAttachment,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }
    try {
      final query = <String, String>{
        if (symbol?.trim().isNotEmpty == true) 'symbol': symbol!.trim(),
        if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
        if (fromDate != null) 'from_date': _formatDate(fromDate),
        if (toDate != null) 'to_date': _formatDate(toDate),
        if (hasAttachment != null) 'has_attachment': hasAttachment.toString(),
      };
      final response = await client
          .get(
            Uri.parse('$baseUrl/disclosures').replace(queryParameters: query),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت اطلاعیه‌های کدال ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      final decoded = jsonDecode(response.body);
      final rawItems = decoded is Map<String, dynamic>
          ? decoded['items'] ?? decoded['data'] ?? decoded['disclosures']
          : decoded;
      if (rawItems is! List) {
        return const Left(AppFailure(message: 'پاسخ اطلاعیه‌ها معتبر نیست.'));
      }
      return Right(rawItems
          .whereType<Map<String, dynamic>>()
          .map(MarketDisclosure.fromJson)
          .toList(growable: false));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت اطلاعیه‌های کدال به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت اطلاعیه‌های کدال.',
      ));
    }
  }

  @override
  Future<Either<AppFailure, MarketDisclosure>> getDisclosure({
    required String trackingNumber,
  }) async {
    if (_token == null || _token!.isEmpty) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }
    try {
      final encoded = Uri.encodeComponent(trackingNumber);
      final response = await client
          .get(Uri.parse('$baseUrl/disclosures/$encoded'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        return const Left(AppFailure(
          message: 'اطلاعیه موردنظر یافت نشد.',
          statusCode: 404,
        ));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت جزئیات اطلاعیه ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const Left(
            AppFailure(message: 'پاسخ جزئیات اطلاعیه معتبر نیست.'));
      }
      return Right(MarketDisclosure.fromJson(decoded));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت جزئیات اطلاعیه به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(
        message: 'خطای پیش‌بینی‌نشده در دریافت جزئیات اطلاعیه.',
      ));
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  MarketStatus _fallbackMarketStatus() {
    return MarketStatus(
      providerStatus: 'unknown',
      syncedAssets: 0,
      failedAssets: 0,
      isMarketOpen: false,
      isTradingDay: true,
      dataFreshnessSeconds: null,
      isStale: true,
      checkedAt: DateTime.now().toUtc(),
    );
  }
}

/// Riverpod provider for market repository.
@Riverpod(keepAlive: true)
MarketRepository marketRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  return MarketApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
}
