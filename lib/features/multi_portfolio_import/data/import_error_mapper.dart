import 'dart:convert';

import 'package:dio/dio.dart';

String mapImportErrorToPersian(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'اتصال به سرور برقرار نشد. لطفاً اینترنت را بررسی کنید.';
  }

  final payload = _asPayload(error.response?.data);
  if (payload is List) {
    final mapped = _mapValidationList(payload);
    if (mapped != null) {
      return mapped;
    }
  }

  if (payload is Map<String, dynamic>) {
    final detail = payload['detail'];
    if (detail is List) {
      final mapped = _mapValidationList(detail);
      if (mapped != null) {
        return mapped;
      }
    }
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    final title = payload['title']?.toString();
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }
  }

  return error.message?.trim().isNotEmpty == true
      ? error.message!.trim()
      : 'خطای نامشخصی رخ داد. لطفاً دوباره تلاش کنید.';
}

String? _mapValidationList(List<dynamic> entries) {
  for (final entry in entries) {
    if (entry is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(entry);
    final type = (map['type'] ?? '').toString();
    final loc = (map['loc'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final field = loc.isNotEmpty ? loc.last : '';

    if (type == 'string_too_short' && field == 'name') {
      return 'نام پرتفوی نمی‌تواند خالی باشد.';
    }
    if (type == 'missing' && field == 'portfolio_id') {
      return 'لطفاً یک پرتفوی مقصد انتخاب کنید.';
    }
    if (field == 'name') {
      return 'برای ایجاد پرتفوی جدید، وارد کردن نام الزامی است.';
    }
  }
  return null;
}

Object? _asPayload(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is Map<String, dynamic> || raw is List) {
    return raw;
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  return null;
}
