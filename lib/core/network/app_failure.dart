import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_failure.freezed.dart';

@freezed
abstract class AppFailure with _$AppFailure {
  const factory AppFailure({
    required String message,
    int? statusCode,
    @Default(false) bool isNetwork,
    @Default(false) bool isUnauthorized,
  }) = _AppFailure;
}
