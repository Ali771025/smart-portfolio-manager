// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'portfolio_card_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PortfolioCardDto {
  String get id;
  String get name;
  double get totalValue;
  double get roiPercent;
  double get riskStdDeviation;
  List<double> get sparklineValues;
  bool get isDefault;

  /// Create a copy of PortfolioCardDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioCardDtoCopyWith<PortfolioCardDto> get copyWith =>
      _$PortfolioCardDtoCopyWithImpl<PortfolioCardDto>(
          this as PortfolioCardDto, _$identity);

  /// Serializes this PortfolioCardDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioCardDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.totalValue, totalValue) ||
                other.totalValue == totalValue) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent) &&
            (identical(other.riskStdDeviation, riskStdDeviation) ||
                other.riskStdDeviation == riskStdDeviation) &&
            const DeepCollectionEquality()
                .equals(other.sparklineValues, sparklineValues) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      totalValue,
      roiPercent,
      riskStdDeviation,
      const DeepCollectionEquality().hash(sparklineValues),
      isDefault);

  @override
  String toString() {
    return 'PortfolioCardDto(id: $id, name: $name, totalValue: $totalValue, roiPercent: $roiPercent, riskStdDeviation: $riskStdDeviation, sparklineValues: $sparklineValues, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class $PortfolioCardDtoCopyWith<$Res> {
  factory $PortfolioCardDtoCopyWith(
          PortfolioCardDto value, $Res Function(PortfolioCardDto) _then) =
      _$PortfolioCardDtoCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      double totalValue,
      double roiPercent,
      double riskStdDeviation,
      List<double> sparklineValues,
      bool isDefault});
}

/// @nodoc
class _$PortfolioCardDtoCopyWithImpl<$Res>
    implements $PortfolioCardDtoCopyWith<$Res> {
  _$PortfolioCardDtoCopyWithImpl(this._self, this._then);

  final PortfolioCardDto _self;
  final $Res Function(PortfolioCardDto) _then;

  /// Create a copy of PortfolioCardDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? totalValue = null,
    Object? roiPercent = null,
    Object? riskStdDeviation = null,
    Object? sparklineValues = null,
    Object? isDefault = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      totalValue: null == totalValue
          ? _self.totalValue
          : totalValue // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
      riskStdDeviation: null == riskStdDeviation
          ? _self.riskStdDeviation
          : riskStdDeviation // ignore: cast_nullable_to_non_nullable
              as double,
      sparklineValues: null == sparklineValues
          ? _self.sparklineValues
          : sparklineValues // ignore: cast_nullable_to_non_nullable
              as List<double>,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioCardDto].
extension PortfolioCardDtoPatterns on PortfolioCardDto {
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
    TResult Function(_PortfolioCardDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto() when $default != null:
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
    TResult Function(_PortfolioCardDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto():
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
    TResult? Function(_PortfolioCardDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto() when $default != null:
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
            String id,
            String name,
            double totalValue,
            double roiPercent,
            double riskStdDeviation,
            List<double> sparklineValues,
            bool isDefault)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.totalValue,
            _that.roiPercent,
            _that.riskStdDeviation,
            _that.sparklineValues,
            _that.isDefault);
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
            String id,
            String name,
            double totalValue,
            double roiPercent,
            double riskStdDeviation,
            List<double> sparklineValues,
            bool isDefault)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto():
        return $default(
            _that.id,
            _that.name,
            _that.totalValue,
            _that.roiPercent,
            _that.riskStdDeviation,
            _that.sparklineValues,
            _that.isDefault);
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
            String id,
            String name,
            double totalValue,
            double roiPercent,
            double riskStdDeviation,
            List<double> sparklineValues,
            bool isDefault)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioCardDto() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.totalValue,
            _that.roiPercent,
            _that.riskStdDeviation,
            _that.sparklineValues,
            _that.isDefault);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PortfolioCardDto extends PortfolioCardDto {
  const _PortfolioCardDto(
      {required this.id,
      required this.name,
      required this.totalValue,
      required this.roiPercent,
      required this.riskStdDeviation,
      final List<double> sparklineValues = const <double>[],
      this.isDefault = false})
      : _sparklineValues = sparklineValues,
        super._();
  factory _PortfolioCardDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioCardDtoFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final double totalValue;
  @override
  final double roiPercent;
  @override
  final double riskStdDeviation;
  final List<double> _sparklineValues;
  @override
  @JsonKey()
  List<double> get sparklineValues {
    if (_sparklineValues is EqualUnmodifiableListView) return _sparklineValues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sparklineValues);
  }

  @override
  @JsonKey()
  final bool isDefault;

  /// Create a copy of PortfolioCardDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioCardDtoCopyWith<_PortfolioCardDto> get copyWith =>
      __$PortfolioCardDtoCopyWithImpl<_PortfolioCardDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PortfolioCardDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioCardDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.totalValue, totalValue) ||
                other.totalValue == totalValue) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent) &&
            (identical(other.riskStdDeviation, riskStdDeviation) ||
                other.riskStdDeviation == riskStdDeviation) &&
            const DeepCollectionEquality()
                .equals(other._sparklineValues, _sparklineValues) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      totalValue,
      roiPercent,
      riskStdDeviation,
      const DeepCollectionEquality().hash(_sparklineValues),
      isDefault);

  @override
  String toString() {
    return 'PortfolioCardDto(id: $id, name: $name, totalValue: $totalValue, roiPercent: $roiPercent, riskStdDeviation: $riskStdDeviation, sparklineValues: $sparklineValues, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioCardDtoCopyWith<$Res>
    implements $PortfolioCardDtoCopyWith<$Res> {
  factory _$PortfolioCardDtoCopyWith(
          _PortfolioCardDto value, $Res Function(_PortfolioCardDto) _then) =
      __$PortfolioCardDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      double totalValue,
      double roiPercent,
      double riskStdDeviation,
      List<double> sparklineValues,
      bool isDefault});
}

/// @nodoc
class __$PortfolioCardDtoCopyWithImpl<$Res>
    implements _$PortfolioCardDtoCopyWith<$Res> {
  __$PortfolioCardDtoCopyWithImpl(this._self, this._then);

  final _PortfolioCardDto _self;
  final $Res Function(_PortfolioCardDto) _then;

  /// Create a copy of PortfolioCardDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? totalValue = null,
    Object? roiPercent = null,
    Object? riskStdDeviation = null,
    Object? sparklineValues = null,
    Object? isDefault = null,
  }) {
    return _then(_PortfolioCardDto(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      totalValue: null == totalValue
          ? _self.totalValue
          : totalValue // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
      riskStdDeviation: null == riskStdDeviation
          ? _self.riskStdDeviation
          : riskStdDeviation // ignore: cast_nullable_to_non_nullable
              as double,
      sparklineValues: null == sparklineValues
          ? _self._sparklineValues
          : sparklineValues // ignore: cast_nullable_to_non_nullable
              as List<double>,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$PortfolioOptionDto {
  String get id;
  String get title;

  /// Create a copy of PortfolioOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioOptionDtoCopyWith<PortfolioOptionDto> get copyWith =>
      _$PortfolioOptionDtoCopyWithImpl<PortfolioOptionDto>(
          this as PortfolioOptionDto, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioOptionDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title);

  @override
  String toString() {
    return 'PortfolioOptionDto(id: $id, title: $title)';
  }
}

/// @nodoc
abstract mixin class $PortfolioOptionDtoCopyWith<$Res> {
  factory $PortfolioOptionDtoCopyWith(
          PortfolioOptionDto value, $Res Function(PortfolioOptionDto) _then) =
      _$PortfolioOptionDtoCopyWithImpl;
  @useResult
  $Res call({String id, String title});
}

/// @nodoc
class _$PortfolioOptionDtoCopyWithImpl<$Res>
    implements $PortfolioOptionDtoCopyWith<$Res> {
  _$PortfolioOptionDtoCopyWithImpl(this._self, this._then);

  final PortfolioOptionDto _self;
  final $Res Function(PortfolioOptionDto) _then;

  /// Create a copy of PortfolioOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioOptionDto].
extension PortfolioOptionDtoPatterns on PortfolioOptionDto {
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
    TResult Function(_PortfolioOptionDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto() when $default != null:
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
    TResult Function(_PortfolioOptionDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto():
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
    TResult? Function(_PortfolioOptionDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto() when $default != null:
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
    TResult Function(String id, String title)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto() when $default != null:
        return $default(_that.id, _that.title);
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
    TResult Function(String id, String title) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto():
        return $default(_that.id, _that.title);
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
    TResult? Function(String id, String title)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioOptionDto() when $default != null:
        return $default(_that.id, _that.title);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PortfolioOptionDto implements PortfolioOptionDto {
  const _PortfolioOptionDto({required this.id, required this.title});

  @override
  final String id;
  @override
  final String title;

  /// Create a copy of PortfolioOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioOptionDtoCopyWith<_PortfolioOptionDto> get copyWith =>
      __$PortfolioOptionDtoCopyWithImpl<_PortfolioOptionDto>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioOptionDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, title);

  @override
  String toString() {
    return 'PortfolioOptionDto(id: $id, title: $title)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioOptionDtoCopyWith<$Res>
    implements $PortfolioOptionDtoCopyWith<$Res> {
  factory _$PortfolioOptionDtoCopyWith(
          _PortfolioOptionDto value, $Res Function(_PortfolioOptionDto) _then) =
      __$PortfolioOptionDtoCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String title});
}

/// @nodoc
class __$PortfolioOptionDtoCopyWithImpl<$Res>
    implements _$PortfolioOptionDtoCopyWith<$Res> {
  __$PortfolioOptionDtoCopyWithImpl(this._self, this._then);

  final _PortfolioOptionDto _self;
  final $Res Function(_PortfolioOptionDto) _then;

  /// Create a copy of PortfolioOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
  }) {
    return _then(_PortfolioOptionDto(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
