import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/network/app_failure.dart';

const int _offloadThresholdBytes = 16 * 1024;

Object? _decodeJsonSync(String payload) => jsonDecode(payload);

Map<String, dynamic>? _asJsonObject(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, dynamic rawValue) => MapEntry(key.toString(), rawValue),
    );
  }
  return null;
}

Future<Object?> _decodeJsonInBackground(String payload) async {
  if (payload.length < _offloadThresholdBytes || kIsWeb) {
    return _decodeJsonSync(payload);
  }

  try {
    return await Isolate.run<Object?>(() => _decodeJsonSync(payload));
  } catch (_) {
    return compute(_decodeJsonSync, payload);
  }
}

Future<Either<AppFailure, Map<String, dynamic>>> parseJsonObjectPayload(
  String payload,
) async {
  try {
    final decoded = await _decodeJsonInBackground(payload);
    final object = _asJsonObject(decoded);
    if (object == null) {
      return const Left(
        AppFailure(message: 'ساختار پاسخ API معتبر نیست.'),
      );
    }
    return Right(object);
  } on FormatException {
    return const Left(
      AppFailure(message: 'ساختار JSON دریافتی نامعتبر است.'),
    );
  } catch (_) {
    return const Left(
      AppFailure(message: 'پردازش پاسخ تحلیلی ناموفق بود.'),
    );
  }
}

Future<Either<AppFailure, Map<String, dynamic>>> parseServerSentEventLine(
  String rawLine,
) async {
  final normalized = rawLine.trim();
  if (!normalized.startsWith('data:')) {
    return const Left(
      AppFailure(message: 'خط داده SSE معتبر نیست.'),
    );
  }

  final payload = normalized.substring(5).trim();
  if (payload.isEmpty || payload == '[DONE]') {
    return const Left(
      AppFailure(message: 'داده SSE خالی است.'),
    );
  }

  return parseJsonObjectPayload(payload);
}
