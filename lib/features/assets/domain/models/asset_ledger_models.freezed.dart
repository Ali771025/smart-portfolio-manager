// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asset_ledger_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LedgerEntryDto {
  String get id;
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(name: 'asset_id')
  String get assetId;
  @JsonKey(name: 'transaction_type')
  String get transactionType;
  @JsonKey(name: 'executed_at')
  DateTime get executedAt;
  String? get notes;
  @DecimalStringJsonConverter()
  Decimal get quantity;
  @JsonKey(name: 'price_per_unit')
  @DecimalStringJsonConverter()
  Decimal get pricePerUnit;
  @DecimalStringJsonConverter()
  Decimal get fees;
  @JsonKey(name: 'total_amount')
  @DecimalStringJsonConverter()
  Decimal get totalAmount;
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  Decimal get realizedPnl;
  @JsonKey(name: 'wac_at_execution')
  @DecimalStringJsonConverter()
  Decimal get wacAtExecution;

  /// Create a copy of LedgerEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LedgerEntryDtoCopyWith<LedgerEntryDto> get copyWith =>
      _$LedgerEntryDtoCopyWithImpl<LedgerEntryDto>(
          this as LedgerEntryDto, _$identity);

  /// Serializes this LedgerEntryDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LedgerEntryDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.pricePerUnit, pricePerUnit) ||
                other.pricePerUnit == pricePerUnit) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl) &&
            (identical(other.wacAtExecution, wacAtExecution) ||
                other.wacAtExecution == wacAtExecution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      portfolioId,
      assetId,
      transactionType,
      executedAt,
      notes,
      quantity,
      pricePerUnit,
      fees,
      totalAmount,
      realizedPnl,
      wacAtExecution);

  @override
  String toString() {
    return 'LedgerEntryDto(id: $id, portfolioId: $portfolioId, assetId: $assetId, transactionType: $transactionType, executedAt: $executedAt, notes: $notes, quantity: $quantity, pricePerUnit: $pricePerUnit, fees: $fees, totalAmount: $totalAmount, realizedPnl: $realizedPnl, wacAtExecution: $wacAtExecution)';
  }
}

/// @nodoc
abstract mixin class $LedgerEntryDtoCopyWith<$Res> {
  factory $LedgerEntryDtoCopyWith(
          LedgerEntryDto value, $Res Function(LedgerEntryDto) _then) =
      _$LedgerEntryDtoCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'transaction_type') String transactionType,
      @JsonKey(name: 'executed_at') DateTime executedAt,
      String? notes,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      Decimal pricePerUnit,
      @DecimalStringJsonConverter() Decimal fees,
      @JsonKey(name: 'total_amount')
      @DecimalStringJsonConverter()
      Decimal totalAmount,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl,
      @JsonKey(name: 'wac_at_execution')
      @DecimalStringJsonConverter()
      Decimal wacAtExecution});
}

/// @nodoc
class _$LedgerEntryDtoCopyWithImpl<$Res>
    implements $LedgerEntryDtoCopyWith<$Res> {
  _$LedgerEntryDtoCopyWithImpl(this._self, this._then);

  final LedgerEntryDto _self;
  final $Res Function(LedgerEntryDto) _then;

  /// Create a copy of LedgerEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? portfolioId = null,
    Object? assetId = null,
    Object? transactionType = null,
    Object? executedAt = null,
    Object? notes = freezed,
    Object? quantity = null,
    Object? pricePerUnit = null,
    Object? fees = null,
    Object? totalAmount = null,
    Object? realizedPnl = null,
    Object? wacAtExecution = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      transactionType: null == transactionType
          ? _self.transactionType
          : transactionType // ignore: cast_nullable_to_non_nullable
              as String,
      executedAt: null == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      pricePerUnit: null == pricePerUnit
          ? _self.pricePerUnit
          : pricePerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal,
      fees: null == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalAmount: null == totalAmount
          ? _self.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      wacAtExecution: null == wacAtExecution
          ? _self.wacAtExecution
          : wacAtExecution // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// Adds pattern-matching-related methods to [LedgerEntryDto].
extension LedgerEntryDtoPatterns on LedgerEntryDto {
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
    TResult Function(_LedgerEntryDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto() when $default != null:
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
    TResult Function(_LedgerEntryDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto():
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
    TResult? Function(_LedgerEntryDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto() when $default != null:
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @JsonKey(name: 'executed_at') DateTime executedAt,
            String? notes,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal pricePerUnit,
            @DecimalStringJsonConverter() Decimal fees,
            @JsonKey(name: 'total_amount')
            @DecimalStringJsonConverter()
            Decimal totalAmount,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl,
            @JsonKey(name: 'wac_at_execution')
            @DecimalStringJsonConverter()
            Decimal wacAtExecution)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto() when $default != null:
        return $default(
            _that.id,
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.executedAt,
            _that.notes,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.totalAmount,
            _that.realizedPnl,
            _that.wacAtExecution);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @JsonKey(name: 'executed_at') DateTime executedAt,
            String? notes,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal pricePerUnit,
            @DecimalStringJsonConverter() Decimal fees,
            @JsonKey(name: 'total_amount')
            @DecimalStringJsonConverter()
            Decimal totalAmount,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl,
            @JsonKey(name: 'wac_at_execution')
            @DecimalStringJsonConverter()
            Decimal wacAtExecution)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto():
        return $default(
            _that.id,
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.executedAt,
            _that.notes,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.totalAmount,
            _that.realizedPnl,
            _that.wacAtExecution);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @JsonKey(name: 'executed_at') DateTime executedAt,
            String? notes,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal pricePerUnit,
            @DecimalStringJsonConverter() Decimal fees,
            @JsonKey(name: 'total_amount')
            @DecimalStringJsonConverter()
            Decimal totalAmount,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl,
            @JsonKey(name: 'wac_at_execution')
            @DecimalStringJsonConverter()
            Decimal wacAtExecution)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerEntryDto() when $default != null:
        return $default(
            _that.id,
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.executedAt,
            _that.notes,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.totalAmount,
            _that.realizedPnl,
            _that.wacAtExecution);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LedgerEntryDto implements LedgerEntryDto {
  const _LedgerEntryDto(
      {required this.id,
      @JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(name: 'asset_id') required this.assetId,
      @JsonKey(name: 'transaction_type') required this.transactionType,
      @JsonKey(name: 'executed_at') required this.executedAt,
      this.notes,
      @DecimalStringJsonConverter() required this.quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      required this.pricePerUnit,
      @DecimalStringJsonConverter() required this.fees,
      @JsonKey(name: 'total_amount')
      @DecimalStringJsonConverter()
      required this.totalAmount,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      required this.realizedPnl,
      @JsonKey(name: 'wac_at_execution')
      @DecimalStringJsonConverter()
      required this.wacAtExecution});
  factory _LedgerEntryDto.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryDtoFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(name: 'asset_id')
  final String assetId;
  @override
  @JsonKey(name: 'transaction_type')
  final String transactionType;
  @override
  @JsonKey(name: 'executed_at')
  final DateTime executedAt;
  @override
  final String? notes;
  @override
  @DecimalStringJsonConverter()
  final Decimal quantity;
  @override
  @JsonKey(name: 'price_per_unit')
  @DecimalStringJsonConverter()
  final Decimal pricePerUnit;
  @override
  @DecimalStringJsonConverter()
  final Decimal fees;
  @override
  @JsonKey(name: 'total_amount')
  @DecimalStringJsonConverter()
  final Decimal totalAmount;
  @override
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  final Decimal realizedPnl;
  @override
  @JsonKey(name: 'wac_at_execution')
  @DecimalStringJsonConverter()
  final Decimal wacAtExecution;

  /// Create a copy of LedgerEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LedgerEntryDtoCopyWith<_LedgerEntryDto> get copyWith =>
      __$LedgerEntryDtoCopyWithImpl<_LedgerEntryDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LedgerEntryDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LedgerEntryDto &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.pricePerUnit, pricePerUnit) ||
                other.pricePerUnit == pricePerUnit) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl) &&
            (identical(other.wacAtExecution, wacAtExecution) ||
                other.wacAtExecution == wacAtExecution));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      portfolioId,
      assetId,
      transactionType,
      executedAt,
      notes,
      quantity,
      pricePerUnit,
      fees,
      totalAmount,
      realizedPnl,
      wacAtExecution);

  @override
  String toString() {
    return 'LedgerEntryDto(id: $id, portfolioId: $portfolioId, assetId: $assetId, transactionType: $transactionType, executedAt: $executedAt, notes: $notes, quantity: $quantity, pricePerUnit: $pricePerUnit, fees: $fees, totalAmount: $totalAmount, realizedPnl: $realizedPnl, wacAtExecution: $wacAtExecution)';
  }
}

/// @nodoc
abstract mixin class _$LedgerEntryDtoCopyWith<$Res>
    implements $LedgerEntryDtoCopyWith<$Res> {
  factory _$LedgerEntryDtoCopyWith(
          _LedgerEntryDto value, $Res Function(_LedgerEntryDto) _then) =
      __$LedgerEntryDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'transaction_type') String transactionType,
      @JsonKey(name: 'executed_at') DateTime executedAt,
      String? notes,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      Decimal pricePerUnit,
      @DecimalStringJsonConverter() Decimal fees,
      @JsonKey(name: 'total_amount')
      @DecimalStringJsonConverter()
      Decimal totalAmount,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl,
      @JsonKey(name: 'wac_at_execution')
      @DecimalStringJsonConverter()
      Decimal wacAtExecution});
}

/// @nodoc
class __$LedgerEntryDtoCopyWithImpl<$Res>
    implements _$LedgerEntryDtoCopyWith<$Res> {
  __$LedgerEntryDtoCopyWithImpl(this._self, this._then);

  final _LedgerEntryDto _self;
  final $Res Function(_LedgerEntryDto) _then;

  /// Create a copy of LedgerEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? portfolioId = null,
    Object? assetId = null,
    Object? transactionType = null,
    Object? executedAt = null,
    Object? notes = freezed,
    Object? quantity = null,
    Object? pricePerUnit = null,
    Object? fees = null,
    Object? totalAmount = null,
    Object? realizedPnl = null,
    Object? wacAtExecution = null,
  }) {
    return _then(_LedgerEntryDto(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      transactionType: null == transactionType
          ? _self.transactionType
          : transactionType // ignore: cast_nullable_to_non_nullable
              as String,
      executedAt: null == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      pricePerUnit: null == pricePerUnit
          ? _self.pricePerUnit
          : pricePerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal,
      fees: null == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalAmount: null == totalAmount
          ? _self.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      wacAtExecution: null == wacAtExecution
          ? _self.wacAtExecution
          : wacAtExecution // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc
mixin _$AssetLedgerPageDto {
  List<LedgerEntryDto> get items;
  int get total;
  int get limit;
  int get offset;

  /// Create a copy of AssetLedgerPageDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetLedgerPageDtoCopyWith<AssetLedgerPageDto> get copyWith =>
      _$AssetLedgerPageDtoCopyWithImpl<AssetLedgerPageDto>(
          this as AssetLedgerPageDto, _$identity);

  /// Serializes this AssetLedgerPageDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssetLedgerPageDto &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(items), total, limit, offset);

  @override
  String toString() {
    return 'AssetLedgerPageDto(items: $items, total: $total, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class $AssetLedgerPageDtoCopyWith<$Res> {
  factory $AssetLedgerPageDtoCopyWith(
          AssetLedgerPageDto value, $Res Function(AssetLedgerPageDto) _then) =
      _$AssetLedgerPageDtoCopyWithImpl;
  @useResult
  $Res call({List<LedgerEntryDto> items, int total, int limit, int offset});
}

/// @nodoc
class _$AssetLedgerPageDtoCopyWithImpl<$Res>
    implements $AssetLedgerPageDtoCopyWith<$Res> {
  _$AssetLedgerPageDtoCopyWithImpl(this._self, this._then);

  final AssetLedgerPageDto _self;
  final $Res Function(AssetLedgerPageDto) _then;

  /// Create a copy of AssetLedgerPageDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<LedgerEntryDto>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [AssetLedgerPageDto].
extension AssetLedgerPageDtoPatterns on AssetLedgerPageDto {
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
    TResult Function(_AssetLedgerPageDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto() when $default != null:
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
    TResult Function(_AssetLedgerPageDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto():
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
    TResult? Function(_AssetLedgerPageDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto() when $default != null:
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
            List<LedgerEntryDto> items, int total, int limit, int offset)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset);
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
            List<LedgerEntryDto> items, int total, int limit, int offset)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto():
        return $default(_that.items, _that.total, _that.limit, _that.offset);
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
            List<LedgerEntryDto> items, int total, int limit, int offset)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetLedgerPageDto() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AssetLedgerPageDto implements AssetLedgerPageDto {
  const _AssetLedgerPageDto(
      {final List<LedgerEntryDto> items = const <LedgerEntryDto>[],
      this.total = 0,
      this.limit = 50,
      this.offset = 0})
      : _items = items;
  factory _AssetLedgerPageDto.fromJson(Map<String, dynamic> json) =>
      _$AssetLedgerPageDtoFromJson(json);

  final List<LedgerEntryDto> _items;
  @override
  @JsonKey()
  List<LedgerEntryDto> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  @JsonKey()
  final int total;
  @override
  @JsonKey()
  final int limit;
  @override
  @JsonKey()
  final int offset;

  /// Create a copy of AssetLedgerPageDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssetLedgerPageDtoCopyWith<_AssetLedgerPageDto> get copyWith =>
      __$AssetLedgerPageDtoCopyWithImpl<_AssetLedgerPageDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AssetLedgerPageDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AssetLedgerPageDto &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_items), total, limit, offset);

  @override
  String toString() {
    return 'AssetLedgerPageDto(items: $items, total: $total, limit: $limit, offset: $offset)';
  }
}

/// @nodoc
abstract mixin class _$AssetLedgerPageDtoCopyWith<$Res>
    implements $AssetLedgerPageDtoCopyWith<$Res> {
  factory _$AssetLedgerPageDtoCopyWith(
          _AssetLedgerPageDto value, $Res Function(_AssetLedgerPageDto) _then) =
      __$AssetLedgerPageDtoCopyWithImpl;
  @override
  @useResult
  $Res call({List<LedgerEntryDto> items, int total, int limit, int offset});
}

/// @nodoc
class __$AssetLedgerPageDtoCopyWithImpl<$Res>
    implements _$AssetLedgerPageDtoCopyWith<$Res> {
  __$AssetLedgerPageDtoCopyWithImpl(this._self, this._then);

  final _AssetLedgerPageDto _self;
  final $Res Function(_AssetLedgerPageDto) _then;

  /// Create a copy of AssetLedgerPageDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_AssetLedgerPageDto(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<LedgerEntryDto>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _self.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$AssetPositionDto {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(name: 'asset_id')
  String get assetId;
  @DecimalStringJsonConverter()
  Decimal get quantity;
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  Decimal get weightedAvgCost;
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  Decimal get totalCostBasis;
  @JsonKey(name: 'latest_price')
  @DecimalStringJsonConverter()
  Decimal get latestPrice;
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  Decimal get marketValue;
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  Decimal get unrealizedPnl;
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  Decimal get realizedPnl;

  /// Create a copy of AssetPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetPositionDtoCopyWith<AssetPositionDto> get copyWith =>
      _$AssetPositionDtoCopyWithImpl<AssetPositionDto>(
          this as AssetPositionDto, _$identity);

  /// Serializes this AssetPositionDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssetPositionDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.latestPrice, latestPrice) ||
                other.latestPrice == latestPrice) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      assetId,
      quantity,
      weightedAvgCost,
      totalCostBasis,
      latestPrice,
      marketValue,
      unrealizedPnl,
      realizedPnl);

  @override
  String toString() {
    return 'AssetPositionDto(portfolioId: $portfolioId, assetId: $assetId, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, latestPrice: $latestPrice, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class $AssetPositionDtoCopyWith<$Res> {
  factory $AssetPositionDtoCopyWith(
          AssetPositionDto value, $Res Function(AssetPositionDto) _then) =
      _$AssetPositionDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      Decimal latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class _$AssetPositionDtoCopyWithImpl<$Res>
    implements $AssetPositionDtoCopyWith<$Res> {
  _$AssetPositionDtoCopyWithImpl(this._self, this._then);

  final AssetPositionDto _self;
  final $Res Function(AssetPositionDto) _then;

  /// Create a copy of AssetPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? latestPrice = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      latestPrice: null == latestPrice
          ? _self.latestPrice
          : latestPrice // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// Adds pattern-matching-related methods to [AssetPositionDto].
extension AssetPositionDtoPatterns on AssetPositionDto {
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
    TResult Function(_AssetPositionDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto() when $default != null:
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
    TResult Function(_AssetPositionDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto():
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
    TResult? Function(_AssetPositionDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto() when $default != null:
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto() when $default != null:
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto():
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetPositionDto() when $default != null:
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AssetPositionDto implements AssetPositionDto {
  const _AssetPositionDto(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(name: 'asset_id') required this.assetId,
      @DecimalStringJsonConverter() required this.quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      required this.weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      required this.totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      required this.latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      required this.marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      required this.unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      required this.realizedPnl});
  factory _AssetPositionDto.fromJson(Map<String, dynamic> json) =>
      _$AssetPositionDtoFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(name: 'asset_id')
  final String assetId;
  @override
  @DecimalStringJsonConverter()
  final Decimal quantity;
  @override
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  final Decimal weightedAvgCost;
  @override
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  final Decimal totalCostBasis;
  @override
  @JsonKey(name: 'latest_price')
  @DecimalStringJsonConverter()
  final Decimal latestPrice;
  @override
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  final Decimal marketValue;
  @override
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  final Decimal unrealizedPnl;
  @override
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  final Decimal realizedPnl;

  /// Create a copy of AssetPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssetPositionDtoCopyWith<_AssetPositionDto> get copyWith =>
      __$AssetPositionDtoCopyWithImpl<_AssetPositionDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AssetPositionDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AssetPositionDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.latestPrice, latestPrice) ||
                other.latestPrice == latestPrice) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      assetId,
      quantity,
      weightedAvgCost,
      totalCostBasis,
      latestPrice,
      marketValue,
      unrealizedPnl,
      realizedPnl);

  @override
  String toString() {
    return 'AssetPositionDto(portfolioId: $portfolioId, assetId: $assetId, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, latestPrice: $latestPrice, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class _$AssetPositionDtoCopyWith<$Res>
    implements $AssetPositionDtoCopyWith<$Res> {
  factory _$AssetPositionDtoCopyWith(
          _AssetPositionDto value, $Res Function(_AssetPositionDto) _then) =
      __$AssetPositionDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      Decimal latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class __$AssetPositionDtoCopyWithImpl<$Res>
    implements _$AssetPositionDtoCopyWith<$Res> {
  __$AssetPositionDtoCopyWithImpl(this._self, this._then);

  final _AssetPositionDto _self;
  final $Res Function(_AssetPositionDto) _then;

  /// Create a copy of AssetPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? latestPrice = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_AssetPositionDto(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      latestPrice: null == latestPrice
          ? _self.latestPrice
          : latestPrice // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc
mixin _$AssetValuationPointDto {
  DateTime get date;
  @DecimalStringJsonConverter()
  Decimal get quantity;
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  Decimal get weightedAvgCost;
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  Decimal get totalCostBasis;
  @DecimalStringJsonConverter()
  Decimal get price;
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  Decimal get marketValue;
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  Decimal get unrealizedPnl;
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  Decimal get realizedPnl;

  /// Create a copy of AssetValuationPointDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetValuationPointDtoCopyWith<AssetValuationPointDto> get copyWith =>
      _$AssetValuationPointDtoCopyWithImpl<AssetValuationPointDto>(
          this as AssetValuationPointDto, _$identity);

  /// Serializes this AssetValuationPointDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssetValuationPointDto &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, quantity, weightedAvgCost,
      totalCostBasis, price, marketValue, unrealizedPnl, realizedPnl);

  @override
  String toString() {
    return 'AssetValuationPointDto(date: $date, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, price: $price, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class $AssetValuationPointDtoCopyWith<$Res> {
  factory $AssetValuationPointDtoCopyWith(AssetValuationPointDto value,
          $Res Function(AssetValuationPointDto) _then) =
      _$AssetValuationPointDtoCopyWithImpl;
  @useResult
  $Res call(
      {DateTime date,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @DecimalStringJsonConverter() Decimal price,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class _$AssetValuationPointDtoCopyWithImpl<$Res>
    implements $AssetValuationPointDtoCopyWith<$Res> {
  _$AssetValuationPointDtoCopyWithImpl(this._self, this._then);

  final AssetValuationPointDto _self;
  final $Res Function(AssetValuationPointDto) _then;

  /// Create a copy of AssetValuationPointDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? price = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// Adds pattern-matching-related methods to [AssetValuationPointDto].
extension AssetValuationPointDtoPatterns on AssetValuationPointDto {
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
    TResult Function(_AssetValuationPointDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto() when $default != null:
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
    TResult Function(_AssetValuationPointDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto():
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
    TResult? Function(_AssetValuationPointDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto() when $default != null:
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
            DateTime date,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @DecimalStringJsonConverter() Decimal price,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto() when $default != null:
        return $default(
            _that.date,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.price,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            DateTime date,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @DecimalStringJsonConverter() Decimal price,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto():
        return $default(
            _that.date,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.price,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            DateTime date,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @DecimalStringJsonConverter() Decimal price,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationPointDto() when $default != null:
        return $default(
            _that.date,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.price,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AssetValuationPointDto implements AssetValuationPointDto {
  const _AssetValuationPointDto(
      {required this.date,
      @DecimalStringJsonConverter() required this.quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      required this.weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      required this.totalCostBasis,
      @DecimalStringJsonConverter() required this.price,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      required this.marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      required this.unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      required this.realizedPnl});
  factory _AssetValuationPointDto.fromJson(Map<String, dynamic> json) =>
      _$AssetValuationPointDtoFromJson(json);

  @override
  final DateTime date;
  @override
  @DecimalStringJsonConverter()
  final Decimal quantity;
  @override
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  final Decimal weightedAvgCost;
  @override
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  final Decimal totalCostBasis;
  @override
  @DecimalStringJsonConverter()
  final Decimal price;
  @override
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  final Decimal marketValue;
  @override
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  final Decimal unrealizedPnl;
  @override
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  final Decimal realizedPnl;

  /// Create a copy of AssetValuationPointDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssetValuationPointDtoCopyWith<_AssetValuationPointDto> get copyWith =>
      __$AssetValuationPointDtoCopyWithImpl<_AssetValuationPointDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AssetValuationPointDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AssetValuationPointDto &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, quantity, weightedAvgCost,
      totalCostBasis, price, marketValue, unrealizedPnl, realizedPnl);

  @override
  String toString() {
    return 'AssetValuationPointDto(date: $date, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, price: $price, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class _$AssetValuationPointDtoCopyWith<$Res>
    implements $AssetValuationPointDtoCopyWith<$Res> {
  factory _$AssetValuationPointDtoCopyWith(_AssetValuationPointDto value,
          $Res Function(_AssetValuationPointDto) _then) =
      __$AssetValuationPointDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime date,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @DecimalStringJsonConverter() Decimal price,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class __$AssetValuationPointDtoCopyWithImpl<$Res>
    implements _$AssetValuationPointDtoCopyWith<$Res> {
  __$AssetValuationPointDtoCopyWithImpl(this._self, this._then);

  final _AssetValuationPointDto _self;
  final $Res Function(_AssetValuationPointDto) _then;

  /// Create a copy of AssetValuationPointDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? price = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_AssetValuationPointDto(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc
mixin _$AssetValuationSeriesDto {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(name: 'asset_id')
  String get assetId;
  @JsonKey(name: 'adjusted_prices')
  bool get adjustedPrices;
  List<AssetValuationPointDto> get points;

  /// Create a copy of AssetValuationSeriesDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetValuationSeriesDtoCopyWith<AssetValuationSeriesDto> get copyWith =>
      _$AssetValuationSeriesDtoCopyWithImpl<AssetValuationSeriesDto>(
          this as AssetValuationSeriesDto, _$identity);

  /// Serializes this AssetValuationSeriesDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssetValuationSeriesDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.adjustedPrices, adjustedPrices) ||
                other.adjustedPrices == adjustedPrices) &&
            const DeepCollectionEquality().equals(other.points, points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, assetId,
      adjustedPrices, const DeepCollectionEquality().hash(points));

  @override
  String toString() {
    return 'AssetValuationSeriesDto(portfolioId: $portfolioId, assetId: $assetId, adjustedPrices: $adjustedPrices, points: $points)';
  }
}

/// @nodoc
abstract mixin class $AssetValuationSeriesDtoCopyWith<$Res> {
  factory $AssetValuationSeriesDtoCopyWith(AssetValuationSeriesDto value,
          $Res Function(AssetValuationSeriesDto) _then) =
      _$AssetValuationSeriesDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'adjusted_prices') bool adjustedPrices,
      List<AssetValuationPointDto> points});
}

/// @nodoc
class _$AssetValuationSeriesDtoCopyWithImpl<$Res>
    implements $AssetValuationSeriesDtoCopyWith<$Res> {
  _$AssetValuationSeriesDtoCopyWithImpl(this._self, this._then);

  final AssetValuationSeriesDto _self;
  final $Res Function(AssetValuationSeriesDto) _then;

  /// Create a copy of AssetValuationSeriesDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? adjustedPrices = null,
    Object? points = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      adjustedPrices: null == adjustedPrices
          ? _self.adjustedPrices
          : adjustedPrices // ignore: cast_nullable_to_non_nullable
              as bool,
      points: null == points
          ? _self.points
          : points // ignore: cast_nullable_to_non_nullable
              as List<AssetValuationPointDto>,
    ));
  }
}

/// Adds pattern-matching-related methods to [AssetValuationSeriesDto].
extension AssetValuationSeriesDtoPatterns on AssetValuationSeriesDto {
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
    TResult Function(_AssetValuationSeriesDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto() when $default != null:
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
    TResult Function(_AssetValuationSeriesDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto():
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
    TResult? Function(_AssetValuationSeriesDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto() when $default != null:
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'adjusted_prices') bool adjustedPrices,
            List<AssetValuationPointDto> points)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto() when $default != null:
        return $default(_that.portfolioId, _that.assetId, _that.adjustedPrices,
            _that.points);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'adjusted_prices') bool adjustedPrices,
            List<AssetValuationPointDto> points)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto():
        return $default(_that.portfolioId, _that.assetId, _that.adjustedPrices,
            _that.points);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'adjusted_prices') bool adjustedPrices,
            List<AssetValuationPointDto> points)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AssetValuationSeriesDto() when $default != null:
        return $default(_that.portfolioId, _that.assetId, _that.adjustedPrices,
            _that.points);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AssetValuationSeriesDto implements AssetValuationSeriesDto {
  const _AssetValuationSeriesDto(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(name: 'asset_id') required this.assetId,
      @JsonKey(name: 'adjusted_prices') required this.adjustedPrices,
      final List<AssetValuationPointDto> points =
          const <AssetValuationPointDto>[]})
      : _points = points;
  factory _AssetValuationSeriesDto.fromJson(Map<String, dynamic> json) =>
      _$AssetValuationSeriesDtoFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(name: 'asset_id')
  final String assetId;
  @override
  @JsonKey(name: 'adjusted_prices')
  final bool adjustedPrices;
  final List<AssetValuationPointDto> _points;
  @override
  @JsonKey()
  List<AssetValuationPointDto> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  /// Create a copy of AssetValuationSeriesDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssetValuationSeriesDtoCopyWith<_AssetValuationSeriesDto> get copyWith =>
      __$AssetValuationSeriesDtoCopyWithImpl<_AssetValuationSeriesDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AssetValuationSeriesDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AssetValuationSeriesDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.adjustedPrices, adjustedPrices) ||
                other.adjustedPrices == adjustedPrices) &&
            const DeepCollectionEquality().equals(other._points, _points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, assetId,
      adjustedPrices, const DeepCollectionEquality().hash(_points));

  @override
  String toString() {
    return 'AssetValuationSeriesDto(portfolioId: $portfolioId, assetId: $assetId, adjustedPrices: $adjustedPrices, points: $points)';
  }
}

/// @nodoc
abstract mixin class _$AssetValuationSeriesDtoCopyWith<$Res>
    implements $AssetValuationSeriesDtoCopyWith<$Res> {
  factory _$AssetValuationSeriesDtoCopyWith(_AssetValuationSeriesDto value,
          $Res Function(_AssetValuationSeriesDto) _then) =
      __$AssetValuationSeriesDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'adjusted_prices') bool adjustedPrices,
      List<AssetValuationPointDto> points});
}

/// @nodoc
class __$AssetValuationSeriesDtoCopyWithImpl<$Res>
    implements _$AssetValuationSeriesDtoCopyWith<$Res> {
  __$AssetValuationSeriesDtoCopyWithImpl(this._self, this._then);

  final _AssetValuationSeriesDto _self;
  final $Res Function(_AssetValuationSeriesDto) _then;

  /// Create a copy of AssetValuationSeriesDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? adjustedPrices = null,
    Object? points = null,
  }) {
    return _then(_AssetValuationSeriesDto(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      adjustedPrices: null == adjustedPrices
          ? _self.adjustedPrices
          : adjustedPrices // ignore: cast_nullable_to_non_nullable
              as bool,
      points: null == points
          ? _self._points
          : points // ignore: cast_nullable_to_non_nullable
              as List<AssetValuationPointDto>,
    ));
  }
}

/// @nodoc
mixin _$PortfolioPositionDto {
  @JsonKey(name: 'asset_id')
  String get assetId;
  @JsonKey(name: 'ticker_symbol')
  String get tickerSymbol;
  @DecimalStringJsonConverter()
  Decimal get quantity;
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  Decimal get weightedAvgCost;
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  Decimal get totalCostBasis;
  @JsonKey(name: 'latest_price')
  @DecimalStringJsonConverter()
  Decimal get latestPrice;
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  Decimal get marketValue;
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  Decimal get unrealizedPnl;
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  Decimal get realizedPnl;

  /// Create a copy of PortfolioPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioPositionDtoCopyWith<PortfolioPositionDto> get copyWith =>
      _$PortfolioPositionDtoCopyWithImpl<PortfolioPositionDto>(
          this as PortfolioPositionDto, _$identity);

  /// Serializes this PortfolioPositionDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioPositionDto &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.tickerSymbol, tickerSymbol) ||
                other.tickerSymbol == tickerSymbol) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.latestPrice, latestPrice) ||
                other.latestPrice == latestPrice) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assetId,
      tickerSymbol,
      quantity,
      weightedAvgCost,
      totalCostBasis,
      latestPrice,
      marketValue,
      unrealizedPnl,
      realizedPnl);

  @override
  String toString() {
    return 'PortfolioPositionDto(assetId: $assetId, tickerSymbol: $tickerSymbol, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, latestPrice: $latestPrice, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class $PortfolioPositionDtoCopyWith<$Res> {
  factory $PortfolioPositionDtoCopyWith(PortfolioPositionDto value,
          $Res Function(PortfolioPositionDto) _then) =
      _$PortfolioPositionDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'ticker_symbol') String tickerSymbol,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      Decimal latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class _$PortfolioPositionDtoCopyWithImpl<$Res>
    implements $PortfolioPositionDtoCopyWith<$Res> {
  _$PortfolioPositionDtoCopyWithImpl(this._self, this._then);

  final PortfolioPositionDto _self;
  final $Res Function(PortfolioPositionDto) _then;

  /// Create a copy of PortfolioPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assetId = null,
    Object? tickerSymbol = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? latestPrice = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_self.copyWith(
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      tickerSymbol: null == tickerSymbol
          ? _self.tickerSymbol
          : tickerSymbol // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      latestPrice: null == latestPrice
          ? _self.latestPrice
          : latestPrice // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioPositionDto].
extension PortfolioPositionDtoPatterns on PortfolioPositionDto {
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
    TResult Function(_PortfolioPositionDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto() when $default != null:
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
    TResult Function(_PortfolioPositionDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto():
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
    TResult? Function(_PortfolioPositionDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto() when $default != null:
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'ticker_symbol') String tickerSymbol,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto() when $default != null:
        return $default(
            _that.assetId,
            _that.tickerSymbol,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'ticker_symbol') String tickerSymbol,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto():
        return $default(
            _that.assetId,
            _that.tickerSymbol,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'ticker_symbol') String tickerSymbol,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'weighted_avg_cost')
            @DecimalStringJsonConverter()
            Decimal weightedAvgCost,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'latest_price')
            @DecimalStringJsonConverter()
            Decimal latestPrice,
            @JsonKey(name: 'market_value')
            @DecimalStringJsonConverter()
            Decimal marketValue,
            @JsonKey(name: 'unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal unrealizedPnl,
            @JsonKey(name: 'realized_pnl')
            @DecimalStringJsonConverter()
            Decimal realizedPnl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionDto() when $default != null:
        return $default(
            _that.assetId,
            _that.tickerSymbol,
            _that.quantity,
            _that.weightedAvgCost,
            _that.totalCostBasis,
            _that.latestPrice,
            _that.marketValue,
            _that.unrealizedPnl,
            _that.realizedPnl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PortfolioPositionDto implements PortfolioPositionDto {
  const _PortfolioPositionDto(
      {@JsonKey(name: 'asset_id') required this.assetId,
      @JsonKey(name: 'ticker_symbol') required this.tickerSymbol,
      @DecimalStringJsonConverter() required this.quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      required this.weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      required this.totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      required this.latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      required this.marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      required this.unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      required this.realizedPnl});
  factory _PortfolioPositionDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioPositionDtoFromJson(json);

  @override
  @JsonKey(name: 'asset_id')
  final String assetId;
  @override
  @JsonKey(name: 'ticker_symbol')
  final String tickerSymbol;
  @override
  @DecimalStringJsonConverter()
  final Decimal quantity;
  @override
  @JsonKey(name: 'weighted_avg_cost')
  @DecimalStringJsonConverter()
  final Decimal weightedAvgCost;
  @override
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  final Decimal totalCostBasis;
  @override
  @JsonKey(name: 'latest_price')
  @DecimalStringJsonConverter()
  final Decimal latestPrice;
  @override
  @JsonKey(name: 'market_value')
  @DecimalStringJsonConverter()
  final Decimal marketValue;
  @override
  @JsonKey(name: 'unrealized_pnl')
  @DecimalStringJsonConverter()
  final Decimal unrealizedPnl;
  @override
  @JsonKey(name: 'realized_pnl')
  @DecimalStringJsonConverter()
  final Decimal realizedPnl;

  /// Create a copy of PortfolioPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioPositionDtoCopyWith<_PortfolioPositionDto> get copyWith =>
      __$PortfolioPositionDtoCopyWithImpl<_PortfolioPositionDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PortfolioPositionDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioPositionDto &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.tickerSymbol, tickerSymbol) ||
                other.tickerSymbol == tickerSymbol) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.weightedAvgCost, weightedAvgCost) ||
                other.weightedAvgCost == weightedAvgCost) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.latestPrice, latestPrice) ||
                other.latestPrice == latestPrice) &&
            (identical(other.marketValue, marketValue) ||
                other.marketValue == marketValue) &&
            (identical(other.unrealizedPnl, unrealizedPnl) ||
                other.unrealizedPnl == unrealizedPnl) &&
            (identical(other.realizedPnl, realizedPnl) ||
                other.realizedPnl == realizedPnl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assetId,
      tickerSymbol,
      quantity,
      weightedAvgCost,
      totalCostBasis,
      latestPrice,
      marketValue,
      unrealizedPnl,
      realizedPnl);

  @override
  String toString() {
    return 'PortfolioPositionDto(assetId: $assetId, tickerSymbol: $tickerSymbol, quantity: $quantity, weightedAvgCost: $weightedAvgCost, totalCostBasis: $totalCostBasis, latestPrice: $latestPrice, marketValue: $marketValue, unrealizedPnl: $unrealizedPnl, realizedPnl: $realizedPnl)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioPositionDtoCopyWith<$Res>
    implements $PortfolioPositionDtoCopyWith<$Res> {
  factory _$PortfolioPositionDtoCopyWith(_PortfolioPositionDto value,
          $Res Function(_PortfolioPositionDto) _then) =
      __$PortfolioPositionDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'ticker_symbol') String tickerSymbol,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'weighted_avg_cost')
      @DecimalStringJsonConverter()
      Decimal weightedAvgCost,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'latest_price')
      @DecimalStringJsonConverter()
      Decimal latestPrice,
      @JsonKey(name: 'market_value')
      @DecimalStringJsonConverter()
      Decimal marketValue,
      @JsonKey(name: 'unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal unrealizedPnl,
      @JsonKey(name: 'realized_pnl')
      @DecimalStringJsonConverter()
      Decimal realizedPnl});
}

/// @nodoc
class __$PortfolioPositionDtoCopyWithImpl<$Res>
    implements _$PortfolioPositionDtoCopyWith<$Res> {
  __$PortfolioPositionDtoCopyWithImpl(this._self, this._then);

  final _PortfolioPositionDto _self;
  final $Res Function(_PortfolioPositionDto) _then;

  /// Create a copy of PortfolioPositionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? assetId = null,
    Object? tickerSymbol = null,
    Object? quantity = null,
    Object? weightedAvgCost = null,
    Object? totalCostBasis = null,
    Object? latestPrice = null,
    Object? marketValue = null,
    Object? unrealizedPnl = null,
    Object? realizedPnl = null,
  }) {
    return _then(_PortfolioPositionDto(
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      tickerSymbol: null == tickerSymbol
          ? _self.tickerSymbol
          : tickerSymbol // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      weightedAvgCost: null == weightedAvgCost
          ? _self.weightedAvgCost
          : weightedAvgCost // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      latestPrice: null == latestPrice
          ? _self.latestPrice
          : latestPrice // ignore: cast_nullable_to_non_nullable
              as Decimal,
      marketValue: null == marketValue
          ? _self.marketValue
          : marketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      unrealizedPnl: null == unrealizedPnl
          ? _self.unrealizedPnl
          : unrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      realizedPnl: null == realizedPnl
          ? _self.realizedPnl
          : realizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc
mixin _$PortfolioPositionsDto {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(name: 'total_market_value')
  @DecimalStringJsonConverter()
  Decimal get totalMarketValue;
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  Decimal get totalCostBasis;
  @JsonKey(name: 'total_unrealized_pnl')
  @DecimalStringJsonConverter()
  Decimal get totalUnrealizedPnl;
  @JsonKey(name: 'total_realized_pnl')
  @DecimalStringJsonConverter()
  Decimal get totalRealizedPnl;
  List<PortfolioPositionDto> get items;

  /// Create a copy of PortfolioPositionsDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioPositionsDtoCopyWith<PortfolioPositionsDto> get copyWith =>
      _$PortfolioPositionsDtoCopyWithImpl<PortfolioPositionsDto>(
          this as PortfolioPositionsDto, _$identity);

  /// Serializes this PortfolioPositionsDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioPositionsDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.totalMarketValue, totalMarketValue) ||
                other.totalMarketValue == totalMarketValue) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.totalUnrealizedPnl, totalUnrealizedPnl) ||
                other.totalUnrealizedPnl == totalUnrealizedPnl) &&
            (identical(other.totalRealizedPnl, totalRealizedPnl) ||
                other.totalRealizedPnl == totalRealizedPnl) &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      totalMarketValue,
      totalCostBasis,
      totalUnrealizedPnl,
      totalRealizedPnl,
      const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'PortfolioPositionsDto(portfolioId: $portfolioId, totalMarketValue: $totalMarketValue, totalCostBasis: $totalCostBasis, totalUnrealizedPnl: $totalUnrealizedPnl, totalRealizedPnl: $totalRealizedPnl, items: $items)';
  }
}

/// @nodoc
abstract mixin class $PortfolioPositionsDtoCopyWith<$Res> {
  factory $PortfolioPositionsDtoCopyWith(PortfolioPositionsDto value,
          $Res Function(PortfolioPositionsDto) _then) =
      _$PortfolioPositionsDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'total_market_value')
      @DecimalStringJsonConverter()
      Decimal totalMarketValue,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'total_unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal totalUnrealizedPnl,
      @JsonKey(name: 'total_realized_pnl')
      @DecimalStringJsonConverter()
      Decimal totalRealizedPnl,
      List<PortfolioPositionDto> items});
}

/// @nodoc
class _$PortfolioPositionsDtoCopyWithImpl<$Res>
    implements $PortfolioPositionsDtoCopyWith<$Res> {
  _$PortfolioPositionsDtoCopyWithImpl(this._self, this._then);

  final PortfolioPositionsDto _self;
  final $Res Function(PortfolioPositionsDto) _then;

  /// Create a copy of PortfolioPositionsDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? totalMarketValue = null,
    Object? totalCostBasis = null,
    Object? totalUnrealizedPnl = null,
    Object? totalRealizedPnl = null,
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      totalMarketValue: null == totalMarketValue
          ? _self.totalMarketValue
          : totalMarketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalUnrealizedPnl: null == totalUnrealizedPnl
          ? _self.totalUnrealizedPnl
          : totalUnrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalRealizedPnl: null == totalRealizedPnl
          ? _self.totalRealizedPnl
          : totalRealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<PortfolioPositionDto>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioPositionsDto].
extension PortfolioPositionsDtoPatterns on PortfolioPositionsDto {
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
    TResult Function(_PortfolioPositionsDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto() when $default != null:
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
    TResult Function(_PortfolioPositionsDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto():
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
    TResult? Function(_PortfolioPositionsDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto() when $default != null:
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'total_market_value')
            @DecimalStringJsonConverter()
            Decimal totalMarketValue,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'total_unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalUnrealizedPnl,
            @JsonKey(name: 'total_realized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalRealizedPnl,
            List<PortfolioPositionDto> items)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto() when $default != null:
        return $default(
            _that.portfolioId,
            _that.totalMarketValue,
            _that.totalCostBasis,
            _that.totalUnrealizedPnl,
            _that.totalRealizedPnl,
            _that.items);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'total_market_value')
            @DecimalStringJsonConverter()
            Decimal totalMarketValue,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'total_unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalUnrealizedPnl,
            @JsonKey(name: 'total_realized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalRealizedPnl,
            List<PortfolioPositionDto> items)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto():
        return $default(
            _that.portfolioId,
            _that.totalMarketValue,
            _that.totalCostBasis,
            _that.totalUnrealizedPnl,
            _that.totalRealizedPnl,
            _that.items);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'total_market_value')
            @DecimalStringJsonConverter()
            Decimal totalMarketValue,
            @JsonKey(name: 'total_cost_basis')
            @DecimalStringJsonConverter()
            Decimal totalCostBasis,
            @JsonKey(name: 'total_unrealized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalUnrealizedPnl,
            @JsonKey(name: 'total_realized_pnl')
            @DecimalStringJsonConverter()
            Decimal totalRealizedPnl,
            List<PortfolioPositionDto> items)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioPositionsDto() when $default != null:
        return $default(
            _that.portfolioId,
            _that.totalMarketValue,
            _that.totalCostBasis,
            _that.totalUnrealizedPnl,
            _that.totalRealizedPnl,
            _that.items);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PortfolioPositionsDto implements PortfolioPositionsDto {
  const _PortfolioPositionsDto(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(name: 'total_market_value')
      @DecimalStringJsonConverter()
      required this.totalMarketValue,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      required this.totalCostBasis,
      @JsonKey(name: 'total_unrealized_pnl')
      @DecimalStringJsonConverter()
      required this.totalUnrealizedPnl,
      @JsonKey(name: 'total_realized_pnl')
      @DecimalStringJsonConverter()
      required this.totalRealizedPnl,
      final List<PortfolioPositionDto> items = const <PortfolioPositionDto>[]})
      : _items = items;
  factory _PortfolioPositionsDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioPositionsDtoFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(name: 'total_market_value')
  @DecimalStringJsonConverter()
  final Decimal totalMarketValue;
  @override
  @JsonKey(name: 'total_cost_basis')
  @DecimalStringJsonConverter()
  final Decimal totalCostBasis;
  @override
  @JsonKey(name: 'total_unrealized_pnl')
  @DecimalStringJsonConverter()
  final Decimal totalUnrealizedPnl;
  @override
  @JsonKey(name: 'total_realized_pnl')
  @DecimalStringJsonConverter()
  final Decimal totalRealizedPnl;
  final List<PortfolioPositionDto> _items;
  @override
  @JsonKey()
  List<PortfolioPositionDto> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of PortfolioPositionsDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioPositionsDtoCopyWith<_PortfolioPositionsDto> get copyWith =>
      __$PortfolioPositionsDtoCopyWithImpl<_PortfolioPositionsDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PortfolioPositionsDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioPositionsDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.totalMarketValue, totalMarketValue) ||
                other.totalMarketValue == totalMarketValue) &&
            (identical(other.totalCostBasis, totalCostBasis) ||
                other.totalCostBasis == totalCostBasis) &&
            (identical(other.totalUnrealizedPnl, totalUnrealizedPnl) ||
                other.totalUnrealizedPnl == totalUnrealizedPnl) &&
            (identical(other.totalRealizedPnl, totalRealizedPnl) ||
                other.totalRealizedPnl == totalRealizedPnl) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      totalMarketValue,
      totalCostBasis,
      totalUnrealizedPnl,
      totalRealizedPnl,
      const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'PortfolioPositionsDto(portfolioId: $portfolioId, totalMarketValue: $totalMarketValue, totalCostBasis: $totalCostBasis, totalUnrealizedPnl: $totalUnrealizedPnl, totalRealizedPnl: $totalRealizedPnl, items: $items)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioPositionsDtoCopyWith<$Res>
    implements $PortfolioPositionsDtoCopyWith<$Res> {
  factory _$PortfolioPositionsDtoCopyWith(_PortfolioPositionsDto value,
          $Res Function(_PortfolioPositionsDto) _then) =
      __$PortfolioPositionsDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'total_market_value')
      @DecimalStringJsonConverter()
      Decimal totalMarketValue,
      @JsonKey(name: 'total_cost_basis')
      @DecimalStringJsonConverter()
      Decimal totalCostBasis,
      @JsonKey(name: 'total_unrealized_pnl')
      @DecimalStringJsonConverter()
      Decimal totalUnrealizedPnl,
      @JsonKey(name: 'total_realized_pnl')
      @DecimalStringJsonConverter()
      Decimal totalRealizedPnl,
      List<PortfolioPositionDto> items});
}

/// @nodoc
class __$PortfolioPositionsDtoCopyWithImpl<$Res>
    implements _$PortfolioPositionsDtoCopyWith<$Res> {
  __$PortfolioPositionsDtoCopyWithImpl(this._self, this._then);

  final _PortfolioPositionsDto _self;
  final $Res Function(_PortfolioPositionsDto) _then;

  /// Create a copy of PortfolioPositionsDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? totalMarketValue = null,
    Object? totalCostBasis = null,
    Object? totalUnrealizedPnl = null,
    Object? totalRealizedPnl = null,
    Object? items = null,
  }) {
    return _then(_PortfolioPositionsDto(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      totalMarketValue: null == totalMarketValue
          ? _self.totalMarketValue
          : totalMarketValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalCostBasis: null == totalCostBasis
          ? _self.totalCostBasis
          : totalCostBasis // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalUnrealizedPnl: null == totalUnrealizedPnl
          ? _self.totalUnrealizedPnl
          : totalUnrealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      totalRealizedPnl: null == totalRealizedPnl
          ? _self.totalRealizedPnl
          : totalRealizedPnl // ignore: cast_nullable_to_non_nullable
              as Decimal,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<PortfolioPositionDto>,
    ));
  }
}

/// @nodoc
mixin _$PortfolioTwrPointDto {
  DateTime get date;
  @JsonKey(name: 'portfolio_value')
  @DecimalStringJsonConverter()
  Decimal get portfolioValue;
  @JsonKey(name: 'net_cash_flow')
  @DecimalStringJsonConverter()
  Decimal get netCashFlow;
  @JsonKey(name: 'period_return')
  @DecimalStringJsonConverter()
  Decimal get periodReturn;
  @JsonKey(name: 'cumulative_twr')
  @DecimalStringJsonConverter()
  Decimal get cumulativeTwr;

  /// Create a copy of PortfolioTwrPointDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioTwrPointDtoCopyWith<PortfolioTwrPointDto> get copyWith =>
      _$PortfolioTwrPointDtoCopyWithImpl<PortfolioTwrPointDto>(
          this as PortfolioTwrPointDto, _$identity);

  /// Serializes this PortfolioTwrPointDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioTwrPointDto &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.portfolioValue, portfolioValue) ||
                other.portfolioValue == portfolioValue) &&
            (identical(other.netCashFlow, netCashFlow) ||
                other.netCashFlow == netCashFlow) &&
            (identical(other.periodReturn, periodReturn) ||
                other.periodReturn == periodReturn) &&
            (identical(other.cumulativeTwr, cumulativeTwr) ||
                other.cumulativeTwr == cumulativeTwr));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, portfolioValue,
      netCashFlow, periodReturn, cumulativeTwr);

  @override
  String toString() {
    return 'PortfolioTwrPointDto(date: $date, portfolioValue: $portfolioValue, netCashFlow: $netCashFlow, periodReturn: $periodReturn, cumulativeTwr: $cumulativeTwr)';
  }
}

/// @nodoc
abstract mixin class $PortfolioTwrPointDtoCopyWith<$Res> {
  factory $PortfolioTwrPointDtoCopyWith(PortfolioTwrPointDto value,
          $Res Function(PortfolioTwrPointDto) _then) =
      _$PortfolioTwrPointDtoCopyWithImpl;
  @useResult
  $Res call(
      {DateTime date,
      @JsonKey(name: 'portfolio_value')
      @DecimalStringJsonConverter()
      Decimal portfolioValue,
      @JsonKey(name: 'net_cash_flow')
      @DecimalStringJsonConverter()
      Decimal netCashFlow,
      @JsonKey(name: 'period_return')
      @DecimalStringJsonConverter()
      Decimal periodReturn,
      @JsonKey(name: 'cumulative_twr')
      @DecimalStringJsonConverter()
      Decimal cumulativeTwr});
}

/// @nodoc
class _$PortfolioTwrPointDtoCopyWithImpl<$Res>
    implements $PortfolioTwrPointDtoCopyWith<$Res> {
  _$PortfolioTwrPointDtoCopyWithImpl(this._self, this._then);

  final PortfolioTwrPointDto _self;
  final $Res Function(PortfolioTwrPointDto) _then;

  /// Create a copy of PortfolioTwrPointDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? portfolioValue = null,
    Object? netCashFlow = null,
    Object? periodReturn = null,
    Object? cumulativeTwr = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      portfolioValue: null == portfolioValue
          ? _self.portfolioValue
          : portfolioValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      netCashFlow: null == netCashFlow
          ? _self.netCashFlow
          : netCashFlow // ignore: cast_nullable_to_non_nullable
              as Decimal,
      periodReturn: null == periodReturn
          ? _self.periodReturn
          : periodReturn // ignore: cast_nullable_to_non_nullable
              as Decimal,
      cumulativeTwr: null == cumulativeTwr
          ? _self.cumulativeTwr
          : cumulativeTwr // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioTwrPointDto].
extension PortfolioTwrPointDtoPatterns on PortfolioTwrPointDto {
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
    TResult Function(_PortfolioTwrPointDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto() when $default != null:
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
    TResult Function(_PortfolioTwrPointDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto():
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
    TResult? Function(_PortfolioTwrPointDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto() when $default != null:
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
            DateTime date,
            @JsonKey(name: 'portfolio_value')
            @DecimalStringJsonConverter()
            Decimal portfolioValue,
            @JsonKey(name: 'net_cash_flow')
            @DecimalStringJsonConverter()
            Decimal netCashFlow,
            @JsonKey(name: 'period_return')
            @DecimalStringJsonConverter()
            Decimal periodReturn,
            @JsonKey(name: 'cumulative_twr')
            @DecimalStringJsonConverter()
            Decimal cumulativeTwr)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto() when $default != null:
        return $default(_that.date, _that.portfolioValue, _that.netCashFlow,
            _that.periodReturn, _that.cumulativeTwr);
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
            DateTime date,
            @JsonKey(name: 'portfolio_value')
            @DecimalStringJsonConverter()
            Decimal portfolioValue,
            @JsonKey(name: 'net_cash_flow')
            @DecimalStringJsonConverter()
            Decimal netCashFlow,
            @JsonKey(name: 'period_return')
            @DecimalStringJsonConverter()
            Decimal periodReturn,
            @JsonKey(name: 'cumulative_twr')
            @DecimalStringJsonConverter()
            Decimal cumulativeTwr)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto():
        return $default(_that.date, _that.portfolioValue, _that.netCashFlow,
            _that.periodReturn, _that.cumulativeTwr);
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
            DateTime date,
            @JsonKey(name: 'portfolio_value')
            @DecimalStringJsonConverter()
            Decimal portfolioValue,
            @JsonKey(name: 'net_cash_flow')
            @DecimalStringJsonConverter()
            Decimal netCashFlow,
            @JsonKey(name: 'period_return')
            @DecimalStringJsonConverter()
            Decimal periodReturn,
            @JsonKey(name: 'cumulative_twr')
            @DecimalStringJsonConverter()
            Decimal cumulativeTwr)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrPointDto() when $default != null:
        return $default(_that.date, _that.portfolioValue, _that.netCashFlow,
            _that.periodReturn, _that.cumulativeTwr);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PortfolioTwrPointDto implements PortfolioTwrPointDto {
  const _PortfolioTwrPointDto(
      {required this.date,
      @JsonKey(name: 'portfolio_value')
      @DecimalStringJsonConverter()
      required this.portfolioValue,
      @JsonKey(name: 'net_cash_flow')
      @DecimalStringJsonConverter()
      required this.netCashFlow,
      @JsonKey(name: 'period_return')
      @DecimalStringJsonConverter()
      required this.periodReturn,
      @JsonKey(name: 'cumulative_twr')
      @DecimalStringJsonConverter()
      required this.cumulativeTwr});
  factory _PortfolioTwrPointDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioTwrPointDtoFromJson(json);

  @override
  final DateTime date;
  @override
  @JsonKey(name: 'portfolio_value')
  @DecimalStringJsonConverter()
  final Decimal portfolioValue;
  @override
  @JsonKey(name: 'net_cash_flow')
  @DecimalStringJsonConverter()
  final Decimal netCashFlow;
  @override
  @JsonKey(name: 'period_return')
  @DecimalStringJsonConverter()
  final Decimal periodReturn;
  @override
  @JsonKey(name: 'cumulative_twr')
  @DecimalStringJsonConverter()
  final Decimal cumulativeTwr;

  /// Create a copy of PortfolioTwrPointDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioTwrPointDtoCopyWith<_PortfolioTwrPointDto> get copyWith =>
      __$PortfolioTwrPointDtoCopyWithImpl<_PortfolioTwrPointDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PortfolioTwrPointDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioTwrPointDto &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.portfolioValue, portfolioValue) ||
                other.portfolioValue == portfolioValue) &&
            (identical(other.netCashFlow, netCashFlow) ||
                other.netCashFlow == netCashFlow) &&
            (identical(other.periodReturn, periodReturn) ||
                other.periodReturn == periodReturn) &&
            (identical(other.cumulativeTwr, cumulativeTwr) ||
                other.cumulativeTwr == cumulativeTwr));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, portfolioValue,
      netCashFlow, periodReturn, cumulativeTwr);

  @override
  String toString() {
    return 'PortfolioTwrPointDto(date: $date, portfolioValue: $portfolioValue, netCashFlow: $netCashFlow, periodReturn: $periodReturn, cumulativeTwr: $cumulativeTwr)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioTwrPointDtoCopyWith<$Res>
    implements $PortfolioTwrPointDtoCopyWith<$Res> {
  factory _$PortfolioTwrPointDtoCopyWith(_PortfolioTwrPointDto value,
          $Res Function(_PortfolioTwrPointDto) _then) =
      __$PortfolioTwrPointDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime date,
      @JsonKey(name: 'portfolio_value')
      @DecimalStringJsonConverter()
      Decimal portfolioValue,
      @JsonKey(name: 'net_cash_flow')
      @DecimalStringJsonConverter()
      Decimal netCashFlow,
      @JsonKey(name: 'period_return')
      @DecimalStringJsonConverter()
      Decimal periodReturn,
      @JsonKey(name: 'cumulative_twr')
      @DecimalStringJsonConverter()
      Decimal cumulativeTwr});
}

/// @nodoc
class __$PortfolioTwrPointDtoCopyWithImpl<$Res>
    implements _$PortfolioTwrPointDtoCopyWith<$Res> {
  __$PortfolioTwrPointDtoCopyWithImpl(this._self, this._then);

  final _PortfolioTwrPointDto _self;
  final $Res Function(_PortfolioTwrPointDto) _then;

  /// Create a copy of PortfolioTwrPointDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? portfolioValue = null,
    Object? netCashFlow = null,
    Object? periodReturn = null,
    Object? cumulativeTwr = null,
  }) {
    return _then(_PortfolioTwrPointDto(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      portfolioValue: null == portfolioValue
          ? _self.portfolioValue
          : portfolioValue // ignore: cast_nullable_to_non_nullable
              as Decimal,
      netCashFlow: null == netCashFlow
          ? _self.netCashFlow
          : netCashFlow // ignore: cast_nullable_to_non_nullable
              as Decimal,
      periodReturn: null == periodReturn
          ? _self.periodReturn
          : periodReturn // ignore: cast_nullable_to_non_nullable
              as Decimal,
      cumulativeTwr: null == cumulativeTwr
          ? _self.cumulativeTwr
          : cumulativeTwr // ignore: cast_nullable_to_non_nullable
              as Decimal,
    ));
  }
}

/// @nodoc
mixin _$PortfolioTwrDto {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @JsonKey(name: 'end_date')
  DateTime get endDate;
  List<PortfolioTwrPointDto> get points;

  /// Create a copy of PortfolioTwrDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PortfolioTwrDtoCopyWith<PortfolioTwrDto> get copyWith =>
      _$PortfolioTwrDtoCopyWithImpl<PortfolioTwrDto>(
          this as PortfolioTwrDto, _$identity);

  /// Serializes this PortfolioTwrDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PortfolioTwrDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality().equals(other.points, points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, startDate, endDate,
      const DeepCollectionEquality().hash(points));

  @override
  String toString() {
    return 'PortfolioTwrDto(portfolioId: $portfolioId, startDate: $startDate, endDate: $endDate, points: $points)';
  }
}

/// @nodoc
abstract mixin class $PortfolioTwrDtoCopyWith<$Res> {
  factory $PortfolioTwrDtoCopyWith(
          PortfolioTwrDto value, $Res Function(PortfolioTwrDto) _then) =
      _$PortfolioTwrDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime endDate,
      List<PortfolioTwrPointDto> points});
}

/// @nodoc
class _$PortfolioTwrDtoCopyWithImpl<$Res>
    implements $PortfolioTwrDtoCopyWith<$Res> {
  _$PortfolioTwrDtoCopyWithImpl(this._self, this._then);

  final PortfolioTwrDto _self;
  final $Res Function(PortfolioTwrDto) _then;

  /// Create a copy of PortfolioTwrDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? points = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      points: null == points
          ? _self.points
          : points // ignore: cast_nullable_to_non_nullable
              as List<PortfolioTwrPointDto>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PortfolioTwrDto].
extension PortfolioTwrDtoPatterns on PortfolioTwrDto {
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
    TResult Function(_PortfolioTwrDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto() when $default != null:
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
    TResult Function(_PortfolioTwrDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto():
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
    TResult? Function(_PortfolioTwrDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto() when $default != null:
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'start_date') DateTime startDate,
            @JsonKey(name: 'end_date') DateTime endDate,
            List<PortfolioTwrPointDto> points)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto() when $default != null:
        return $default(
            _that.portfolioId, _that.startDate, _that.endDate, _that.points);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'start_date') DateTime startDate,
            @JsonKey(name: 'end_date') DateTime endDate,
            List<PortfolioTwrPointDto> points)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto():
        return $default(
            _that.portfolioId, _that.startDate, _that.endDate, _that.points);
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
            @JsonKey(name: 'portfolio_id') String portfolioId,
            @JsonKey(name: 'start_date') DateTime startDate,
            @JsonKey(name: 'end_date') DateTime endDate,
            List<PortfolioTwrPointDto> points)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PortfolioTwrDto() when $default != null:
        return $default(
            _that.portfolioId, _that.startDate, _that.endDate, _that.points);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PortfolioTwrDto implements PortfolioTwrDto {
  const _PortfolioTwrDto(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') required this.endDate,
      final List<PortfolioTwrPointDto> points = const <PortfolioTwrPointDto>[]})
      : _points = points;
  factory _PortfolioTwrDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioTwrDtoFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime endDate;
  final List<PortfolioTwrPointDto> _points;
  @override
  @JsonKey()
  List<PortfolioTwrPointDto> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  /// Create a copy of PortfolioTwrDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PortfolioTwrDtoCopyWith<_PortfolioTwrDto> get copyWith =>
      __$PortfolioTwrDtoCopyWithImpl<_PortfolioTwrDto>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PortfolioTwrDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PortfolioTwrDto &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality().equals(other._points, _points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, startDate, endDate,
      const DeepCollectionEquality().hash(_points));

  @override
  String toString() {
    return 'PortfolioTwrDto(portfolioId: $portfolioId, startDate: $startDate, endDate: $endDate, points: $points)';
  }
}

/// @nodoc
abstract mixin class _$PortfolioTwrDtoCopyWith<$Res>
    implements $PortfolioTwrDtoCopyWith<$Res> {
  factory _$PortfolioTwrDtoCopyWith(
          _PortfolioTwrDto value, $Res Function(_PortfolioTwrDto) _then) =
      __$PortfolioTwrDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime endDate,
      List<PortfolioTwrPointDto> points});
}

/// @nodoc
class __$PortfolioTwrDtoCopyWithImpl<$Res>
    implements _$PortfolioTwrDtoCopyWith<$Res> {
  __$PortfolioTwrDtoCopyWithImpl(this._self, this._then);

  final _PortfolioTwrDto _self;
  final $Res Function(_PortfolioTwrDto) _then;

  /// Create a copy of PortfolioTwrDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? points = null,
  }) {
    return _then(_PortfolioTwrDto(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      points: null == points
          ? _self._points
          : points // ignore: cast_nullable_to_non_nullable
              as List<PortfolioTwrPointDto>,
    ));
  }
}

/// @nodoc
mixin _$TransactionCreateDto {
  @JsonKey(name: 'asset_id')
  String get assetId;
  @JsonKey(name: 'transaction_type')
  String get transactionType;
  @DecimalStringJsonConverter()
  Decimal get quantity;
  @JsonKey(name: 'price_per_unit')
  @DecimalStringJsonConverter()
  Decimal? get pricePerUnit;
  @DecimalStringJsonConverter()
  Decimal? get fees;
  @JsonKey(name: 'dividend_per_unit')
  @DecimalStringJsonConverter()
  Decimal? get dividendPerUnit;
  @JsonKey(name: 'bonus_ratio')
  @DecimalStringJsonConverter()
  Decimal? get bonusRatio;
  @JsonKey(name: 'split_from')
  int? get splitFrom;
  @JsonKey(name: 'split_to')
  int? get splitTo;
  @JsonKey(name: 'rights_ratio')
  @DecimalStringJsonConverter()
  Decimal? get rightsRatio;
  @JsonKey(name: 'subscription_price')
  @DecimalStringJsonConverter()
  Decimal? get subscriptionPrice;
  String? get notes;
  @JsonKey(name: 'executed_at')
  DateTime get executedAt;

  /// Create a copy of TransactionCreateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TransactionCreateDtoCopyWith<TransactionCreateDto> get copyWith =>
      _$TransactionCreateDtoCopyWithImpl<TransactionCreateDto>(
          this as TransactionCreateDto, _$identity);

  /// Serializes this TransactionCreateDto to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TransactionCreateDto &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.pricePerUnit, pricePerUnit) ||
                other.pricePerUnit == pricePerUnit) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.dividendPerUnit, dividendPerUnit) ||
                other.dividendPerUnit == dividendPerUnit) &&
            (identical(other.bonusRatio, bonusRatio) ||
                other.bonusRatio == bonusRatio) &&
            (identical(other.splitFrom, splitFrom) ||
                other.splitFrom == splitFrom) &&
            (identical(other.splitTo, splitTo) || other.splitTo == splitTo) &&
            (identical(other.rightsRatio, rightsRatio) ||
                other.rightsRatio == rightsRatio) &&
            (identical(other.subscriptionPrice, subscriptionPrice) ||
                other.subscriptionPrice == subscriptionPrice) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assetId,
      transactionType,
      quantity,
      pricePerUnit,
      fees,
      dividendPerUnit,
      bonusRatio,
      splitFrom,
      splitTo,
      rightsRatio,
      subscriptionPrice,
      notes,
      executedAt);

  @override
  String toString() {
    return 'TransactionCreateDto(assetId: $assetId, transactionType: $transactionType, quantity: $quantity, pricePerUnit: $pricePerUnit, fees: $fees, dividendPerUnit: $dividendPerUnit, bonusRatio: $bonusRatio, splitFrom: $splitFrom, splitTo: $splitTo, rightsRatio: $rightsRatio, subscriptionPrice: $subscriptionPrice, notes: $notes, executedAt: $executedAt)';
  }
}

/// @nodoc
abstract mixin class $TransactionCreateDtoCopyWith<$Res> {
  factory $TransactionCreateDtoCopyWith(TransactionCreateDto value,
          $Res Function(TransactionCreateDto) _then) =
      _$TransactionCreateDtoCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'transaction_type') String transactionType,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      Decimal? pricePerUnit,
      @DecimalStringJsonConverter() Decimal? fees,
      @JsonKey(name: 'dividend_per_unit')
      @DecimalStringJsonConverter()
      Decimal? dividendPerUnit,
      @JsonKey(name: 'bonus_ratio')
      @DecimalStringJsonConverter()
      Decimal? bonusRatio,
      @JsonKey(name: 'split_from') int? splitFrom,
      @JsonKey(name: 'split_to') int? splitTo,
      @JsonKey(name: 'rights_ratio')
      @DecimalStringJsonConverter()
      Decimal? rightsRatio,
      @JsonKey(name: 'subscription_price')
      @DecimalStringJsonConverter()
      Decimal? subscriptionPrice,
      String? notes,
      @JsonKey(name: 'executed_at') DateTime executedAt});
}

/// @nodoc
class _$TransactionCreateDtoCopyWithImpl<$Res>
    implements $TransactionCreateDtoCopyWith<$Res> {
  _$TransactionCreateDtoCopyWithImpl(this._self, this._then);

  final TransactionCreateDto _self;
  final $Res Function(TransactionCreateDto) _then;

  /// Create a copy of TransactionCreateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? assetId = null,
    Object? transactionType = null,
    Object? quantity = null,
    Object? pricePerUnit = freezed,
    Object? fees = freezed,
    Object? dividendPerUnit = freezed,
    Object? bonusRatio = freezed,
    Object? splitFrom = freezed,
    Object? splitTo = freezed,
    Object? rightsRatio = freezed,
    Object? subscriptionPrice = freezed,
    Object? notes = freezed,
    Object? executedAt = null,
  }) {
    return _then(_self.copyWith(
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      transactionType: null == transactionType
          ? _self.transactionType
          : transactionType // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      pricePerUnit: freezed == pricePerUnit
          ? _self.pricePerUnit
          : pricePerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      fees: freezed == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      dividendPerUnit: freezed == dividendPerUnit
          ? _self.dividendPerUnit
          : dividendPerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      bonusRatio: freezed == bonusRatio
          ? _self.bonusRatio
          : bonusRatio // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      splitFrom: freezed == splitFrom
          ? _self.splitFrom
          : splitFrom // ignore: cast_nullable_to_non_nullable
              as int?,
      splitTo: freezed == splitTo
          ? _self.splitTo
          : splitTo // ignore: cast_nullable_to_non_nullable
              as int?,
      rightsRatio: freezed == rightsRatio
          ? _self.rightsRatio
          : rightsRatio // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      subscriptionPrice: freezed == subscriptionPrice
          ? _self.subscriptionPrice
          : subscriptionPrice // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      executedAt: null == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [TransactionCreateDto].
extension TransactionCreateDtoPatterns on TransactionCreateDto {
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
    TResult Function(_TransactionCreateDto value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto() when $default != null:
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
    TResult Function(_TransactionCreateDto value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto():
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
    TResult? Function(_TransactionCreateDto value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto() when $default != null:
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal? pricePerUnit,
            @DecimalStringJsonConverter() Decimal? fees,
            @JsonKey(name: 'dividend_per_unit')
            @DecimalStringJsonConverter()
            Decimal? dividendPerUnit,
            @JsonKey(name: 'bonus_ratio')
            @DecimalStringJsonConverter()
            Decimal? bonusRatio,
            @JsonKey(name: 'split_from') int? splitFrom,
            @JsonKey(name: 'split_to') int? splitTo,
            @JsonKey(name: 'rights_ratio')
            @DecimalStringJsonConverter()
            Decimal? rightsRatio,
            @JsonKey(name: 'subscription_price')
            @DecimalStringJsonConverter()
            Decimal? subscriptionPrice,
            String? notes,
            @JsonKey(name: 'executed_at') DateTime executedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto() when $default != null:
        return $default(
            _that.assetId,
            _that.transactionType,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.dividendPerUnit,
            _that.bonusRatio,
            _that.splitFrom,
            _that.splitTo,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.notes,
            _that.executedAt);
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal? pricePerUnit,
            @DecimalStringJsonConverter() Decimal? fees,
            @JsonKey(name: 'dividend_per_unit')
            @DecimalStringJsonConverter()
            Decimal? dividendPerUnit,
            @JsonKey(name: 'bonus_ratio')
            @DecimalStringJsonConverter()
            Decimal? bonusRatio,
            @JsonKey(name: 'split_from') int? splitFrom,
            @JsonKey(name: 'split_to') int? splitTo,
            @JsonKey(name: 'rights_ratio')
            @DecimalStringJsonConverter()
            Decimal? rightsRatio,
            @JsonKey(name: 'subscription_price')
            @DecimalStringJsonConverter()
            Decimal? subscriptionPrice,
            String? notes,
            @JsonKey(name: 'executed_at') DateTime executedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto():
        return $default(
            _that.assetId,
            _that.transactionType,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.dividendPerUnit,
            _that.bonusRatio,
            _that.splitFrom,
            _that.splitTo,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.notes,
            _that.executedAt);
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
            @JsonKey(name: 'asset_id') String assetId,
            @JsonKey(name: 'transaction_type') String transactionType,
            @DecimalStringJsonConverter() Decimal quantity,
            @JsonKey(name: 'price_per_unit')
            @DecimalStringJsonConverter()
            Decimal? pricePerUnit,
            @DecimalStringJsonConverter() Decimal? fees,
            @JsonKey(name: 'dividend_per_unit')
            @DecimalStringJsonConverter()
            Decimal? dividendPerUnit,
            @JsonKey(name: 'bonus_ratio')
            @DecimalStringJsonConverter()
            Decimal? bonusRatio,
            @JsonKey(name: 'split_from') int? splitFrom,
            @JsonKey(name: 'split_to') int? splitTo,
            @JsonKey(name: 'rights_ratio')
            @DecimalStringJsonConverter()
            Decimal? rightsRatio,
            @JsonKey(name: 'subscription_price')
            @DecimalStringJsonConverter()
            Decimal? subscriptionPrice,
            String? notes,
            @JsonKey(name: 'executed_at') DateTime executedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionCreateDto() when $default != null:
        return $default(
            _that.assetId,
            _that.transactionType,
            _that.quantity,
            _that.pricePerUnit,
            _that.fees,
            _that.dividendPerUnit,
            _that.bonusRatio,
            _that.splitFrom,
            _that.splitTo,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.notes,
            _that.executedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TransactionCreateDto implements TransactionCreateDto {
  const _TransactionCreateDto(
      {@JsonKey(name: 'asset_id') required this.assetId,
      @JsonKey(name: 'transaction_type') required this.transactionType,
      @DecimalStringJsonConverter() required this.quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      this.pricePerUnit,
      @DecimalStringJsonConverter() this.fees,
      @JsonKey(name: 'dividend_per_unit')
      @DecimalStringJsonConverter()
      this.dividendPerUnit,
      @JsonKey(name: 'bonus_ratio')
      @DecimalStringJsonConverter()
      this.bonusRatio,
      @JsonKey(name: 'split_from') this.splitFrom,
      @JsonKey(name: 'split_to') this.splitTo,
      @JsonKey(name: 'rights_ratio')
      @DecimalStringJsonConverter()
      this.rightsRatio,
      @JsonKey(name: 'subscription_price')
      @DecimalStringJsonConverter()
      this.subscriptionPrice,
      this.notes,
      @JsonKey(name: 'executed_at') required this.executedAt});
  factory _TransactionCreateDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionCreateDtoFromJson(json);

  @override
  @JsonKey(name: 'asset_id')
  final String assetId;
  @override
  @JsonKey(name: 'transaction_type')
  final String transactionType;
  @override
  @DecimalStringJsonConverter()
  final Decimal quantity;
  @override
  @JsonKey(name: 'price_per_unit')
  @DecimalStringJsonConverter()
  final Decimal? pricePerUnit;
  @override
  @DecimalStringJsonConverter()
  final Decimal? fees;
  @override
  @JsonKey(name: 'dividend_per_unit')
  @DecimalStringJsonConverter()
  final Decimal? dividendPerUnit;
  @override
  @JsonKey(name: 'bonus_ratio')
  @DecimalStringJsonConverter()
  final Decimal? bonusRatio;
  @override
  @JsonKey(name: 'split_from')
  final int? splitFrom;
  @override
  @JsonKey(name: 'split_to')
  final int? splitTo;
  @override
  @JsonKey(name: 'rights_ratio')
  @DecimalStringJsonConverter()
  final Decimal? rightsRatio;
  @override
  @JsonKey(name: 'subscription_price')
  @DecimalStringJsonConverter()
  final Decimal? subscriptionPrice;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'executed_at')
  final DateTime executedAt;

  /// Create a copy of TransactionCreateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TransactionCreateDtoCopyWith<_TransactionCreateDto> get copyWith =>
      __$TransactionCreateDtoCopyWithImpl<_TransactionCreateDto>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TransactionCreateDtoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TransactionCreateDto &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.pricePerUnit, pricePerUnit) ||
                other.pricePerUnit == pricePerUnit) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.dividendPerUnit, dividendPerUnit) ||
                other.dividendPerUnit == dividendPerUnit) &&
            (identical(other.bonusRatio, bonusRatio) ||
                other.bonusRatio == bonusRatio) &&
            (identical(other.splitFrom, splitFrom) ||
                other.splitFrom == splitFrom) &&
            (identical(other.splitTo, splitTo) || other.splitTo == splitTo) &&
            (identical(other.rightsRatio, rightsRatio) ||
                other.rightsRatio == rightsRatio) &&
            (identical(other.subscriptionPrice, subscriptionPrice) ||
                other.subscriptionPrice == subscriptionPrice) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      assetId,
      transactionType,
      quantity,
      pricePerUnit,
      fees,
      dividendPerUnit,
      bonusRatio,
      splitFrom,
      splitTo,
      rightsRatio,
      subscriptionPrice,
      notes,
      executedAt);

  @override
  String toString() {
    return 'TransactionCreateDto(assetId: $assetId, transactionType: $transactionType, quantity: $quantity, pricePerUnit: $pricePerUnit, fees: $fees, dividendPerUnit: $dividendPerUnit, bonusRatio: $bonusRatio, splitFrom: $splitFrom, splitTo: $splitTo, rightsRatio: $rightsRatio, subscriptionPrice: $subscriptionPrice, notes: $notes, executedAt: $executedAt)';
  }
}

/// @nodoc
abstract mixin class _$TransactionCreateDtoCopyWith<$Res>
    implements $TransactionCreateDtoCopyWith<$Res> {
  factory _$TransactionCreateDtoCopyWith(_TransactionCreateDto value,
          $Res Function(_TransactionCreateDto) _then) =
      __$TransactionCreateDtoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'asset_id') String assetId,
      @JsonKey(name: 'transaction_type') String transactionType,
      @DecimalStringJsonConverter() Decimal quantity,
      @JsonKey(name: 'price_per_unit')
      @DecimalStringJsonConverter()
      Decimal? pricePerUnit,
      @DecimalStringJsonConverter() Decimal? fees,
      @JsonKey(name: 'dividend_per_unit')
      @DecimalStringJsonConverter()
      Decimal? dividendPerUnit,
      @JsonKey(name: 'bonus_ratio')
      @DecimalStringJsonConverter()
      Decimal? bonusRatio,
      @JsonKey(name: 'split_from') int? splitFrom,
      @JsonKey(name: 'split_to') int? splitTo,
      @JsonKey(name: 'rights_ratio')
      @DecimalStringJsonConverter()
      Decimal? rightsRatio,
      @JsonKey(name: 'subscription_price')
      @DecimalStringJsonConverter()
      Decimal? subscriptionPrice,
      String? notes,
      @JsonKey(name: 'executed_at') DateTime executedAt});
}

/// @nodoc
class __$TransactionCreateDtoCopyWithImpl<$Res>
    implements _$TransactionCreateDtoCopyWith<$Res> {
  __$TransactionCreateDtoCopyWithImpl(this._self, this._then);

  final _TransactionCreateDto _self;
  final $Res Function(_TransactionCreateDto) _then;

  /// Create a copy of TransactionCreateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? assetId = null,
    Object? transactionType = null,
    Object? quantity = null,
    Object? pricePerUnit = freezed,
    Object? fees = freezed,
    Object? dividendPerUnit = freezed,
    Object? bonusRatio = freezed,
    Object? splitFrom = freezed,
    Object? splitTo = freezed,
    Object? rightsRatio = freezed,
    Object? subscriptionPrice = freezed,
    Object? notes = freezed,
    Object? executedAt = null,
  }) {
    return _then(_TransactionCreateDto(
      assetId: null == assetId
          ? _self.assetId
          : assetId // ignore: cast_nullable_to_non_nullable
              as String,
      transactionType: null == transactionType
          ? _self.transactionType
          : transactionType // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      pricePerUnit: freezed == pricePerUnit
          ? _self.pricePerUnit
          : pricePerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      fees: freezed == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      dividendPerUnit: freezed == dividendPerUnit
          ? _self.dividendPerUnit
          : dividendPerUnit // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      bonusRatio: freezed == bonusRatio
          ? _self.bonusRatio
          : bonusRatio // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      splitFrom: freezed == splitFrom
          ? _self.splitFrom
          : splitFrom // ignore: cast_nullable_to_non_nullable
              as int?,
      splitTo: freezed == splitTo
          ? _self.splitTo
          : splitTo // ignore: cast_nullable_to_non_nullable
              as int?,
      rightsRatio: freezed == rightsRatio
          ? _self.rightsRatio
          : rightsRatio // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      subscriptionPrice: freezed == subscriptionPrice
          ? _self.subscriptionPrice
          : subscriptionPrice // ignore: cast_nullable_to_non_nullable
              as Decimal?,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      executedAt: null == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
