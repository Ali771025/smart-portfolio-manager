import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_failure.freezed.dart';

@freezed
abstract class AuthFailure with _$AuthFailure {
  const factory AuthFailure({
    required String message,
    int? statusCode,
    @Default(false) bool isValidationError,
  }) = _AuthFailure;
}
