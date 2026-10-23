import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/problem_details_parser.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/asset_ledger_models.dart';

class AssetLedgerException implements Exception {
  const AssetLedgerException(this.problem);

  final ProblemDetailsPayload problem;

  @override
  String toString() => '${problem.title}: ${problem.detail}';
}

class AssetResolveResult {
  const AssetResolveResult({
    required this.assetId,
    required this.symbol,
    required this.created,
  });

  final String assetId;
  final String symbol;
  final bool created;
}

class AssetBreakEvenInfo {
  const AssetBreakEvenInfo({
    required this.computedBreakEvenPrice,
    required this.breakEvenPrice,
    this.manualBreakEvenPrice,
  });

  final Decimal? manualBreakEvenPrice;
  final Decimal computedBreakEvenPrice;
  final Decimal breakEvenPrice;

  bool get hasManualValue => manualBreakEvenPrice != null;

  factory AssetBreakEvenInfo.fromJson(Map<String, dynamic> json) {
    return AssetBreakEvenInfo(
      manualBreakEvenPrice: _optionalDecimal(json['manual_break_even_price']),
      computedBreakEvenPrice: _requiredDecimal(
        json['computed_break_even_price'] ?? json['weighted_avg_cost'],
      ),
      breakEvenPrice: _requiredDecimal(
        json['break_even_price'] ??
            json['manual_break_even_price'] ??
            json['weighted_avg_cost'],
      ),
    );
  }
}

abstract class AssetLedgerRepository {
  Future<AssetResolveResult> resolveAsset({required String symbol});

  Future<LedgerEntryDto> createTransaction({
    required String portfolioId,
    required TransactionCreateDto payload,
    required String idempotencyKey,
  });

  Future<AssetLedgerPageDto> fetchAssetLedger({
    required String portfolioId,
    required String assetId,
    required int limit,
    required int offset,
  });

  Future<AssetPositionDto> fetchAssetPosition({
    required String portfolioId,
    required String assetId,
  });

  Future<AssetBreakEvenInfo> fetchBreakEvenInfo({
    required String portfolioId,
    required String assetId,
  });

  Future<AssetBreakEvenInfo> updateBreakEvenPrice({
    required String portfolioId,
    required String assetId,
    required Decimal? manualBreakEvenPrice,
  });

  Future<AssetValuationSeriesDto> fetchAssetValuationSeries({
    required String portfolioId,
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
    required bool adjustedPrices,
  });

  Future<PortfolioPositionsDto> fetchPortfolioPositions({
    required String portfolioId,
    DateTime? asOfDate,
  });

  Future<PortfolioHoldingsDto> fetchHoldings({
    required String portfolioId,
  });

  Future<PortfolioFrontendSummaryDto> fetchFrontendSummary({
    required String portfolioId,
  });

  Future<PortfolioTwrDto> fetchPortfolioTwr({
    required String portfolioId,
    required DateTime startDate,
    required DateTime endDate,
  });
}

class DioAssetLedgerRepository implements AssetLedgerRepository {
  DioAssetLedgerRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<AssetResolveResult> resolveAsset({required String symbol}) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.post<Object?>(
        '/assets/resolve',
        data: <String, Object?>{
          'symbol': symbol.trim().toUpperCase(),
        },
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      final assetId = body['asset_id']?.toString() ?? '';
      final symbolRaw = (body['symbol'] ?? '').toString().trim().toUpperCase();
      final created = body['created'] == true;
      if (assetId.isEmpty) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Resolved asset id is missing.'),
        );
      }
      return AssetResolveResult(
        assetId: assetId,
        symbol: symbolRaw,
        created: created,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<LedgerEntryDto> createTransaction({
    required String portfolioId,
    required TransactionCreateDto payload,
    required String idempotencyKey,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.post<Object?>(
        '/portfolios/$portfolioId/transactions/',
        data: _encodeTransactionPayload(payload),
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return LedgerEntryDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<AssetLedgerPageDto> fetchAssetLedger({
    required String portfolioId,
    required String assetId,
    required int limit,
    required int offset,
  }) async {
    _requireUuid(portfolioId, fieldLabel: 'شناسه پرتفوی');
    _requireUuid(assetId, fieldLabel: 'شناسه دارایی');
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/assets/$assetId/ledger',
        queryParameters: <String, Object?>{
          'limit': limit,
          'offset': offset,
        },
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return AssetLedgerPageDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<AssetPositionDto> fetchAssetPosition({
    required String portfolioId,
    required String assetId,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/assets/$assetId/position',
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return AssetPositionDto.fromJson(_normalizePositionPayload(body));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<AssetBreakEvenInfo> fetchBreakEvenInfo({
    required String portfolioId,
    required String assetId,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/assets/$assetId/position',
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return AssetBreakEvenInfo.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<AssetBreakEvenInfo> updateBreakEvenPrice({
    required String portfolioId,
    required String assetId,
    required Decimal? manualBreakEvenPrice,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.put<Object?>(
        '/portfolios/$portfolioId/assets/$assetId/break-even-price',
        data: <String, Object?>{
          'manual_break_even_price': manualBreakEvenPrice?.toString(),
        },
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return AssetBreakEvenInfo.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<AssetValuationSeriesDto> fetchAssetValuationSeries({
    required String portfolioId,
    required String assetId,
    required DateTime startDate,
    required DateTime endDate,
    required bool adjustedPrices,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/assets/$assetId/valuation-series',
        queryParameters: <String, Object?>{
          'start_date': _toIsoDate(startDate),
          'end_date': _toIsoDate(endDate),
          'adjusted_prices': adjustedPrices,
        },
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return AssetValuationSeriesDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<PortfolioPositionsDto> fetchPortfolioPositions({
    required String portfolioId,
    DateTime? asOfDate,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/positions',
        queryParameters: <String, Object?>{
          if (asOfDate != null) 'as_of_date': _toIsoDate(asOfDate),
        },
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return PortfolioPositionsDto.fromJson(_normalizePositionsPayload(body));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<PortfolioHoldingsDto> fetchHoldings({
    required String portfolioId,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/holdings',
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
            title: 'Invalid response',
            detail: 'Server response is not valid JSON.',
          ),
        );
      }
      return PortfolioHoldingsDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<PortfolioFrontendSummaryDto> fetchFrontendSummary({
    required String portfolioId,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/summary/frontend',
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
            title: 'Invalid response',
            detail: 'Server response is not valid JSON.',
          ),
        );
      }
      return PortfolioFrontendSummaryDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  @override
  Future<PortfolioTwrDto> fetchPortfolioTwr({
    required String portfolioId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/portfolios/$portfolioId/twr',
        queryParameters: <String, Object?>{
          'start_date': _toIsoDate(startDate),
          'end_date': _toIsoDate(endDate),
        },
        options: Options(headers: _authHeaders(token)),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const AssetLedgerException(
          ProblemDetailsPayload(
              title: 'Invalid response',
              detail: 'Server response is not valid JSON.'),
        );
      }
      return PortfolioTwrDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  String _tokenOrThrow() {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const AssetLedgerException(
        ProblemDetailsPayload(
          title: 'Unauthorized',
          detail: 'Your session has expired. Please sign in again.',
          status: 401,
        ),
      );
    }
    return token;
  }

  void _requireUuid(String value, {required String fieldLabel}) {
    final isValid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
    if (!isValid) {
      throw AssetLedgerException(
        ProblemDetailsPayload(
          title: 'شناسه نامعتبر',
          detail: '$fieldLabel معتبر نیست.',
          status: 422,
        ),
      );
    }
  }

  Map<String, String> _authHeaders(String token) {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  AssetLedgerException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const AssetLedgerException(
        ProblemDetailsPayload(
          title: 'Network error',
          detail: 'Connection timeout. Please retry.',
          status: 503,
        ),
      );
    }

    final payload = parseProblemDetails(error.response?.data);
    return AssetLedgerException(payload);
  }

  Map<String, dynamic>? _decodeMap(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizePositionPayload(Map<String, dynamic> source) {
    final normalized = Map<String, dynamic>.from(source);
    _normalizePriceFields(normalized);
    return normalized;
  }

  Map<String, dynamic> _normalizePositionsPayload(Map<String, dynamic> source) {
    final normalized = Map<String, dynamic>.from(source);
    final rawItems = normalized['items'] ??
        normalized['positions'] ??
        normalized['holdings'];
    if (rawItems is List) {
      normalized['items'] = rawItems
          .whereType<Map>()
          .map((item) =>
              _normalizePositionPayload(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }
    normalized['daily_pnl'] ??= normalized['total_daily_pnl'] ?? 0;
    normalized['last_market_update'] ??= normalized['last_updated_at'];
    return normalized;
  }

  void _normalizePriceFields(Map<String, dynamic> json) {
    final lastPrice = json['last_price'] ??
        json['current_price'] ??
        json['latest_price'] ??
        json['current_live_price'];
    final closingPrice = json['closing_price'] ?? json['close_price'];
    if (lastPrice != null) {
      json['last_price'] ??= lastPrice;
      json['latest_price'] ??= lastPrice;
    }
    if (closingPrice != null) {
      json['closing_price'] ??= closingPrice;
    }
    json['last_market_update'] ??=
        json['last_updated_at'] ?? json['price_timestamp'];
    json['market_value'] ??= json['current_value'];
  }

  Map<String, Object?> _encodeTransactionPayload(TransactionCreateDto payload) {
    final json = payload.toJson();
    json['executed_at'] = payload.executedAt.toUtc().toIso8601String();
    return json;
  }
}

String _toIsoDate(DateTime value) =>
    value.toUtc().toIso8601String().split('T').first;

Decimal _requiredDecimal(Object? value) {
  return _optionalDecimal(value) ?? Decimal.zero;
}

Decimal? _optionalDecimal(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Decimal) {
    return value;
  }
  if (value is num) {
    return Decimal.parse(value.toString());
  }
  final source = value.toString().trim();
  if (source.isEmpty) {
    return null;
  }
  try {
    return Decimal.parse(source);
  } catch (_) {
    return null;
  }
}

final assetLedgerDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final assetLedgerRepositoryProvider = Provider<AssetLedgerRepository>((ref) {
  return DioAssetLedgerRepository(
    dio: ref.watch(assetLedgerDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
