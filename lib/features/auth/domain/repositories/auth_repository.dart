import 'package:fpdart/fpdart.dart';

import '../models/auth_failure.dart';
import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<Either<AuthFailure, Unit>> registerInit({
    required String email,
    required String password,
    required String rePassword,
  });

  Future<Either<AuthFailure, AuthSession>> registerVerify({
    required String email,
    required String otp,
  });

  Future<Either<AuthFailure, AuthSession>> login({
    required String email,
    required String password,
  });

  Future<void> persistSession(AuthSession session);

  Future<AuthSession?> readCachedSession();

  Future<void> clearSession();
}
