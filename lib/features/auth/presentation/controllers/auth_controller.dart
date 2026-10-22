import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/api_base_url.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/models/auth_failure.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AuthApiRepository(client: client, baseUrl: defaultApiBaseUrl);
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Timer? _otpTimer;

  @override
  Future<AuthSession?> build() async {
    ref.onDispose(_stopOtpTimer);

    final session = await _repository.readCachedSession();
    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      await _repository.clearSession();
      return null;
    }

    return session;
  }

  Future<Either<AuthFailure, Unit>> registerInit({
    required String email,
    required String password,
    required String rePassword,
  }) async {
    if (state.isLoading) {
      return const Left(
        AuthFailure(message: 'درخواست دیگری در حال پردازش است.'),
      );
    }

    final previousSession = state.value;
    state = const AsyncValue.loading();

    final result = await _repository.registerInit(
      email: email,
      password: password,
      rePassword: rePassword,
    );

    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse((_) => const AuthFailure(message: 'خطای نامشخص در احراز هویت.'));
      state = AsyncValue.error(failure, StackTrace.current);
      return result;
    }

    final normalizedEmail = email.trim().toLowerCase();
    ref.read(pendingRegistrationProvider.notifier).state = PendingRegistration(
          email: normalizedEmail,
          password: password,
          rePassword: rePassword,
        );
    _startOtpCountdown();
    state = AsyncValue.data(previousSession);

    return result;
  }

  Future<Either<AuthFailure, AuthSession>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    if (state.isLoading) {
      return const Left(
        AuthFailure(message: 'درخواست دیگری در حال پردازش است.'),
      );
    }

    state = const AsyncValue.loading();

    final result = await _repository.registerVerify(
      email: email,
      otp: otp,
    );

    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse((_) => const AuthFailure(message: 'خطای نامشخص در احراز هویت.'));
      state = AsyncValue.error(failure, StackTrace.current);
      return result;
    }

    final session = result.getOrElse(
      (_) => throw StateError('عملیات تایید ثبت‌نام بدون نشست معتبر بازگشت داده شد.'),
    );
    await _repository.persistSession(session);
    _clearPendingRegistration();
    state = AsyncValue.data(session);

    return result;
  }

  Future<Either<AuthFailure, Unit>> resendOtp() async {
    final pending = ref.read(pendingRegistrationProvider);
    final remainingSeconds = ref.read(otpResendSecondsProvider);

    if (pending == null) {
      return const Left(
        AuthFailure(message: 'اطلاعات ثبت‌نام یافت نشد. لطفا دوباره ثبت‌نام کنید.'),
      );
    }

    if (remainingSeconds > 0) {
      return Left(
        AuthFailure(
          message: 'برای ارسال مجدد کد تایید کمی صبر کنید. $remainingSeconds ثانیه باقی مانده است.',
          isValidationError: true,
        ),
      );
    }

    return registerInit(
      email: pending.email,
      password: pending.password,
      rePassword: pending.rePassword,
    );
  }

  Future<Either<AuthFailure, Unit>> login({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) {
      return const Left(
        AuthFailure(message: 'درخواست دیگری در حال پردازش است.'),
      );
    }

    state = const AsyncValue.loading();
    final result = await _repository.login(email: email, password: password);

    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse((_) => const AuthFailure(message: 'خطای نامشخص در احراز هویت.'));
      state = AsyncValue.error(failure, StackTrace.current);
      return result.map((_) => unit);
    }

    final session = result.getOrElse(
      (_) => throw StateError('عملیات ورود بدون نشست معتبر بازگشت داده شد.'),
    );
    await _repository.persistSession(session);
    _clearPendingRegistration();
    state = AsyncValue.data(session);

    return result.map((_) => unit);
  }

  Future<void> logout() async {
    await _repository.clearSession();
    _clearPendingRegistration();
    state = const AsyncValue.data(null);
  }

  void _startOtpCountdown() {
    _stopOtpTimer();
    ref.read(otpResendSecondsProvider.notifier).state = 120;

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = ref.read(otpResendSecondsProvider);
      if (current <= 0) {
        _stopOtpTimer();
        return;
      }
      ref.read(otpResendSecondsProvider.notifier).state = current - 1;
    });
  }

  void _clearPendingRegistration() {
    _stopOtpTimer();
    ref.read(pendingRegistrationProvider.notifier).state = null;
    ref.read(otpResendSecondsProvider.notifier).state = 0;
  }

  void _stopOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = null;
  }
}
