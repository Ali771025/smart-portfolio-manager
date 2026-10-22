// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manual_entry_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ManualEntryPayload {
  String get portfolioId;
  String get symbol;
  DateTime get tradeDate;
  Decimal get quantity;
  String? get notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ManualEntryPayloadCopyWith<ManualEntryPayload> get copyWith =>
      _$ManualEntryPayloadCopyWithImpl<ManualEntryPayload>(
          this as ManualEntryPayload, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ManualEntryPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, portfolioId, symbol, tradeDate, quantity, notes);

  @override
  String toString() {
    return 'ManualEntryPayload(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $ManualEntryPayloadCopyWith<$Res> {
  factory $ManualEntryPayloadCopyWith(
          ManualEntryPayload value, $Res Function(ManualEntryPayload) _then) =
      _$ManualEntryPayloadCopyWithImpl;
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      String? notes});
}

/// @nodoc
class _$ManualEntryPayloadCopyWithImpl<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  _$ManualEntryPayloadCopyWithImpl(this._self, this._then);

  final ManualEntryPayload _self;
  final $Res Function(ManualEntryPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? notes = freezed,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ManualEntryPayload].
extension ManualEntryPayloadPatterns on ManualEntryPayload {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BuyPayload value)? buy,
    TResult Function(SellPayload value)? sell,
    TResult Function(CapitalIncreaseBonusPayload value)? capitalIncreaseBonus,
    TResult Function(StockSplitPayload value)? stockSplit,
    TResult Function(PreEmptiveRightsPayload value)? preEmptiveRights,
    TResult Function(CashDividendPayload value)? cashDividend,
    TResult Function(AssetTransferPayload value)? assetTransfer,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload() when buy != null:
        return buy(_that);
      case SellPayload() when sell != null:
        return sell(_that);
      case CapitalIncreaseBonusPayload() when capitalIncreaseBonus != null:
        return capitalIncreaseBonus(_that);
      case StockSplitPayload() when stockSplit != null:
        return stockSplit(_that);
      case PreEmptiveRightsPayload() when preEmptiveRights != null:
        return preEmptiveRights(_that);
      case CashDividendPayload() when cashDividend != null:
        return cashDividend(_that);
      case AssetTransferPayload() when assetTransfer != null:
        return assetTransfer(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(BuyPayload value) buy,
    required TResult Function(SellPayload value) sell,
    required TResult Function(CapitalIncreaseBonusPayload value)
        capitalIncreaseBonus,
    required TResult Function(StockSplitPayload value) stockSplit,
    required TResult Function(PreEmptiveRightsPayload value) preEmptiveRights,
    required TResult Function(CashDividendPayload value) cashDividend,
    required TResult Function(AssetTransferPayload value) assetTransfer,
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload():
        return buy(_that);
      case SellPayload():
        return sell(_that);
      case CapitalIncreaseBonusPayload():
        return capitalIncreaseBonus(_that);
      case StockSplitPayload():
        return stockSplit(_that);
      case PreEmptiveRightsPayload():
        return preEmptiveRights(_that);
      case CashDividendPayload():
        return cashDividend(_that);
      case AssetTransferPayload():
        return assetTransfer(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BuyPayload value)? buy,
    TResult? Function(SellPayload value)? sell,
    TResult? Function(CapitalIncreaseBonusPayload value)? capitalIncreaseBonus,
    TResult? Function(StockSplitPayload value)? stockSplit,
    TResult? Function(PreEmptiveRightsPayload value)? preEmptiveRights,
    TResult? Function(CashDividendPayload value)? cashDividend,
    TResult? Function(AssetTransferPayload value)? assetTransfer,
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload() when buy != null:
        return buy(_that);
      case SellPayload() when sell != null:
        return sell(_that);
      case CapitalIncreaseBonusPayload() when capitalIncreaseBonus != null:
        return capitalIncreaseBonus(_that);
      case StockSplitPayload() when stockSplit != null:
        return stockSplit(_that);
      case PreEmptiveRightsPayload() when preEmptiveRights != null:
        return preEmptiveRights(_that);
      case CashDividendPayload() when cashDividend != null:
        return cashDividend(_that);
      case AssetTransferPayload() when assetTransfer != null:
        return assetTransfer(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal price, Decimal commission, String? notes)?
        buy,
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal price, Decimal commission, String? notes)?
        sell,
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal bonusRatio, String? notes)?
        capitalIncreaseBonus,
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, int splitFrom, int splitTo, String? notes)?
        stockSplit,
    TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal rightsRatio,
            Decimal subscriptionPrice,
            Decimal commission,
            String? notes)?
        preEmptiveRights,
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal dps, String? notes)?
        cashDividend,
    TResult Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, String targetSymbol, String? notes)?
        assetTransfer,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload() when buy != null:
        return buy(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case SellPayload() when sell != null:
        return sell(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case CapitalIncreaseBonusPayload() when capitalIncreaseBonus != null:
        return capitalIncreaseBonus(_that.portfolioId, _that.symbol,
            _that.tradeDate, _that.quantity, _that.bonusRatio, _that.notes);
      case StockSplitPayload() when stockSplit != null:
        return stockSplit(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.splitFrom, _that.splitTo, _that.notes);
      case PreEmptiveRightsPayload() when preEmptiveRights != null:
        return preEmptiveRights(
            _that.portfolioId,
            _that.symbol,
            _that.tradeDate,
            _that.quantity,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.commission,
            _that.notes);
      case CashDividendPayload() when cashDividend != null:
        return cashDividend(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.dps, _that.notes);
      case AssetTransferPayload() when assetTransfer != null:
        return assetTransfer(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.targetSymbol, _that.notes);
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
  TResult when<TResult extends Object?>({
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal price,
            Decimal commission,
            String? notes)
        buy,
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal price,
            Decimal commission,
            String? notes)
        sell,
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal bonusRatio,
            String? notes)
        capitalIncreaseBonus,
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            int splitFrom,
            int splitTo,
            String? notes)
        stockSplit,
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal rightsRatio,
            Decimal subscriptionPrice,
            Decimal commission,
            String? notes)
        preEmptiveRights,
    required TResult Function(String portfolioId, String symbol,
            DateTime tradeDate, Decimal quantity, Decimal dps, String? notes)
        cashDividend,
    required TResult Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            String targetSymbol,
            String? notes)
        assetTransfer,
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload():
        return buy(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case SellPayload():
        return sell(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case CapitalIncreaseBonusPayload():
        return capitalIncreaseBonus(_that.portfolioId, _that.symbol,
            _that.tradeDate, _that.quantity, _that.bonusRatio, _that.notes);
      case StockSplitPayload():
        return stockSplit(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.splitFrom, _that.splitTo, _that.notes);
      case PreEmptiveRightsPayload():
        return preEmptiveRights(
            _that.portfolioId,
            _that.symbol,
            _that.tradeDate,
            _that.quantity,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.commission,
            _that.notes);
      case CashDividendPayload():
        return cashDividend(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.dps, _that.notes);
      case AssetTransferPayload():
        return assetTransfer(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.targetSymbol, _that.notes);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal price, Decimal commission, String? notes)?
        buy,
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal price, Decimal commission, String? notes)?
        sell,
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal bonusRatio, String? notes)?
        capitalIncreaseBonus,
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, int splitFrom, int splitTo, String? notes)?
        stockSplit,
    TResult? Function(
            String portfolioId,
            String symbol,
            DateTime tradeDate,
            Decimal quantity,
            Decimal rightsRatio,
            Decimal subscriptionPrice,
            Decimal commission,
            String? notes)?
        preEmptiveRights,
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, Decimal dps, String? notes)?
        cashDividend,
    TResult? Function(String portfolioId, String symbol, DateTime tradeDate,
            Decimal quantity, String targetSymbol, String? notes)?
        assetTransfer,
  }) {
    final _that = this;
    switch (_that) {
      case BuyPayload() when buy != null:
        return buy(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case SellPayload() when sell != null:
        return sell(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.price, _that.commission, _that.notes);
      case CapitalIncreaseBonusPayload() when capitalIncreaseBonus != null:
        return capitalIncreaseBonus(_that.portfolioId, _that.symbol,
            _that.tradeDate, _that.quantity, _that.bonusRatio, _that.notes);
      case StockSplitPayload() when stockSplit != null:
        return stockSplit(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.splitFrom, _that.splitTo, _that.notes);
      case PreEmptiveRightsPayload() when preEmptiveRights != null:
        return preEmptiveRights(
            _that.portfolioId,
            _that.symbol,
            _that.tradeDate,
            _that.quantity,
            _that.rightsRatio,
            _that.subscriptionPrice,
            _that.commission,
            _that.notes);
      case CashDividendPayload() when cashDividend != null:
        return cashDividend(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.dps, _that.notes);
      case AssetTransferPayload() when assetTransfer != null:
        return assetTransfer(_that.portfolioId, _that.symbol, _that.tradeDate,
            _that.quantity, _that.targetSymbol, _that.notes);
      case _:
        return null;
    }
  }
}

/// @nodoc

class BuyPayload extends ManualEntryPayload {
  const BuyPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.price,
      required this.commission,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final Decimal price;
  final Decimal commission;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BuyPayloadCopyWith<BuyPayload> get copyWith =>
      _$BuyPayloadCopyWithImpl<BuyPayload>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BuyPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.commission, commission) ||
                other.commission == commission) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, symbol, tradeDate,
      quantity, price, commission, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.buy(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, price: $price, commission: $commission, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $BuyPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $BuyPayloadCopyWith(
          BuyPayload value, $Res Function(BuyPayload) _then) =
      _$BuyPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      Decimal price,
      Decimal commission,
      String? notes});
}

/// @nodoc
class _$BuyPayloadCopyWithImpl<$Res> implements $BuyPayloadCopyWith<$Res> {
  _$BuyPayloadCopyWithImpl(this._self, this._then);

  final BuyPayload _self;
  final $Res Function(BuyPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? price = null,
    Object? commission = null,
    Object? notes = freezed,
  }) {
    return _then(BuyPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as Decimal,
      commission: null == commission
          ? _self.commission
          : commission // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class SellPayload extends ManualEntryPayload {
  const SellPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.price,
      required this.commission,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final Decimal price;
  final Decimal commission;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SellPayloadCopyWith<SellPayload> get copyWith =>
      _$SellPayloadCopyWithImpl<SellPayload>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SellPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.commission, commission) ||
                other.commission == commission) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, symbol, tradeDate,
      quantity, price, commission, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.sell(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, price: $price, commission: $commission, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $SellPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $SellPayloadCopyWith(
          SellPayload value, $Res Function(SellPayload) _then) =
      _$SellPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      Decimal price,
      Decimal commission,
      String? notes});
}

/// @nodoc
class _$SellPayloadCopyWithImpl<$Res> implements $SellPayloadCopyWith<$Res> {
  _$SellPayloadCopyWithImpl(this._self, this._then);

  final SellPayload _self;
  final $Res Function(SellPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? price = null,
    Object? commission = null,
    Object? notes = freezed,
  }) {
    return _then(SellPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as Decimal,
      commission: null == commission
          ? _self.commission
          : commission // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class CapitalIncreaseBonusPayload extends ManualEntryPayload {
  const CapitalIncreaseBonusPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.bonusRatio,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final Decimal bonusRatio;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CapitalIncreaseBonusPayloadCopyWith<CapitalIncreaseBonusPayload>
      get copyWith => _$CapitalIncreaseBonusPayloadCopyWithImpl<
          CapitalIncreaseBonusPayload>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CapitalIncreaseBonusPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.bonusRatio, bonusRatio) ||
                other.bonusRatio == bonusRatio) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, portfolioId, symbol, tradeDate, quantity, bonusRatio, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.capitalIncreaseBonus(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, bonusRatio: $bonusRatio, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $CapitalIncreaseBonusPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $CapitalIncreaseBonusPayloadCopyWith(
          CapitalIncreaseBonusPayload value,
          $Res Function(CapitalIncreaseBonusPayload) _then) =
      _$CapitalIncreaseBonusPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      Decimal bonusRatio,
      String? notes});
}

/// @nodoc
class _$CapitalIncreaseBonusPayloadCopyWithImpl<$Res>
    implements $CapitalIncreaseBonusPayloadCopyWith<$Res> {
  _$CapitalIncreaseBonusPayloadCopyWithImpl(this._self, this._then);

  final CapitalIncreaseBonusPayload _self;
  final $Res Function(CapitalIncreaseBonusPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? bonusRatio = null,
    Object? notes = freezed,
  }) {
    return _then(CapitalIncreaseBonusPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      bonusRatio: null == bonusRatio
          ? _self.bonusRatio
          : bonusRatio // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class StockSplitPayload extends ManualEntryPayload {
  const StockSplitPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.splitFrom,
      required this.splitTo,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final int splitFrom;
  final int splitTo;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StockSplitPayloadCopyWith<StockSplitPayload> get copyWith =>
      _$StockSplitPayloadCopyWithImpl<StockSplitPayload>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StockSplitPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.splitFrom, splitFrom) ||
                other.splitFrom == splitFrom) &&
            (identical(other.splitTo, splitTo) || other.splitTo == splitTo) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, symbol, tradeDate,
      quantity, splitFrom, splitTo, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.stockSplit(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, splitFrom: $splitFrom, splitTo: $splitTo, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $StockSplitPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $StockSplitPayloadCopyWith(
          StockSplitPayload value, $Res Function(StockSplitPayload) _then) =
      _$StockSplitPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      int splitFrom,
      int splitTo,
      String? notes});
}

/// @nodoc
class _$StockSplitPayloadCopyWithImpl<$Res>
    implements $StockSplitPayloadCopyWith<$Res> {
  _$StockSplitPayloadCopyWithImpl(this._self, this._then);

  final StockSplitPayload _self;
  final $Res Function(StockSplitPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? splitFrom = null,
    Object? splitTo = null,
    Object? notes = freezed,
  }) {
    return _then(StockSplitPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      splitFrom: null == splitFrom
          ? _self.splitFrom
          : splitFrom // ignore: cast_nullable_to_non_nullable
              as int,
      splitTo: null == splitTo
          ? _self.splitTo
          : splitTo // ignore: cast_nullable_to_non_nullable
              as int,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class PreEmptiveRightsPayload extends ManualEntryPayload {
  const PreEmptiveRightsPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.rightsRatio,
      required this.subscriptionPrice,
      required this.commission,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final Decimal rightsRatio;
  final Decimal subscriptionPrice;
  final Decimal commission;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PreEmptiveRightsPayloadCopyWith<PreEmptiveRightsPayload> get copyWith =>
      _$PreEmptiveRightsPayloadCopyWithImpl<PreEmptiveRightsPayload>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PreEmptiveRightsPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.rightsRatio, rightsRatio) ||
                other.rightsRatio == rightsRatio) &&
            (identical(other.subscriptionPrice, subscriptionPrice) ||
                other.subscriptionPrice == subscriptionPrice) &&
            (identical(other.commission, commission) ||
                other.commission == commission) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, symbol, tradeDate,
      quantity, rightsRatio, subscriptionPrice, commission, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.preEmptiveRights(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, rightsRatio: $rightsRatio, subscriptionPrice: $subscriptionPrice, commission: $commission, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $PreEmptiveRightsPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $PreEmptiveRightsPayloadCopyWith(PreEmptiveRightsPayload value,
          $Res Function(PreEmptiveRightsPayload) _then) =
      _$PreEmptiveRightsPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      Decimal rightsRatio,
      Decimal subscriptionPrice,
      Decimal commission,
      String? notes});
}

/// @nodoc
class _$PreEmptiveRightsPayloadCopyWithImpl<$Res>
    implements $PreEmptiveRightsPayloadCopyWith<$Res> {
  _$PreEmptiveRightsPayloadCopyWithImpl(this._self, this._then);

  final PreEmptiveRightsPayload _self;
  final $Res Function(PreEmptiveRightsPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? rightsRatio = null,
    Object? subscriptionPrice = null,
    Object? commission = null,
    Object? notes = freezed,
  }) {
    return _then(PreEmptiveRightsPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      rightsRatio: null == rightsRatio
          ? _self.rightsRatio
          : rightsRatio // ignore: cast_nullable_to_non_nullable
              as Decimal,
      subscriptionPrice: null == subscriptionPrice
          ? _self.subscriptionPrice
          : subscriptionPrice // ignore: cast_nullable_to_non_nullable
              as Decimal,
      commission: null == commission
          ? _self.commission
          : commission // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class CashDividendPayload extends ManualEntryPayload {
  const CashDividendPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.dps,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final Decimal dps;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CashDividendPayloadCopyWith<CashDividendPayload> get copyWith =>
      _$CashDividendPayloadCopyWithImpl<CashDividendPayload>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CashDividendPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.dps, dps) || other.dps == dps) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, portfolioId, symbol, tradeDate, quantity, dps, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.cashDividend(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, dps: $dps, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $CashDividendPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $CashDividendPayloadCopyWith(
          CashDividendPayload value, $Res Function(CashDividendPayload) _then) =
      _$CashDividendPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      Decimal dps,
      String? notes});
}

/// @nodoc
class _$CashDividendPayloadCopyWithImpl<$Res>
    implements $CashDividendPayloadCopyWith<$Res> {
  _$CashDividendPayloadCopyWithImpl(this._self, this._then);

  final CashDividendPayload _self;
  final $Res Function(CashDividendPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? dps = null,
    Object? notes = freezed,
  }) {
    return _then(CashDividendPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      dps: null == dps
          ? _self.dps
          : dps // ignore: cast_nullable_to_non_nullable
              as Decimal,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class AssetTransferPayload extends ManualEntryPayload {
  const AssetTransferPayload(
      {required this.portfolioId,
      required this.symbol,
      required this.tradeDate,
      required this.quantity,
      required this.targetSymbol,
      this.notes})
      : super._();

  @override
  final String portfolioId;
  @override
  final String symbol;
  @override
  final DateTime tradeDate;
  @override
  final Decimal quantity;
  final String targetSymbol;
  @override
  final String? notes;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetTransferPayloadCopyWith<AssetTransferPayload> get copyWith =>
      _$AssetTransferPayloadCopyWithImpl<AssetTransferPayload>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AssetTransferPayload &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.symbol, symbol) || other.symbol == symbol) &&
            (identical(other.tradeDate, tradeDate) ||
                other.tradeDate == tradeDate) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.targetSymbol, targetSymbol) ||
                other.targetSymbol == targetSymbol) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, symbol, tradeDate,
      quantity, targetSymbol, notes);

  @override
  String toString() {
    return 'ManualEntryPayload.assetTransfer(portfolioId: $portfolioId, symbol: $symbol, tradeDate: $tradeDate, quantity: $quantity, targetSymbol: $targetSymbol, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $AssetTransferPayloadCopyWith<$Res>
    implements $ManualEntryPayloadCopyWith<$Res> {
  factory $AssetTransferPayloadCopyWith(AssetTransferPayload value,
          $Res Function(AssetTransferPayload) _then) =
      _$AssetTransferPayloadCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String symbol,
      DateTime tradeDate,
      Decimal quantity,
      String targetSymbol,
      String? notes});
}

/// @nodoc
class _$AssetTransferPayloadCopyWithImpl<$Res>
    implements $AssetTransferPayloadCopyWith<$Res> {
  _$AssetTransferPayloadCopyWithImpl(this._self, this._then);

  final AssetTransferPayload _self;
  final $Res Function(AssetTransferPayload) _then;

  /// Create a copy of ManualEntryPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? symbol = null,
    Object? tradeDate = null,
    Object? quantity = null,
    Object? targetSymbol = null,
    Object? notes = freezed,
  }) {
    return _then(AssetTransferPayload(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      symbol: null == symbol
          ? _self.symbol
          : symbol // ignore: cast_nullable_to_non_nullable
              as String,
      tradeDate: null == tradeDate
          ? _self.tradeDate
          : tradeDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as Decimal,
      targetSymbol: null == targetSymbol
          ? _self.targetSymbol
          : targetSymbol // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$ManualEntryFormState {
  ManualEntryPayload get payload;
  Map<String, String> get fieldErrors;
  bool get submitSuccess;
  String? get globalErrorMessage;

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ManualEntryFormStateCopyWith<ManualEntryFormState> get copyWith =>
      _$ManualEntryFormStateCopyWithImpl<ManualEntryFormState>(
          this as ManualEntryFormState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ManualEntryFormState &&
            (identical(other.payload, payload) || other.payload == payload) &&
            const DeepCollectionEquality()
                .equals(other.fieldErrors, fieldErrors) &&
            (identical(other.submitSuccess, submitSuccess) ||
                other.submitSuccess == submitSuccess) &&
            (identical(other.globalErrorMessage, globalErrorMessage) ||
                other.globalErrorMessage == globalErrorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      payload,
      const DeepCollectionEquality().hash(fieldErrors),
      submitSuccess,
      globalErrorMessage);

  @override
  String toString() {
    return 'ManualEntryFormState(payload: $payload, fieldErrors: $fieldErrors, submitSuccess: $submitSuccess, globalErrorMessage: $globalErrorMessage)';
  }
}

/// @nodoc
abstract mixin class $ManualEntryFormStateCopyWith<$Res> {
  factory $ManualEntryFormStateCopyWith(ManualEntryFormState value,
          $Res Function(ManualEntryFormState) _then) =
      _$ManualEntryFormStateCopyWithImpl;
  @useResult
  $Res call(
      {ManualEntryPayload payload,
      Map<String, String> fieldErrors,
      bool submitSuccess,
      String? globalErrorMessage});

  $ManualEntryPayloadCopyWith<$Res> get payload;
}

/// @nodoc
class _$ManualEntryFormStateCopyWithImpl<$Res>
    implements $ManualEntryFormStateCopyWith<$Res> {
  _$ManualEntryFormStateCopyWithImpl(this._self, this._then);

  final ManualEntryFormState _self;
  final $Res Function(ManualEntryFormState) _then;

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? payload = null,
    Object? fieldErrors = null,
    Object? submitSuccess = null,
    Object? globalErrorMessage = freezed,
  }) {
    return _then(_self.copyWith(
      payload: null == payload
          ? _self.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as ManualEntryPayload,
      fieldErrors: null == fieldErrors
          ? _self.fieldErrors
          : fieldErrors // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      submitSuccess: null == submitSuccess
          ? _self.submitSuccess
          : submitSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      globalErrorMessage: freezed == globalErrorMessage
          ? _self.globalErrorMessage
          : globalErrorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ManualEntryPayloadCopyWith<$Res> get payload {
    return $ManualEntryPayloadCopyWith<$Res>(_self.payload, (value) {
      return _then(_self.copyWith(payload: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ManualEntryFormState].
extension ManualEntryFormStatePatterns on ManualEntryFormState {
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
    TResult Function(_ManualEntryFormState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState() when $default != null:
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
    TResult Function(_ManualEntryFormState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState():
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
    TResult? Function(_ManualEntryFormState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState() when $default != null:
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
            ManualEntryPayload payload,
            Map<String, String> fieldErrors,
            bool submitSuccess,
            String? globalErrorMessage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState() when $default != null:
        return $default(_that.payload, _that.fieldErrors, _that.submitSuccess,
            _that.globalErrorMessage);
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
            ManualEntryPayload payload,
            Map<String, String> fieldErrors,
            bool submitSuccess,
            String? globalErrorMessage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState():
        return $default(_that.payload, _that.fieldErrors, _that.submitSuccess,
            _that.globalErrorMessage);
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
            ManualEntryPayload payload,
            Map<String, String> fieldErrors,
            bool submitSuccess,
            String? globalErrorMessage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ManualEntryFormState() when $default != null:
        return $default(_that.payload, _that.fieldErrors, _that.submitSuccess,
            _that.globalErrorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ManualEntryFormState extends ManualEntryFormState {
  const _ManualEntryFormState(
      {required this.payload,
      final Map<String, String> fieldErrors = const <String, String>{},
      this.submitSuccess = false,
      this.globalErrorMessage})
      : _fieldErrors = fieldErrors,
        super._();

  @override
  final ManualEntryPayload payload;
  final Map<String, String> _fieldErrors;
  @override
  @JsonKey()
  Map<String, String> get fieldErrors {
    if (_fieldErrors is EqualUnmodifiableMapView) return _fieldErrors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_fieldErrors);
  }

  @override
  @JsonKey()
  final bool submitSuccess;
  @override
  final String? globalErrorMessage;

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ManualEntryFormStateCopyWith<_ManualEntryFormState> get copyWith =>
      __$ManualEntryFormStateCopyWithImpl<_ManualEntryFormState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ManualEntryFormState &&
            (identical(other.payload, payload) || other.payload == payload) &&
            const DeepCollectionEquality()
                .equals(other._fieldErrors, _fieldErrors) &&
            (identical(other.submitSuccess, submitSuccess) ||
                other.submitSuccess == submitSuccess) &&
            (identical(other.globalErrorMessage, globalErrorMessage) ||
                other.globalErrorMessage == globalErrorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      payload,
      const DeepCollectionEquality().hash(_fieldErrors),
      submitSuccess,
      globalErrorMessage);

  @override
  String toString() {
    return 'ManualEntryFormState(payload: $payload, fieldErrors: $fieldErrors, submitSuccess: $submitSuccess, globalErrorMessage: $globalErrorMessage)';
  }
}

/// @nodoc
abstract mixin class _$ManualEntryFormStateCopyWith<$Res>
    implements $ManualEntryFormStateCopyWith<$Res> {
  factory _$ManualEntryFormStateCopyWith(_ManualEntryFormState value,
          $Res Function(_ManualEntryFormState) _then) =
      __$ManualEntryFormStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {ManualEntryPayload payload,
      Map<String, String> fieldErrors,
      bool submitSuccess,
      String? globalErrorMessage});

  @override
  $ManualEntryPayloadCopyWith<$Res> get payload;
}

/// @nodoc
class __$ManualEntryFormStateCopyWithImpl<$Res>
    implements _$ManualEntryFormStateCopyWith<$Res> {
  __$ManualEntryFormStateCopyWithImpl(this._self, this._then);

  final _ManualEntryFormState _self;
  final $Res Function(_ManualEntryFormState) _then;

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? payload = null,
    Object? fieldErrors = null,
    Object? submitSuccess = null,
    Object? globalErrorMessage = freezed,
  }) {
    return _then(_ManualEntryFormState(
      payload: null == payload
          ? _self.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as ManualEntryPayload,
      fieldErrors: null == fieldErrors
          ? _self._fieldErrors
          : fieldErrors // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      submitSuccess: null == submitSuccess
          ? _self.submitSuccess
          : submitSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      globalErrorMessage: freezed == globalErrorMessage
          ? _self.globalErrorMessage
          : globalErrorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of ManualEntryFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ManualEntryPayloadCopyWith<$Res> get payload {
    return $ManualEntryPayloadCopyWith<$Res>(_self.payload, (value) {
      return _then(_self.copyWith(payload: value));
    });
  }
}

// dart format on
