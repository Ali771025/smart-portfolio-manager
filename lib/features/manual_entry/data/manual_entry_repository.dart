import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_base_url.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/manual_entry_state.dart';
import '../domain/problem_details.dart';

abstract class ManualEntryRepository {
  Future<void> submit({
    required ManualEntryPayload payload,
    required String idempotencyKey,
  });
}

class DioManualEntryRepository implements ManualEntryRepository {
  DioManualEntryRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<void> submit({
    required ManualEntryPayload payload,
    required String idempotencyKey,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const ProblemDetailsException(
        status: 401,
        title: 'Unauthorized',
        detail: 'Your session has expired. Please sign in again.',
      );
    }

    try {
      await dio.post<Object?>(
        '/manual-transactions',
        data: payload.toApiJson(),
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ProblemDetailsException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final payload = _decodeMap(error.response?.data);
    final fallback = error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'Unexpected error while submitting the transaction.';

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ProblemDetailsException(
        status: 503,
        title: 'Network error',
        detail: 'Connection timeout. Please check internet and retry.',
      );
    }

    return ProblemDetailsException(
      status: statusCode,
      title: payload?['title']?.toString() ?? 'Request failed',
      detail: payload?['detail']?.toString() ?? fallback,
      type: payload?['type']?.toString(),
      instance: payload?['instance']?.toString(),
      fieldErrors: _extractFieldErrors(payload),
    );
  }

  Map<String, dynamic>? _decodeMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
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

  List<ProblemFieldError> _extractFieldErrors(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const <ProblemFieldError>[];
    }

    final rawErrors = payload['errors'];
    if (rawErrors is! List) {
      return const <ProblemFieldError>[];
    }

    return rawErrors
        .whereType<Map>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final field = map['field']?.toString() ?? _readLocationPath(map['loc']);
          final message = map['message']?.toString() ?? map['msg']?.toString();
          if (field.isEmpty || message == null || message.isEmpty) {
            return null;
          }
          return ProblemFieldError(field: field, message: message);
        })
        .whereType<ProblemFieldError>()
        .toList(growable: false);
  }

  String _readLocationPath(Object? location) {
    if (location is! List) {
      return '';
    }
    return location
        .whereType<Object>()
        .map((token) => token.toString())
        .where((token) => token != 'body' && token != 'payload')
        .join('.');
  }
}

final manualEntryDioProvider = Provider<Dio>((ref) {
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

final manualEntryRepositoryProvider = Provider<ManualEntryRepository>((ref) {
  return DioManualEntryRepository(
    dio: ref.watch(manualEntryDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
