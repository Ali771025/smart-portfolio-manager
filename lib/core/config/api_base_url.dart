import 'package:flutter/foundation.dart';

const _apiBaseUrlFromDefine = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String get defaultApiBaseUrl {
  final configuredUrl = _apiBaseUrlFromDefine.trim();
  if (configuredUrl.isNotEmpty) {
    return configuredUrl;
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Android emulators use 127.0.0.1 to access the host machine.
    return 'http://127.0.0.1:8000/api/v1';
  }

  return 'http://127.0.0.1:8000/api/v1';
}
