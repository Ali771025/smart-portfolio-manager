import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@freezed
abstract class AuthSession with _$AuthSession {
  const AuthSession._();

  const factory AuthSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAtUtc,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  static DateTime? tryReadExpiryUtcFromJwt(String token) {
    final segments = token.split('.');
    if (segments.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(segments[1]);
      final payloadMap = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      ) as Map<String, dynamic>;
      final exp = payloadMap['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
