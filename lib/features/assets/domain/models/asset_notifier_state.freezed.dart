// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asset_notifier_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LedgerPaginationState {
  List<LedgerEntryDto> get items;
  int get total;
  int get limit;
  int get offset;
  bool get isLoadingMore;

  /// Create a copy of LedgerPaginationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LedgerPaginationStateCopyWith<LedgerPaginationState> get copyWith =>
      _$LedgerPaginationStateCopyWithImpl<LedgerPaginationState>(
          this as LedgerPaginationState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LedgerPaginationState &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(items),
      total,
      limit,
      offset,
      isLoadingMore);

  @override
  String toString() {
    return 'LedgerPaginationState(items: $items, total: $total, limit: $limit, offset: $offset, isLoadingMore: $isLoadingMore)';
  }
}

/// @nodoc
abstract mixin class $LedgerPaginationStateCopyWith<$Res> {
  factory $LedgerPaginationStateCopyWith(LedgerPaginationState value,
          $Res Function(LedgerPaginationState) _then) =
      _$LedgerPaginationStateCopyWithImpl;
  @useResult
  $Res call(
      {List<LedgerEntryDto> items,
      int total,
      int limit,
      int offset,
      bool isLoadingMore});
}

/// @nodoc
class _$LedgerPaginationStateCopyWithImpl<$Res>
    implements $LedgerPaginationStateCopyWith<$Res> {
  _$LedgerPaginationStateCopyWithImpl(this._self, this._then);

  final LedgerPaginationState _self;
  final $Res Function(LedgerPaginationState) _then;

  /// Create a copy of LedgerPaginationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
    Object? isLoadingMore = null,
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
      isLoadingMore: null == isLoadingMore
          ? _self.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [LedgerPaginationState].
extension LedgerPaginationStatePatterns on LedgerPaginationState {
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
    TResult Function(_LedgerPaginationState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState() when $default != null:
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
    TResult Function(_LedgerPaginationState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState():
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
    TResult? Function(_LedgerPaginationState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState() when $default != null:
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
    TResult Function(List<LedgerEntryDto> items, int total, int limit,
            int offset, bool isLoadingMore)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset,
            _that.isLoadingMore);
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
    TResult Function(List<LedgerEntryDto> items, int total, int limit,
            int offset, bool isLoadingMore)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState():
        return $default(_that.items, _that.total, _that.limit, _that.offset,
            _that.isLoadingMore);
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
    TResult? Function(List<LedgerEntryDto> items, int total, int limit,
            int offset, bool isLoadingMore)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LedgerPaginationState() when $default != null:
        return $default(_that.items, _that.total, _that.limit, _that.offset,
            _that.isLoadingMore);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _LedgerPaginationState extends LedgerPaginationState {
  const _LedgerPaginationState(
      {final List<LedgerEntryDto> items = const <LedgerEntryDto>[],
      this.total = 0,
      this.limit = 50,
      this.offset = 0,
      this.isLoadingMore = false})
      : _items = items,
        super._();

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
  @override
  @JsonKey()
  final bool isLoadingMore;

  /// Create a copy of LedgerPaginationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LedgerPaginationStateCopyWith<_LedgerPaginationState> get copyWith =>
      __$LedgerPaginationStateCopyWithImpl<_LedgerPaginationState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LedgerPaginationState &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_items),
      total,
      limit,
      offset,
      isLoadingMore);

  @override
  String toString() {
    return 'LedgerPaginationState(items: $items, total: $total, limit: $limit, offset: $offset, isLoadingMore: $isLoadingMore)';
  }
}

/// @nodoc
abstract mixin class _$LedgerPaginationStateCopyWith<$Res>
    implements $LedgerPaginationStateCopyWith<$Res> {
  factory _$LedgerPaginationStateCopyWith(_LedgerPaginationState value,
          $Res Function(_LedgerPaginationState) _then) =
      __$LedgerPaginationStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<LedgerEntryDto> items,
      int total,
      int limit,
      int offset,
      bool isLoadingMore});
}

/// @nodoc
class __$LedgerPaginationStateCopyWithImpl<$Res>
    implements _$LedgerPaginationStateCopyWith<$Res> {
  __$LedgerPaginationStateCopyWithImpl(this._self, this._then);

  final _LedgerPaginationState _self;
  final $Res Function(_LedgerPaginationState) _then;

  /// Create a copy of LedgerPaginationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? total = null,
    Object? limit = null,
    Object? offset = null,
    Object? isLoadingMore = null,
  }) {
    return _then(_LedgerPaginationState(
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
      isLoadingMore: null == isLoadingMore
          ? _self.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$TransactionFormState {
  String get portfolioId;
  String get assetId;
  String get transactionType;
  String get quantityInput;
  String get priceInput;
  String get feesInput;
  String get dividendPerUnitInput;
  String get bonusRatioInput;
  String get splitFromInput;
  String get splitToInput;
  String get rightsRatioInput;
  String get subscriptionPriceInput;
  String get notes;
  bool get submitting;
  String? get errorMessage;
  bool get submitSuccess;

  /// Create a copy of TransactionFormState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TransactionFormStateCopyWith<TransactionFormState> get copyWith =>
      _$TransactionFormStateCopyWithImpl<TransactionFormState>(
          this as TransactionFormState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TransactionFormState &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.quantityInput, quantityInput) ||
                other.quantityInput == quantityInput) &&
            (identical(other.priceInput, priceInput) ||
                other.priceInput == priceInput) &&
            (identical(other.feesInput, feesInput) ||
                other.feesInput == feesInput) &&
            (identical(other.dividendPerUnitInput, dividendPerUnitInput) ||
                other.dividendPerUnitInput == dividendPerUnitInput) &&
            (identical(other.bonusRatioInput, bonusRatioInput) ||
                other.bonusRatioInput == bonusRatioInput) &&
            (identical(other.splitFromInput, splitFromInput) ||
                other.splitFromInput == splitFromInput) &&
            (identical(other.splitToInput, splitToInput) ||
                other.splitToInput == splitToInput) &&
            (identical(other.rightsRatioInput, rightsRatioInput) ||
                other.rightsRatioInput == rightsRatioInput) &&
            (identical(other.subscriptionPriceInput, subscriptionPriceInput) ||
                other.subscriptionPriceInput == subscriptionPriceInput) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.submitting, submitting) ||
                other.submitting == submitting) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.submitSuccess, submitSuccess) ||
                other.submitSuccess == submitSuccess));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      assetId,
      transactionType,
      quantityInput,
      priceInput,
      feesInput,
      dividendPerUnitInput,
      bonusRatioInput,
      splitFromInput,
      splitToInput,
      rightsRatioInput,
      subscriptionPriceInput,
      notes,
      submitting,
      errorMessage,
      submitSuccess);

  @override
  String toString() {
    return 'TransactionFormState(portfolioId: $portfolioId, assetId: $assetId, transactionType: $transactionType, quantityInput: $quantityInput, priceInput: $priceInput, feesInput: $feesInput, dividendPerUnitInput: $dividendPerUnitInput, bonusRatioInput: $bonusRatioInput, splitFromInput: $splitFromInput, splitToInput: $splitToInput, rightsRatioInput: $rightsRatioInput, subscriptionPriceInput: $subscriptionPriceInput, notes: $notes, submitting: $submitting, errorMessage: $errorMessage, submitSuccess: $submitSuccess)';
  }
}

/// @nodoc
abstract mixin class $TransactionFormStateCopyWith<$Res> {
  factory $TransactionFormStateCopyWith(TransactionFormState value,
          $Res Function(TransactionFormState) _then) =
      _$TransactionFormStateCopyWithImpl;
  @useResult
  $Res call(
      {String portfolioId,
      String assetId,
      String transactionType,
      String quantityInput,
      String priceInput,
      String feesInput,
      String dividendPerUnitInput,
      String bonusRatioInput,
      String splitFromInput,
      String splitToInput,
      String rightsRatioInput,
      String subscriptionPriceInput,
      String notes,
      bool submitting,
      String? errorMessage,
      bool submitSuccess});
}

/// @nodoc
class _$TransactionFormStateCopyWithImpl<$Res>
    implements $TransactionFormStateCopyWith<$Res> {
  _$TransactionFormStateCopyWithImpl(this._self, this._then);

  final TransactionFormState _self;
  final $Res Function(TransactionFormState) _then;

  /// Create a copy of TransactionFormState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? transactionType = null,
    Object? quantityInput = null,
    Object? priceInput = null,
    Object? feesInput = null,
    Object? dividendPerUnitInput = null,
    Object? bonusRatioInput = null,
    Object? splitFromInput = null,
    Object? splitToInput = null,
    Object? rightsRatioInput = null,
    Object? subscriptionPriceInput = null,
    Object? notes = null,
    Object? submitting = null,
    Object? errorMessage = freezed,
    Object? submitSuccess = null,
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
      transactionType: null == transactionType
          ? _self.transactionType
          : transactionType // ignore: cast_nullable_to_non_nullable
              as String,
      quantityInput: null == quantityInput
          ? _self.quantityInput
          : quantityInput // ignore: cast_nullable_to_non_nullable
              as String,
      priceInput: null == priceInput
          ? _self.priceInput
          : priceInput // ignore: cast_nullable_to_non_nullable
              as String,
      feesInput: null == feesInput
          ? _self.feesInput
          : feesInput // ignore: cast_nullable_to_non_nullable
              as String,
      dividendPerUnitInput: null == dividendPerUnitInput
          ? _self.dividendPerUnitInput
          : dividendPerUnitInput // ignore: cast_nullable_to_non_nullable
              as String,
      bonusRatioInput: null == bonusRatioInput
          ? _self.bonusRatioInput
          : bonusRatioInput // ignore: cast_nullable_to_non_nullable
              as String,
      splitFromInput: null == splitFromInput
          ? _self.splitFromInput
          : splitFromInput // ignore: cast_nullable_to_non_nullable
              as String,
      splitToInput: null == splitToInput
          ? _self.splitToInput
          : splitToInput // ignore: cast_nullable_to_non_nullable
              as String,
      rightsRatioInput: null == rightsRatioInput
          ? _self.rightsRatioInput
          : rightsRatioInput // ignore: cast_nullable_to_non_nullable
              as String,
      subscriptionPriceInput: null == subscriptionPriceInput
          ? _self.subscriptionPriceInput
          : subscriptionPriceInput // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      submitting: null == submitting
          ? _self.submitting
          : submitting // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      submitSuccess: null == submitSuccess
          ? _self.submitSuccess
          : submitSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [TransactionFormState].
extension TransactionFormStatePatterns on TransactionFormState {
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
    TResult Function(_TransactionFormState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState() when $default != null:
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
    TResult Function(_TransactionFormState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState():
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
    TResult? Function(_TransactionFormState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState() when $default != null:
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
            String portfolioId,
            String assetId,
            String transactionType,
            String quantityInput,
            String priceInput,
            String feesInput,
            String dividendPerUnitInput,
            String bonusRatioInput,
            String splitFromInput,
            String splitToInput,
            String rightsRatioInput,
            String subscriptionPriceInput,
            String notes,
            bool submitting,
            String? errorMessage,
            bool submitSuccess)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState() when $default != null:
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.quantityInput,
            _that.priceInput,
            _that.feesInput,
            _that.dividendPerUnitInput,
            _that.bonusRatioInput,
            _that.splitFromInput,
            _that.splitToInput,
            _that.rightsRatioInput,
            _that.subscriptionPriceInput,
            _that.notes,
            _that.submitting,
            _that.errorMessage,
            _that.submitSuccess);
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
            String portfolioId,
            String assetId,
            String transactionType,
            String quantityInput,
            String priceInput,
            String feesInput,
            String dividendPerUnitInput,
            String bonusRatioInput,
            String splitFromInput,
            String splitToInput,
            String rightsRatioInput,
            String subscriptionPriceInput,
            String notes,
            bool submitting,
            String? errorMessage,
            bool submitSuccess)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState():
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.quantityInput,
            _that.priceInput,
            _that.feesInput,
            _that.dividendPerUnitInput,
            _that.bonusRatioInput,
            _that.splitFromInput,
            _that.splitToInput,
            _that.rightsRatioInput,
            _that.subscriptionPriceInput,
            _that.notes,
            _that.submitting,
            _that.errorMessage,
            _that.submitSuccess);
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
            String portfolioId,
            String assetId,
            String transactionType,
            String quantityInput,
            String priceInput,
            String feesInput,
            String dividendPerUnitInput,
            String bonusRatioInput,
            String splitFromInput,
            String splitToInput,
            String rightsRatioInput,
            String subscriptionPriceInput,
            String notes,
            bool submitting,
            String? errorMessage,
            bool submitSuccess)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TransactionFormState() when $default != null:
        return $default(
            _that.portfolioId,
            _that.assetId,
            _that.transactionType,
            _that.quantityInput,
            _that.priceInput,
            _that.feesInput,
            _that.dividendPerUnitInput,
            _that.bonusRatioInput,
            _that.splitFromInput,
            _that.splitToInput,
            _that.rightsRatioInput,
            _that.subscriptionPriceInput,
            _that.notes,
            _that.submitting,
            _that.errorMessage,
            _that.submitSuccess);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TransactionFormState extends TransactionFormState {
  const _TransactionFormState(
      {required this.portfolioId,
      required this.assetId,
      this.transactionType = 'BUY',
      this.quantityInput = '0',
      this.priceInput = '0',
      this.feesInput = '0',
      this.dividendPerUnitInput = '0',
      this.bonusRatioInput = '0',
      this.splitFromInput = '1',
      this.splitToInput = '2',
      this.rightsRatioInput = '0',
      this.subscriptionPriceInput = '0',
      this.notes = '',
      this.submitting = false,
      this.errorMessage,
      this.submitSuccess = false})
      : super._();

  @override
  final String portfolioId;
  @override
  final String assetId;
  @override
  @JsonKey()
  final String transactionType;
  @override
  @JsonKey()
  final String quantityInput;
  @override
  @JsonKey()
  final String priceInput;
  @override
  @JsonKey()
  final String feesInput;
  @override
  @JsonKey()
  final String dividendPerUnitInput;
  @override
  @JsonKey()
  final String bonusRatioInput;
  @override
  @JsonKey()
  final String splitFromInput;
  @override
  @JsonKey()
  final String splitToInput;
  @override
  @JsonKey()
  final String rightsRatioInput;
  @override
  @JsonKey()
  final String subscriptionPriceInput;
  @override
  @JsonKey()
  final String notes;
  @override
  @JsonKey()
  final bool submitting;
  @override
  final String? errorMessage;
  @override
  @JsonKey()
  final bool submitSuccess;

  /// Create a copy of TransactionFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TransactionFormStateCopyWith<_TransactionFormState> get copyWith =>
      __$TransactionFormStateCopyWithImpl<_TransactionFormState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TransactionFormState &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.assetId, assetId) || other.assetId == assetId) &&
            (identical(other.transactionType, transactionType) ||
                other.transactionType == transactionType) &&
            (identical(other.quantityInput, quantityInput) ||
                other.quantityInput == quantityInput) &&
            (identical(other.priceInput, priceInput) ||
                other.priceInput == priceInput) &&
            (identical(other.feesInput, feesInput) ||
                other.feesInput == feesInput) &&
            (identical(other.dividendPerUnitInput, dividendPerUnitInput) ||
                other.dividendPerUnitInput == dividendPerUnitInput) &&
            (identical(other.bonusRatioInput, bonusRatioInput) ||
                other.bonusRatioInput == bonusRatioInput) &&
            (identical(other.splitFromInput, splitFromInput) ||
                other.splitFromInput == splitFromInput) &&
            (identical(other.splitToInput, splitToInput) ||
                other.splitToInput == splitToInput) &&
            (identical(other.rightsRatioInput, rightsRatioInput) ||
                other.rightsRatioInput == rightsRatioInput) &&
            (identical(other.subscriptionPriceInput, subscriptionPriceInput) ||
                other.subscriptionPriceInput == subscriptionPriceInput) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.submitting, submitting) ||
                other.submitting == submitting) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.submitSuccess, submitSuccess) ||
                other.submitSuccess == submitSuccess));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      assetId,
      transactionType,
      quantityInput,
      priceInput,
      feesInput,
      dividendPerUnitInput,
      bonusRatioInput,
      splitFromInput,
      splitToInput,
      rightsRatioInput,
      subscriptionPriceInput,
      notes,
      submitting,
      errorMessage,
      submitSuccess);

  @override
  String toString() {
    return 'TransactionFormState(portfolioId: $portfolioId, assetId: $assetId, transactionType: $transactionType, quantityInput: $quantityInput, priceInput: $priceInput, feesInput: $feesInput, dividendPerUnitInput: $dividendPerUnitInput, bonusRatioInput: $bonusRatioInput, splitFromInput: $splitFromInput, splitToInput: $splitToInput, rightsRatioInput: $rightsRatioInput, subscriptionPriceInput: $subscriptionPriceInput, notes: $notes, submitting: $submitting, errorMessage: $errorMessage, submitSuccess: $submitSuccess)';
  }
}

/// @nodoc
abstract mixin class _$TransactionFormStateCopyWith<$Res>
    implements $TransactionFormStateCopyWith<$Res> {
  factory _$TransactionFormStateCopyWith(_TransactionFormState value,
          $Res Function(_TransactionFormState) _then) =
      __$TransactionFormStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String portfolioId,
      String assetId,
      String transactionType,
      String quantityInput,
      String priceInput,
      String feesInput,
      String dividendPerUnitInput,
      String bonusRatioInput,
      String splitFromInput,
      String splitToInput,
      String rightsRatioInput,
      String subscriptionPriceInput,
      String notes,
      bool submitting,
      String? errorMessage,
      bool submitSuccess});
}

/// @nodoc
class __$TransactionFormStateCopyWithImpl<$Res>
    implements _$TransactionFormStateCopyWith<$Res> {
  __$TransactionFormStateCopyWithImpl(this._self, this._then);

  final _TransactionFormState _self;
  final $Res Function(_TransactionFormState) _then;

  /// Create a copy of TransactionFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? assetId = null,
    Object? transactionType = null,
    Object? quantityInput = null,
    Object? priceInput = null,
    Object? feesInput = null,
    Object? dividendPerUnitInput = null,
    Object? bonusRatioInput = null,
    Object? splitFromInput = null,
    Object? splitToInput = null,
    Object? rightsRatioInput = null,
    Object? subscriptionPriceInput = null,
    Object? notes = null,
    Object? submitting = null,
    Object? errorMessage = freezed,
    Object? submitSuccess = null,
  }) {
    return _then(_TransactionFormState(
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
      quantityInput: null == quantityInput
          ? _self.quantityInput
          : quantityInput // ignore: cast_nullable_to_non_nullable
              as String,
      priceInput: null == priceInput
          ? _self.priceInput
          : priceInput // ignore: cast_nullable_to_non_nullable
              as String,
      feesInput: null == feesInput
          ? _self.feesInput
          : feesInput // ignore: cast_nullable_to_non_nullable
              as String,
      dividendPerUnitInput: null == dividendPerUnitInput
          ? _self.dividendPerUnitInput
          : dividendPerUnitInput // ignore: cast_nullable_to_non_nullable
              as String,
      bonusRatioInput: null == bonusRatioInput
          ? _self.bonusRatioInput
          : bonusRatioInput // ignore: cast_nullable_to_non_nullable
              as String,
      splitFromInput: null == splitFromInput
          ? _self.splitFromInput
          : splitFromInput // ignore: cast_nullable_to_non_nullable
              as String,
      splitToInput: null == splitToInput
          ? _self.splitToInput
          : splitToInput // ignore: cast_nullable_to_non_nullable
              as String,
      rightsRatioInput: null == rightsRatioInput
          ? _self.rightsRatioInput
          : rightsRatioInput // ignore: cast_nullable_to_non_nullable
              as String,
      subscriptionPriceInput: null == subscriptionPriceInput
          ? _self.subscriptionPriceInput
          : subscriptionPriceInput // ignore: cast_nullable_to_non_nullable
              as String,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
      submitting: null == submitting
          ? _self.submitting
          : submitting // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      submitSuccess: null == submitSuccess
          ? _self.submitSuccess
          : submitSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
