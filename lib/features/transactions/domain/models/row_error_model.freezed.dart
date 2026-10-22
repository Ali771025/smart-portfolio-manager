// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'row_error_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RowErrorModel {
  String get type;
  String get title;
  @JsonKey(fromJson: _toInt)
  int get status;
  String get detail;
  String get instance;
  @JsonKey(
      name: 'row_number', readValue: _readRowNumber, fromJson: _toNullableInt)
  int? get rowNumber;
  @JsonKey(name: 'row_payload')
  Map<String, dynamic>? get rowPayload;

  /// Create a copy of RowErrorModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RowErrorModelCopyWith<RowErrorModel> get copyWith =>
      _$RowErrorModelCopyWithImpl<RowErrorModel>(
          this as RowErrorModel, _$identity);

  /// Serializes this RowErrorModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RowErrorModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.instance, instance) ||
                other.instance == instance) &&
            (identical(other.rowNumber, rowNumber) ||
                other.rowNumber == rowNumber) &&
            const DeepCollectionEquality()
                .equals(other.rowPayload, rowPayload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, title, status, detail,
      instance, rowNumber, const DeepCollectionEquality().hash(rowPayload));

  @override
  String toString() {
    return 'RowErrorModel(type: $type, title: $title, status: $status, detail: $detail, instance: $instance, rowNumber: $rowNumber, rowPayload: $rowPayload)';
  }
}

/// @nodoc
abstract mixin class $RowErrorModelCopyWith<$Res> {
  factory $RowErrorModelCopyWith(
          RowErrorModel value, $Res Function(RowErrorModel) _then) =
      _$RowErrorModelCopyWithImpl;
  @useResult
  $Res call(
      {String type,
      String title,
      @JsonKey(fromJson: _toInt) int status,
      String detail,
      String instance,
      @JsonKey(
          name: 'row_number',
          readValue: _readRowNumber,
          fromJson: _toNullableInt)
      int? rowNumber,
      @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload});
}

/// @nodoc
class _$RowErrorModelCopyWithImpl<$Res>
    implements $RowErrorModelCopyWith<$Res> {
  _$RowErrorModelCopyWithImpl(this._self, this._then);

  final RowErrorModel _self;
  final $Res Function(RowErrorModel) _then;

  /// Create a copy of RowErrorModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? title = null,
    Object? status = null,
    Object? detail = null,
    Object? instance = null,
    Object? rowNumber = freezed,
    Object? rowPayload = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      instance: null == instance
          ? _self.instance
          : instance // ignore: cast_nullable_to_non_nullable
              as String,
      rowNumber: freezed == rowNumber
          ? _self.rowNumber
          : rowNumber // ignore: cast_nullable_to_non_nullable
              as int?,
      rowPayload: freezed == rowPayload
          ? _self.rowPayload
          : rowPayload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RowErrorModel].
extension RowErrorModelPatterns on RowErrorModel {
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
    TResult Function(_RowErrorModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel() when $default != null:
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
    TResult Function(_RowErrorModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel():
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
    TResult? Function(_RowErrorModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel() when $default != null:
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
    TResult Function(
            String type,
            String title,
            @JsonKey(fromJson: _toInt) int status,
            String detail,
            String instance,
            @JsonKey(
                name: 'row_number',
                readValue: _readRowNumber,
                fromJson: _toNullableInt)
            int? rowNumber,
            @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel() when $default != null:
        return $default(_that.type, _that.title, _that.status, _that.detail,
            _that.instance, _that.rowNumber, _that.rowPayload);
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
    TResult Function(
            String type,
            String title,
            @JsonKey(fromJson: _toInt) int status,
            String detail,
            String instance,
            @JsonKey(
                name: 'row_number',
                readValue: _readRowNumber,
                fromJson: _toNullableInt)
            int? rowNumber,
            @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel():
        return $default(_that.type, _that.title, _that.status, _that.detail,
            _that.instance, _that.rowNumber, _that.rowPayload);
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
    TResult? Function(
            String type,
            String title,
            @JsonKey(fromJson: _toInt) int status,
            String detail,
            String instance,
            @JsonKey(
                name: 'row_number',
                readValue: _readRowNumber,
                fromJson: _toNullableInt)
            int? rowNumber,
            @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RowErrorModel() when $default != null:
        return $default(_that.type, _that.title, _that.status, _that.detail,
            _that.instance, _that.rowNumber, _that.rowPayload);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RowErrorModel extends RowErrorModel {
  const _RowErrorModel(
      {this.type = 'about:blank',
      this.title = 'Import row error',
      @JsonKey(fromJson: _toInt) this.status = 400,
      this.detail = 'Unknown row import error.',
      this.instance = '',
      @JsonKey(
          name: 'row_number',
          readValue: _readRowNumber,
          fromJson: _toNullableInt)
      this.rowNumber,
      @JsonKey(name: 'row_payload') final Map<String, dynamic>? rowPayload})
      : _rowPayload = rowPayload,
        super._();
  factory _RowErrorModel.fromJson(Map<String, dynamic> json) =>
      _$RowErrorModelFromJson(json);

  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey(fromJson: _toInt)
  final int status;
  @override
  @JsonKey()
  final String detail;
  @override
  @JsonKey()
  final String instance;
  @override
  @JsonKey(
      name: 'row_number', readValue: _readRowNumber, fromJson: _toNullableInt)
  final int? rowNumber;
  final Map<String, dynamic>? _rowPayload;
  @override
  @JsonKey(name: 'row_payload')
  Map<String, dynamic>? get rowPayload {
    final value = _rowPayload;
    if (value == null) return null;
    if (_rowPayload is EqualUnmodifiableMapView) return _rowPayload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of RowErrorModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RowErrorModelCopyWith<_RowErrorModel> get copyWith =>
      __$RowErrorModelCopyWithImpl<_RowErrorModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RowErrorModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RowErrorModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.instance, instance) ||
                other.instance == instance) &&
            (identical(other.rowNumber, rowNumber) ||
                other.rowNumber == rowNumber) &&
            const DeepCollectionEquality()
                .equals(other._rowPayload, _rowPayload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, title, status, detail,
      instance, rowNumber, const DeepCollectionEquality().hash(_rowPayload));

  @override
  String toString() {
    return 'RowErrorModel(type: $type, title: $title, status: $status, detail: $detail, instance: $instance, rowNumber: $rowNumber, rowPayload: $rowPayload)';
  }
}

/// @nodoc
abstract mixin class _$RowErrorModelCopyWith<$Res>
    implements $RowErrorModelCopyWith<$Res> {
  factory _$RowErrorModelCopyWith(
          _RowErrorModel value, $Res Function(_RowErrorModel) _then) =
      __$RowErrorModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String type,
      String title,
      @JsonKey(fromJson: _toInt) int status,
      String detail,
      String instance,
      @JsonKey(
          name: 'row_number',
          readValue: _readRowNumber,
          fromJson: _toNullableInt)
      int? rowNumber,
      @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload});
}

/// @nodoc
class __$RowErrorModelCopyWithImpl<$Res>
    implements _$RowErrorModelCopyWith<$Res> {
  __$RowErrorModelCopyWithImpl(this._self, this._then);

  final _RowErrorModel _self;
  final $Res Function(_RowErrorModel) _then;

  /// Create a copy of RowErrorModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? title = null,
    Object? status = null,
    Object? detail = null,
    Object? instance = null,
    Object? rowNumber = freezed,
    Object? rowPayload = freezed,
  }) {
    return _then(_RowErrorModel(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as int,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      instance: null == instance
          ? _self.instance
          : instance // ignore: cast_nullable_to_non_nullable
              as String,
      rowNumber: freezed == rowNumber
          ? _self.rowNumber
          : rowNumber // ignore: cast_nullable_to_non_nullable
              as int?,
      rowPayload: freezed == rowPayload
          ? _self._rowPayload
          : rowPayload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

// dart format on
