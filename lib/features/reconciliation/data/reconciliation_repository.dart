import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_base_url.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/reconciliation_models.dart';

class ReconciliationApiException implements Exception {
  const ReconciliationApiException({
    required this.message,
    this.code,
    this.status,
  });

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

abstract class ReconciliationRepository {
  Future<List<ReconciliationBuyCandidate>> fetchBuyCandidates({
    required ReconciliationSellSelection sell,
    required List<ReconciliationPortfolioRef> portfolios,
  });

  Future<String?> findActiveSuggestionForSell({
    required String assetId,
    required String sellTransactionId,
  });

  Future<String> createManual({
    required String sellTransactionId,
    required Map<String, Decimal> allocations,
    String? notes,
  });

  Future<ReconciliationPreview> preview(String reconciliationId);

  Future<void> confirm(String reconciliationId, {String? notes});

  Future<void> reject(String reconciliationId, {String? notes});
}

class DioReconciliationRepository implements ReconciliationRepository {
  DioReconciliationRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<List<ReconciliationBuyCandidate>> fetchBuyCandidates({
    required ReconciliationSellSelection sell,
    required List<ReconciliationPortfolioRef> portfolios,
  }) async {
    final confirmedUsage = await _confirmedBuyUsage(assetId: sell.assetId);
    final candidates = <ReconciliationBuyCandidate>[];
    for (final portfolio in portfolios) {
      if (portfolio.id == sell.portfolioId || !_isUuid(portfolio.id)) {
        continue;
      }
      try {
        final response = await dio.get<Object?>(
          '/portfolios/${portfolio.id}/assets/${sell.assetId}/ledger',
          queryParameters: const <String, Object?>{'limit': 500, 'offset': 0},
          options: Options(headers: _headers()),
        );
        final body = _map(response.data);
        final rawItems = body?['items'];
        if (rawItems is! List) {
          continue;
        }
        for (final raw in rawItems.whereType<Map>()) {
          final item = Map<String, dynamic>.from(raw);
          if (item['transaction_type']?.toString().toUpperCase() != 'BUY') {
            continue;
          }
          final executedAt = DateTime.tryParse(
            item['executed_at']?.toString() ?? '',
          );
          if (executedAt == null || executedAt.isAfter(sell.executedAt)) {
            continue;
          }
          final transactionId = item['id']?.toString() ?? '';
          final quantity = reconciliationDecimal(item['quantity']);
          final used = confirmedUsage[transactionId] ?? Decimal.zero;
          final available = quantity - used;
          if (transactionId.isEmpty || available <= Decimal.zero) {
            continue;
          }
          candidates.add(
            ReconciliationBuyCandidate(
              transactionId: transactionId,
              portfolioId: portfolio.id,
              portfolioLabel: portfolio.label,
              executedAt: executedAt,
              quantity: quantity,
              availableQuantity: available,
              pricePerUnit: reconciliationDecimal(item['price_per_unit']),
            ),
          );
        }
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) {
          continue;
        }
        throw _exception(error);
      }
    }
    candidates.sort(
      (left, right) => left
          .dateDistanceDays(sell.executedAt)
          .compareTo(right.dateDistanceDays(sell.executedAt)),
    );
    return candidates;
  }

  @override
  Future<String?> findActiveSuggestionForSell({
    required String assetId,
    required String sellTransactionId,
  }) async {
    try {
      final response = await dio.get<Object?>(
        '/trade-reconciliations/suggestions',
        queryParameters: <String, Object?>{'asset_id': assetId},
        options: Options(headers: _headers()),
      );
      final body = _list(response.data);
      for (final raw in body.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final sellRaw = item['sell_transaction'];
        final sell = sellRaw is Map
            ? Map<String, dynamic>.from(sellRaw)
            : const <String, dynamic>{};
        if (sell['transaction_id']?.toString() == sellTransactionId) {
          return item['reconciliation_id']?.toString();
        }
      }
      return null;
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String> createManual({
    required String sellTransactionId,
    required Map<String, Decimal> allocations,
    String? notes,
  }) async {
    try {
      final response = await dio.post<Object?>(
        '/trade-reconciliations/manual',
        data: <String, Object?>{
          'sell_transaction_id': sellTransactionId,
          'allocations': allocations.entries
              .map(
                (entry) => <String, Object?>{
                  'buy_transaction_id': entry.key,
                  'quantity': entry.value.toString(),
                },
              )
              .toList(growable: false),
          if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        },
        options: Options(headers: _headers(contentType: true)),
      );
      final body = _map(response.data);
      final id = body?['reconciliation_id']?.toString() ?? '';
      if (id.isEmpty) {
        throw const ReconciliationApiException(
          message: 'شناسه تطبیق در پاسخ سرور موجود نیست.',
        );
      }
      return id;
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<ReconciliationPreview> preview(String reconciliationId) async {
    try {
      final response = await dio.get<Object?>(
        '/trade-reconciliations/$reconciliationId/preview',
        options: Options(headers: _headers()),
      );
      final body = _map(response.data);
      if (body == null) {
        throw const ReconciliationApiException(
          message: 'پاسخ پیش‌نمایش معتبر نیست.',
        );
      }
      return ReconciliationPreview.fromJson(body);
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> confirm(String reconciliationId, {String? notes}) async {
    await _transition(reconciliationId, 'confirm', notes);
  }

  @override
  Future<void> reject(String reconciliationId, {String? notes}) async {
    await _transition(reconciliationId, 'reject', notes);
  }

  Future<void> _transition(
    String reconciliationId,
    String action,
    String? notes,
  ) async {
    try {
      await dio.post<Object?>(
        '/trade-reconciliations/$reconciliationId/$action',
        data: <String, Object?>{
          if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
        },
        options: Options(headers: _headers(contentType: true)),
      );
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  Future<Map<String, Decimal>> _confirmedBuyUsage({
    required String assetId,
  }) async {
    try {
      final response = await dio.get<Object?>(
        '/trade-reconciliations',
        queryParameters: const <String, Object?>{'status': 'CONFIRMED'},
        options: Options(headers: _headers()),
      );
      final usage = <String, Decimal>{};
      for (final raw in _list(response.data).whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        if (item['asset_id']?.toString() != assetId) {
          continue;
        }
        final rawAllocations = item['source_allocations'];
        if (rawAllocations is! List) {
          continue;
        }
        for (final allocationRaw in rawAllocations.whereType<Map>()) {
          final allocation = Map<String, dynamic>.from(allocationRaw);
          final buyRaw = allocation['buy_transaction'];
          final buy = buyRaw is Map
              ? Map<String, dynamic>.from(buyRaw)
              : const <String, dynamic>{};
          final id = buy['transaction_id']?.toString() ?? '';
          if (id.isEmpty) {
            continue;
          }
          usage[id] = (usage[id] ?? Decimal.zero) +
              reconciliationDecimal(allocation['matched_quantity']);
        }
      }
      return usage;
    } on DioException catch (error) {
      throw _exception(error);
    }
  }

  Map<String, String> _headers({bool contentType = false}) {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const ReconciliationApiException(
        message: 'نشست کاربری منقضی شده است. دوباره وارد شوید.',
        code: 'unauthorized',
        status: 401,
      );
    }
    return <String, String>{
      'Accept': 'application/json',
      if (contentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  ReconciliationApiException _exception(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ReconciliationApiException(
        message: 'ارتباط با سرور برقرار نشد. دوباره تلاش کنید.',
        code: 'network-error',
        status: 503,
      );
    }
    final body = _map(error.response?.data);
    return ReconciliationApiException(
      message: _localizedMessage(
        body?['code']?.toString(),
        body?['detail']?.toString(),
      ),
      code: body?['code']?.toString(),
      status: error.response?.statusCode,
    );
  }

  String _localizedMessage(String? code, String? detail) {
    switch (code) {
      case 'asset-mismatch':
        return 'خرید و فروش باید مربوط به یک نماد یکسان باشند.';
      case 'buy-allocation-overflow':
        return 'مقدار واردشده از مانده قابل استفاده خرید بیشتر است.';
      case 'source-inventory-overflow':
        return 'در پرتفوی مبدا، موجودی کافی در تاریخ فروش وجود ندارد.';
      case 'sell-allocation-overflow':
        return 'مجموع تخصیص از مقدار فروش تطبیق‌نشده بیشتر است.';
      case 'invalid-quantity':
        return 'مقدار تخصیص باید بزرگ‌تر از صفر باشد.';
      case 'active-case-exists':
        return 'برای این فروش یک پیشنهاد فعال وجود دارد.';
      case 'invalid-status-transition':
        return 'وضعیت فعلی اجازه این عملیات را نمی‌دهد.';
      case 'user-mismatch':
        return 'تراکنش انتخابی متعلق به کاربر دیگری است.';
      case 'buy-after-sell':
        return 'تاریخ خرید نمی‌تواند بعد از تاریخ فروش باشد.';
      default:
        return detail?.trim().isNotEmpty == true
            ? detail!.trim()
            : 'عملیات تطبیق انجام نشد.';
    }
  }

  Map<String, dynamic>? _map(Object? payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<dynamic> _list(Object? payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        return const <dynamic>[];
      }
    }
    return const <dynamic>[];
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }
}

final reconciliationDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final reconciliationRepositoryProvider =
    Provider<ReconciliationRepository>((ref) {
  return DioReconciliationRepository(
    dio: ref.watch(reconciliationDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
