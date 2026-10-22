// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trade_ticket.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TradeTicket {
  TradeSide get side;
  String get symbol;
  String get portfolioId;
  int get quantity; // Tehran market: integer shares only
  double get price;
  double get fees;
  String? get notes;
  DateTime? get executedAt;

  /// Create a copy of TradeTicket
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TradeTicketCopyWith<TradeTicket> get copyWith =>
      _$TradeTicketCopyWithImpl<TradeTicket>(this as TradeTicket, _$identity);

  /// Serializes this TradeTicket to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TradeTicket &&
            (identical(other.side, side) || other.side == side) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, side, symbol, portfolioId,
      quantity, price, fees, notes, executedAt);

  @override
  String toString() {
    return 'TradeTicket(side: $side, symbol: $symbol, portfolioId: $portfolioId, quantity: $quantity, price: $price, fees: $fees, notes: $notes, executedAt: $executedAt)';
  }
}

/// @nodoc
abstract mixin class $TradeTicketCopyWith<$Res> {
  factory $TradeTicketCopyWith(
          TradeTicket value, $Res Function(TradeTicket) _then) =
      _$TradeTicketCopyWithImpl;
  @useResult
  $Res call(
      {TradeSide side,
      String symbol,
      String portfolioId,
      int quantity,
      double price,
      double fees,
      String? notes,
      DateTime? executedAt});
}

/// @nodoc
class _$TradeTicketCopyWithImpl<$Res> implements $TradeTicketCopyWith<$Res> {
  _$TradeTicketCopyWithImpl(this._self, this._then);

  final TradeTicket _self;
  final $Res Function(TradeTicket) _then;

  /// Create a copy of TradeTicket
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? side = null,
    Object? symbol = null,
    Object? portfolioId = null,
    Object? quantity = null,
    Object? price = null,
    Object? fees = null,
    Object? notes = freezed,
    Object? executedAt = freezed,
  }) {
    return _then(_self.copyWith(
      side: null == side
          ? _self.side
          : side // ignore: cast_nullable_to_non_nullable
              as TradeSide,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      fees: null == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as double,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      executedAt: freezed == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TradeTicket].
extension TradeTicketPatterns on TradeTicket {
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
    TResult Function(_TradeTicket value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TradeTicket() when $default != null:
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
    TResult Function(_TradeTicket value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TradeTicket():
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
    TResult? Function(_TradeTicket value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TradeTicket() when $default != null:
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
            TradeSide side,
            String symbol,
            String portfolioId,
            int quantity,
            double price,
            double fees,
            String? notes,
            DateTime? executedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TradeTicket() when $default != null:
        return $default(
            _that.side,
            _that.symbol,
            _that.portfolioId,
            _that.quantity,
            _that.price,
            _that.fees,
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
            TradeSide side,
            String symbol,
            String portfolioId,
            int quantity,
            double price,
            double fees,
            String? notes,
            DateTime? executedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TradeTicket():
        return $default(
            _that.side,
            _that.symbol,
            _that.portfolioId,
            _that.quantity,
            _that.price,
            _that.fees,
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
            TradeSide side,
            String symbol,
            String portfolioId,
            int quantity,
            double price,
            double fees,
            String? notes,
            DateTime? executedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TradeTicket() when $default != null:
        return $default(
            _that.side,
            _that.symbol,
            _that.portfolioId,
            _that.quantity,
            _that.price,
            _that.fees,
            _that.notes,
            _that.executedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TradeTicket implements TradeTicket {
  const _TradeTicket(
      {required this.side,
      required this.symbol,
      required this.portfolioId,
      required this.quantity,
      required this.price,
      this.fees = 0,
      this.notes,
      this.executedAt});
  factory _TradeTicket.fromJson(Map<String, dynamic> json) =>
      _$TradeTicketFromJson(json);

  @override
  final TradeSide side;
  @override
  final String symbol;
  @override
  final String portfolioId;
  @override
  final int quantity;
// Tehran market: integer shares only
  @override
  final double price;
  @override
  @JsonKey()
  final double fees;
  @override
  final String? notes;
  @override
  final DateTime? executedAt;

  /// Create a copy of TradeTicket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TradeTicketCopyWith<_TradeTicket> get copyWith =>
      __$TradeTicketCopyWithImpl<_TradeTicket>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TradeTicketToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TradeTicket &&
            (identical(other.side, side) || other.side == side) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, side, symbol, portfolioId,
      quantity, price, fees, notes, executedAt);

  @override
  String toString() {
    return 'TradeTicket(side: $side, symbol: $symbol, portfolioId: $portfolioId, quantity: $quantity, price: $price, fees: $fees, notes: $notes, executedAt: $executedAt)';
  }
}

/// @nodoc
abstract mixin class _$TradeTicketCopyWith<$Res>
    implements $TradeTicketCopyWith<$Res> {
  factory _$TradeTicketCopyWith(
          _TradeTicket value, $Res Function(_TradeTicket) _then) =
      __$TradeTicketCopyWithImpl;
  @override
  @useResult
  $Res call(
      {TradeSide side,
      String symbol,
      String portfolioId,
      int quantity,
      double price,
      double fees,
      String? notes,
      DateTime? executedAt});
}

/// @nodoc
class __$TradeTicketCopyWithImpl<$Res> implements _$TradeTicketCopyWith<$Res> {
  __$TradeTicketCopyWithImpl(this._self, this._then);

  final _TradeTicket _self;
  final $Res Function(_TradeTicket) _then;

  /// Create a copy of TradeTicket
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? side = null,
    Object? symbol = null,
    Object? portfolioId = null,
    Object? quantity = null,
    Object? price = null,
    Object? fees = null,
    Object? notes = freezed,
    Object? executedAt = freezed,
  }) {
    return _then(_TradeTicket(
      side: null == side
          ? _self.side
          : side // ignore: cast_nullable_to_non_nullable
              as TradeSide,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      fees: null == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as double,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      executedAt: freezed == executedAt
          ? _self.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
