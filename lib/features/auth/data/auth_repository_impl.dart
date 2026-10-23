import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../domain/models/auth_failure.dart';
import '../domain/models/auth_session.dart';
import '../domain/repositories/auth_repository.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository({
    required this.client,
    required this.baseUrl,
  });

  final http.Client client;
  final String baseUrl;

  AuthSession? _cachedSession;

  @override
  Future<Either<AuthFailure, Unit>> registerInit({
    required String email,
    required String password,
    required String rePassword,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register-init');

    try {
      final response = await client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'email': email.trim().toLowerCase(),
              'password': password,
              're_password': rePassword,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          _mapFailure(
            response,
            fallback: 'ثبت‌نام ناموفق بود. لطفا اطلاعات را بررسی کرده و دوباره تلاش کنید.',
          ),
        );
      }

      return const Right(unit);
    } on TimeoutException {
      return const Left(
        AuthFailure(message: 'زمان درخواست به پایان رسید. لطفا دوباره تلاش کنید.'),
      );
    } on http.ClientException catch (_) {
      return Left(
        AuthFailure(message: _connectionFailureMessage()),
      );
    } catch (_) {
      return const Left(
        AuthFailure(message: 'خطای پیش‌بینی‌نشده هنگام شروع ثبت‌نام رخ داد.'),
      );
    }
  }

  @override
  Future<Either<AuthFailure, AuthSession>> registerVerify({
    required String email,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register-verify');

    try {
      final response = await client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'email': email.trim().toLowerCase(),
              'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 12));

      return _mapAuthSessionResponse(
        response,
        fallbackMessage: 'تایید کد یکبارمصرف ناموفق بود. لطفا دوباره تلاش کنید.',
      );
    } on TimeoutException {
      return const Left(
        AuthFailure(message: 'زمان درخواست به پایان رسید. لطفا دوباره تلاش کنید.'),
      );
    } on http.ClientException catch (_) {
      return Left(
        AuthFailure(message: _connectionFailureMessage()),
      );
    } catch (_) {
      return const Left(
        AuthFailure(message: 'خطای پیش‌بینی‌نشده هنگام تایید کد یکبارمصرف رخ داد.'),
      );
    }
  }

  @override
  Future<Either<AuthFailure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 422) {
        return _loginUsingOAuthForm(email: email, password: password);
      }

      return _mapAuthSessionResponse(
        response,
        fallbackMessage: 'ورود ناموفق بود. لطفا اطلاعات ورود را بررسی کنید.',
      );
    } on TimeoutException {
      return const Left(
        AuthFailure(message: 'زمان درخواست به پایان رسید. لطفا دوباره تلاش کنید.'),
      );
    } on http.ClientException catch (_) {
      return Left(
        AuthFailure(message: _connectionFailureMessage()),
      );
    } catch (_) {
      return const Left(
        AuthFailure(message: 'خطای پیش‌بینی‌نشده هنگام ورود رخ داد.'),
      );
    }
  }

  Future<Either<AuthFailure, AuthSession>> _loginUsingOAuthForm({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await client
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: <String, String>{
            'username': email.trim().toLowerCase(),
            'password': password,
          },
        )
        .timeout(const Duration(seconds: 12));

    return _mapAuthSessionResponse(
      response,
      fallbackMessage: 'ورود ناموفق بود. لطفا اطلاعات ورود را بررسی کنید.',
    );
  }

  Either<AuthFailure, AuthSession> _mapAuthSessionResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Left(_mapFailure(response, fallback: fallbackMessage));
    }

    final payload = _tryReadJsonMap(response.body);
    final accessToken = (payload['access_token'] ?? '').toString();
    final refreshToken = (payload['refresh_token'] ?? '').toString();
    final accessTtlSec = int.tryParse(
          (payload['access_expires_in_seconds'] ?? '').toString(),
        ) ??
        0;

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      return const Left(
        AuthFailure(message: 'پاسخ سرور ناقص است. لطفا دوباره تلاش کنید.'),
      );
    }

    final jwtExpiry = AuthSession.tryReadExpiryUtcFromJwt(accessToken);
    final fallbackExpiry = DateTime.now().toUtc().add(
          Duration(seconds: accessTtlSec > 0 ? accessTtlSec : 900),
        );

    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAtUtc: jwtExpiry ?? fallbackExpiry,
    );

    return Right(session);
  }

  AuthFailure _mapFailure(
    http.Response response, {
    required String fallback,
  }) {
    final status = response.statusCode;
    final payload = _tryReadJsonMap(response.body);

    final detail = payload['detail'];
    final message = _extractDetailMessage(detail) ?? fallback;

    return AuthFailure(
      message: message,
      statusCode: status,
      isValidationError: status == 400 || status == 409 || status == 422,
    );
  }

  Map<String, dynamic> _tryReadJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  String? _extractDetailMessage(Object? detail) {
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    if (detail is List) {
      final entries = detail
          .whereType<Map<String, dynamic>>()
          .map((item) => (item['msg'] ?? '').toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);

      if (entries.isNotEmpty) {
        return entries.join('\n');
      }
    }

    return null;
  }

  String _connectionFailureMessage() {
    return 'اتصال به سرور API برقرار نشد. از فعال بودن سرویس بک‌اند در $baseUrl مطمئن شوید.';
  }

  @override
  Future<void> clearSession() async {
    _cachedSession = null;
  }

  @override
  Future<void> persistSession(AuthSession session) async {
    _cachedSession = session;
  }

  @override
  Future<AuthSession?> readCachedSession() async {
    return _cachedSession;
  }
}
