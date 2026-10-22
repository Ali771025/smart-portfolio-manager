// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppFailure {
  String get message;
  int? get statusCode;
  bool get isNetwork;
  bool get isUnauthorized;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AppFailureCopyWith<AppFailure> get copyWith =>
      _$AppFailureCopyWithImpl<AppFailure>(this as AppFailure, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AppFailure &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            (identical(other.isNetwork, isNetwork) ||
                other.isNetwork == isNetwork) &&
            (identical(other.isUnauthorized, isUnauthorized) ||
                other.isUnauthorized == isUnauthorized));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, statusCode, isNetwork, isUnauthorized);

  @override
  String toString() {
    return 'AppFailure(message: $message, statusCode: $statusCode, isNetwork: $isNetwork, isUnauthorized: $isUnauthorized)';
  }
}

/// @nodoc
abstract mixin class $AppFailureCopyWith<$Res> {
  factory $AppFailureCopyWith(
          AppFailure value, $Res Function(AppFailure) _then) =
      _$AppFailureCopyWithImpl;
  @useResult
  $Res call(
      {String message, int? statusCode, bool isNetwork, bool isUnauthorized});
}

/// @nodoc
class _$AppFailureCopyWithImpl<$Res> implements $AppFailureCopyWith<$Res> {
  _$AppFailureCopyWithImpl(this._self, this._then);

  final AppFailure _self;
  final $Res Function(AppFailure) _then;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? statusCode = freezed,
    Object? isNetwork = null,
    Object? isUnauthorized = null,
  }) {
    return _then(_self.copyWith(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: freezed == statusCode
          ? _self.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int?,
      isNetwork: null == isNetwork
          ? _self.isNetwork
          : isNetwork // ignore: cast_nullable_to_non_nullable
              as bool,
      isUnauthorized: null == isUnauthorized
          ? _self.isUnauthorized
          : isUnauthorized // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [AppFailure].
extension AppFailurePatterns on AppFailure {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_AppFailure value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AppFailure() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_AppFailure value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppFailure():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_AppFailure value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppFailure() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String message, int? statusCode, bool isNetwork,
            bool isUnauthorized)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AppFailure() when $default != null:
        return $default(_that.message, _that.statusCode, _that.isNetwork,
            _that.isUnauthorized);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String message, int? statusCode, bool isNetwork,
            bool isUnauthorized)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppFailure():
        return $default(_that.message, _that.statusCode, _that.isNetwork,
            _that.isUnauthorized);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String message, int? statusCode, bool isNetwork,
            bool isUnauthorized)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppFailure() when $default != null:
        return $default(_that.message, _that.statusCode, _that.isNetwork,
            _that.isUnauthorized);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AppFailure implements AppFailure {
  const _AppFailure(
      {required this.message,
      this.statusCode,
      this.isNetwork = false,
      this.isUnauthorized = false});

  @override
  final String message;
  @override
  final int? statusCode;
  @override
  @JsonKey()
  final bool isNetwork;
  @override
  @JsonKey()
  final bool isUnauthorized;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AppFailureCopyWith<_AppFailure> get copyWith =>
      __$AppFailureCopyWithImpl<_AppFailure>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AppFailure &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            (identical(other.isNetwork, isNetwork) ||
                other.isNetwork == isNetwork) &&
            (identical(other.isUnauthorized, isUnauthorized) ||
                other.isUnauthorized == isUnauthorized));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, statusCode, isNetwork, isUnauthorized);

  @override
  String toString() {
    return 'AppFailure(message: $message, statusCode: $statusCode, isNetwork: $isNetwork, isUnauthorized: $isUnauthorized)';
  }
}

/// @nodoc
abstract mixin class _$AppFailureCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$AppFailureCopyWith(
          _AppFailure value, $Res Function(_AppFailure) _then) =
      __$AppFailureCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String message, int? statusCode, bool isNetwork, bool isUnauthorized});
}

/// @nodoc
class __$AppFailureCopyWithImpl<$Res> implements _$AppFailureCopyWith<$Res> {
  __$AppFailureCopyWithImpl(this._self, this._then);

  final _AppFailure _self;
  final $Res Function(_AppFailure) _then;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
    Object? statusCode = freezed,
    Object? isNetwork = null,
    Object? isUnauthorized = null,
  }) {
    return _then(_AppFailure(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      statusCode: freezed == statusCode
          ? _self.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int?,
      isNetwork: null == isNetwork
          ? _self.isNetwork
          : isNetwork // ignore: cast_nullable_to_non_nullable
              as bool,
      isUnauthorized: null == isUnauthorized
          ? _self.isUnauthorized
          : isUnauthorized // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
