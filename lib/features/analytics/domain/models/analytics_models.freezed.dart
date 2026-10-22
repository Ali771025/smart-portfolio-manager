// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnalyticsPerformancePoint {
  @JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
  DateTime get date;
  @JsonKey(name: 'market_value', fromJson: _safeDouble)
  double get portfolioValue;
  @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
  double? get benchmarkValue;
  @JsonKey(name: 'pnl', fromJson: _safeDouble)
  double get pnl;
  @JsonKey(name: 'roi', fromJson: _safeDouble)
  double get roiPercent;

  /// Create a copy of AnalyticsPerformancePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AnalyticsPerformancePointCopyWith<AnalyticsPerformancePoint> get copyWith =>
      _$AnalyticsPerformancePointCopyWithImpl<AnalyticsPerformancePoint>(
          this as AnalyticsPerformancePoint, _$identity);

  /// Serializes this AnalyticsPerformancePoint to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AnalyticsPerformancePoint &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.portfolioValue, portfolioValue) ||
                other.portfolioValue == portfolioValue) &&
            (identical(other.benchmarkValue, benchmarkValue) ||
                other.benchmarkValue == benchmarkValue) &&
            (identical(other.pnl, pnl) || other.pnl == pnl) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, date, portfolioValue, benchmarkValue, pnl, roiPercent);

  @override
  String toString() {
    return 'AnalyticsPerformancePoint(date: $date, portfolioValue: $portfolioValue, benchmarkValue: $benchmarkValue, pnl: $pnl, roiPercent: $roiPercent)';
  }
}

/// @nodoc
abstract mixin class $AnalyticsPerformancePointCopyWith<$Res> {
  factory $AnalyticsPerformancePointCopyWith(AnalyticsPerformancePoint value,
          $Res Function(AnalyticsPerformancePoint) _then) =
      _$AnalyticsPerformancePointCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
      DateTime date,
      @JsonKey(name: 'market_value', fromJson: _safeDouble)
      double portfolioValue,
      @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
      double? benchmarkValue,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
      @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent});
}

/// @nodoc
class _$AnalyticsPerformancePointCopyWithImpl<$Res>
    implements $AnalyticsPerformancePointCopyWith<$Res> {
  _$AnalyticsPerformancePointCopyWithImpl(this._self, this._then);

  final AnalyticsPerformancePoint _self;
  final $Res Function(AnalyticsPerformancePoint) _then;

  /// Create a copy of AnalyticsPerformancePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? portfolioValue = null,
    Object? benchmarkValue = freezed,
    Object? pnl = null,
    Object? roiPercent = null,
  }) {
    return _then(_self.copyWith(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      portfolioValue: null == portfolioValue
          ? _self.portfolioValue
          : portfolioValue // ignore: cast_nullable_to_non_nullable
              as double,
      benchmarkValue: freezed == benchmarkValue
          ? _self.benchmarkValue
          : benchmarkValue // ignore: cast_nullable_to_non_nullable
              as double?,
      pnl: null == pnl
          ? _self.pnl
          : pnl // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [AnalyticsPerformancePoint].
extension AnalyticsPerformancePointPatterns on AnalyticsPerformancePoint {
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
    TResult Function(_AnalyticsPerformancePoint value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint() when $default != null:
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
    TResult Function(_AnalyticsPerformancePoint value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint():
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
    TResult? Function(_AnalyticsPerformancePoint value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint() when $default != null:
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
            @JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
            DateTime date,
            @JsonKey(name: 'market_value', fromJson: _safeDouble)
            double portfolioValue,
            @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
            double? benchmarkValue,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint() when $default != null:
        return $default(_that.date, _that.portfolioValue, _that.benchmarkValue,
            _that.pnl, _that.roiPercent);
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
            @JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
            DateTime date,
            @JsonKey(name: 'market_value', fromJson: _safeDouble)
            double portfolioValue,
            @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
            double? benchmarkValue,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint():
        return $default(_that.date, _that.portfolioValue, _that.benchmarkValue,
            _that.pnl, _that.roiPercent);
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
            @JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
            DateTime date,
            @JsonKey(name: 'market_value', fromJson: _safeDouble)
            double portfolioValue,
            @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
            double? benchmarkValue,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformancePoint() when $default != null:
        return $default(_that.date, _that.portfolioValue, _that.benchmarkValue,
            _that.pnl, _that.roiPercent);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AnalyticsPerformancePoint implements AnalyticsPerformancePoint {
  const _AnalyticsPerformancePoint(
      {@JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
      required this.date,
      @JsonKey(name: 'market_value', fromJson: _safeDouble)
      this.portfolioValue = 0,
      @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
      this.benchmarkValue,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) this.pnl = 0,
      @JsonKey(name: 'roi', fromJson: _safeDouble) this.roiPercent = 0});
  factory _AnalyticsPerformancePoint.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsPerformancePointFromJson(json);

  @override
  @JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
  final DateTime date;
  @override
  @JsonKey(name: 'market_value', fromJson: _safeDouble)
  final double portfolioValue;
  @override
  @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
  final double? benchmarkValue;
  @override
  @JsonKey(name: 'pnl', fromJson: _safeDouble)
  final double pnl;
  @override
  @JsonKey(name: 'roi', fromJson: _safeDouble)
  final double roiPercent;

  /// Create a copy of AnalyticsPerformancePoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AnalyticsPerformancePointCopyWith<_AnalyticsPerformancePoint>
      get copyWith =>
          __$AnalyticsPerformancePointCopyWithImpl<_AnalyticsPerformancePoint>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AnalyticsPerformancePointToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AnalyticsPerformancePoint &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.portfolioValue, portfolioValue) ||
                other.portfolioValue == portfolioValue) &&
            (identical(other.benchmarkValue, benchmarkValue) ||
                other.benchmarkValue == benchmarkValue) &&
            (identical(other.pnl, pnl) || other.pnl == pnl) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, date, portfolioValue, benchmarkValue, pnl, roiPercent);

  @override
  String toString() {
    return 'AnalyticsPerformancePoint(date: $date, portfolioValue: $portfolioValue, benchmarkValue: $benchmarkValue, pnl: $pnl, roiPercent: $roiPercent)';
  }
}

/// @nodoc
abstract mixin class _$AnalyticsPerformancePointCopyWith<$Res>
    implements $AnalyticsPerformancePointCopyWith<$Res> {
  factory _$AnalyticsPerformancePointCopyWith(_AnalyticsPerformancePoint value,
          $Res Function(_AnalyticsPerformancePoint) _then) =
      __$AnalyticsPerformancePointCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'date', fromJson: _parseApiDate, toJson: _dateToJson)
      DateTime date,
      @JsonKey(name: 'market_value', fromJson: _safeDouble)
      double portfolioValue,
      @JsonKey(name: 'benchmark_value', fromJson: _safeNullableDouble)
      double? benchmarkValue,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
      @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent});
}

/// @nodoc
class __$AnalyticsPerformancePointCopyWithImpl<$Res>
    implements _$AnalyticsPerformancePointCopyWith<$Res> {
  __$AnalyticsPerformancePointCopyWithImpl(this._self, this._then);

  final _AnalyticsPerformancePoint _self;
  final $Res Function(_AnalyticsPerformancePoint) _then;

  /// Create a copy of AnalyticsPerformancePoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
    Object? portfolioValue = null,
    Object? benchmarkValue = freezed,
    Object? pnl = null,
    Object? roiPercent = null,
  }) {
    return _then(_AnalyticsPerformancePoint(
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      portfolioValue: null == portfolioValue
          ? _self.portfolioValue
          : portfolioValue // ignore: cast_nullable_to_non_nullable
              as double,
      benchmarkValue: freezed == benchmarkValue
          ? _self.benchmarkValue
          : benchmarkValue // ignore: cast_nullable_to_non_nullable
              as double?,
      pnl: null == pnl
          ? _self.pnl
          : pnl // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$AnalyticsPerformanceSeries {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(
      name: 'timeframe', fromJson: _timeframeFromJson, toJson: _timeframeToJson)
  AnalyticsTimeframe get timeframe;
  @JsonKey(name: 'base_currency')
  String get baseCurrency;
  @JsonKey(name: 'points')
  List<AnalyticsPerformancePoint> get points;

  /// Create a copy of AnalyticsPerformanceSeries
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AnalyticsPerformanceSeriesCopyWith<AnalyticsPerformanceSeries>
      get copyWith =>
          _$AnalyticsPerformanceSeriesCopyWithImpl<AnalyticsPerformanceSeries>(
              this as AnalyticsPerformanceSeries, _$identity);

  /// Serializes this AnalyticsPerformanceSeries to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AnalyticsPerformanceSeries &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.timeframe, timeframe) ||
                other.timeframe == timeframe) &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            const DeepCollectionEquality().equals(other.points, points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, timeframe,
      baseCurrency, const DeepCollectionEquality().hash(points));

  @override
  String toString() {
    return 'AnalyticsPerformanceSeries(portfolioId: $portfolioId, timeframe: $timeframe, baseCurrency: $baseCurrency, points: $points)';
  }
}

/// @nodoc
abstract mixin class $AnalyticsPerformanceSeriesCopyWith<$Res> {
  factory $AnalyticsPerformanceSeriesCopyWith(AnalyticsPerformanceSeries value,
          $Res Function(AnalyticsPerformanceSeries) _then) =
      _$AnalyticsPerformanceSeriesCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      AnalyticsTimeframe timeframe,
      @JsonKey(name: 'base_currency') String baseCurrency,
      @JsonKey(name: 'points') List<AnalyticsPerformancePoint> points});
}

/// @nodoc
class _$AnalyticsPerformanceSeriesCopyWithImpl<$Res>
    implements $AnalyticsPerformanceSeriesCopyWith<$Res> {
  _$AnalyticsPerformanceSeriesCopyWithImpl(this._self, this._then);

  final AnalyticsPerformanceSeries _self;
  final $Res Function(AnalyticsPerformanceSeries) _then;

  /// Create a copy of AnalyticsPerformanceSeries
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? timeframe = null,
    Object? baseCurrency = null,
    Object? points = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      timeframe: null == timeframe
          ? _self.timeframe
          : timeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      baseCurrency: null == baseCurrency
          ? _self.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      points: null == points
          ? _self.points
          : points // ignore: cast_nullable_to_non_nullable
              as List<AnalyticsPerformancePoint>,
    ));
  }
}

/// Adds pattern-matching-related methods to [AnalyticsPerformanceSeries].
extension AnalyticsPerformanceSeriesPatterns on AnalyticsPerformanceSeries {
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
    TResult Function(_AnalyticsPerformanceSeries value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries() when $default != null:
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
    TResult Function(_AnalyticsPerformanceSeries value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries():
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
    TResult? Function(_AnalyticsPerformanceSeries value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries() when $default != null:
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(name: 'points') List<AnalyticsPerformancePoint> points)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries() when $default != null:
        return $default(_that.portfolioId, _that.timeframe, _that.baseCurrency,
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(name: 'points') List<AnalyticsPerformancePoint> points)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries():
        return $default(_that.portfolioId, _that.timeframe, _that.baseCurrency,
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(name: 'points') List<AnalyticsPerformancePoint> points)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsPerformanceSeries() when $default != null:
        return $default(_that.portfolioId, _that.timeframe, _that.baseCurrency,
            _that.points);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AnalyticsPerformanceSeries implements AnalyticsPerformanceSeries {
  const _AnalyticsPerformanceSeries(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      required this.timeframe,
      @JsonKey(name: 'base_currency') required this.baseCurrency,
      @JsonKey(name: 'points') final List<AnalyticsPerformancePoint> points =
          const <AnalyticsPerformancePoint>[]})
      : _points = points;
  factory _AnalyticsPerformanceSeries.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsPerformanceSeriesFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(
      name: 'timeframe', fromJson: _timeframeFromJson, toJson: _timeframeToJson)
  final AnalyticsTimeframe timeframe;
  @override
  @JsonKey(name: 'base_currency')
  final String baseCurrency;
  final List<AnalyticsPerformancePoint> _points;
  @override
  @JsonKey(name: 'points')
  List<AnalyticsPerformancePoint> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  /// Create a copy of AnalyticsPerformanceSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AnalyticsPerformanceSeriesCopyWith<_AnalyticsPerformanceSeries>
      get copyWith => __$AnalyticsPerformanceSeriesCopyWithImpl<
          _AnalyticsPerformanceSeries>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AnalyticsPerformanceSeriesToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AnalyticsPerformanceSeries &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.timeframe, timeframe) ||
                other.timeframe == timeframe) &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            const DeepCollectionEquality().equals(other._points, _points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, portfolioId, timeframe,
      baseCurrency, const DeepCollectionEquality().hash(_points));

  @override
  String toString() {
    return 'AnalyticsPerformanceSeries(portfolioId: $portfolioId, timeframe: $timeframe, baseCurrency: $baseCurrency, points: $points)';
  }
}

/// @nodoc
abstract mixin class _$AnalyticsPerformanceSeriesCopyWith<$Res>
    implements $AnalyticsPerformanceSeriesCopyWith<$Res> {
  factory _$AnalyticsPerformanceSeriesCopyWith(
          _AnalyticsPerformanceSeries value,
          $Res Function(_AnalyticsPerformanceSeries) _then) =
      __$AnalyticsPerformanceSeriesCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      AnalyticsTimeframe timeframe,
      @JsonKey(name: 'base_currency') String baseCurrency,
      @JsonKey(name: 'points') List<AnalyticsPerformancePoint> points});
}

/// @nodoc
class __$AnalyticsPerformanceSeriesCopyWithImpl<$Res>
    implements _$AnalyticsPerformanceSeriesCopyWith<$Res> {
  __$AnalyticsPerformanceSeriesCopyWithImpl(this._self, this._then);

  final _AnalyticsPerformanceSeries _self;
  final $Res Function(_AnalyticsPerformanceSeries) _then;

  /// Create a copy of AnalyticsPerformanceSeries
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? timeframe = null,
    Object? baseCurrency = null,
    Object? points = null,
  }) {
    return _then(_AnalyticsPerformanceSeries(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      timeframe: null == timeframe
          ? _self.timeframe
          : timeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      baseCurrency: null == baseCurrency
          ? _self.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      points: null == points
          ? _self._points
          : points // ignore: cast_nullable_to_non_nullable
              as List<AnalyticsPerformancePoint>,
    ));
  }
}

/// @nodoc
mixin _$AnalyticsMetrics {
  @JsonKey(name: 'portfolio_id')
  String get portfolioId;
  @JsonKey(
      name: 'timeframe', fromJson: _timeframeFromJson, toJson: _timeframeToJson)
  AnalyticsTimeframe get timeframe;
  @JsonKey(name: 'base_currency')
  String get baseCurrency;
  @JsonKey(name: 'as_of_date', fromJson: _parseApiDate, toJson: _dateToJson)
  DateTime get asOfDate;
  @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
  double get riskFreeRate;
  @JsonKey(name: 'pnl', fromJson: _safeDouble)
  double get pnl;
  @JsonKey(name: 'roi', fromJson: _safeDouble)
  double get roiPercent;
  @JsonKey(name: 'volatility', fromJson: _safeDouble)
  double get volatility;
  @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
  double get sharpeRatio;
  @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
  AdvancedRiskMetricsResponse get riskAssessment;

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AnalyticsMetricsCopyWith<AnalyticsMetrics> get copyWith =>
      _$AnalyticsMetricsCopyWithImpl<AnalyticsMetrics>(
          this as AnalyticsMetrics, _$identity);

  /// Serializes this AnalyticsMetrics to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AnalyticsMetrics &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.timeframe, timeframe) ||
                other.timeframe == timeframe) &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            (identical(other.asOfDate, asOfDate) ||
                other.asOfDate == asOfDate) &&
            (identical(other.riskFreeRate, riskFreeRate) ||
                other.riskFreeRate == riskFreeRate) &&
            (identical(other.pnl, pnl) || other.pnl == pnl) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent) &&
            (identical(other.volatility, volatility) ||
                other.volatility == volatility) &&
            (identical(other.sharpeRatio, sharpeRatio) ||
                other.sharpeRatio == sharpeRatio) &&
            (identical(other.riskAssessment, riskAssessment) ||
                other.riskAssessment == riskAssessment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      timeframe,
      baseCurrency,
      asOfDate,
      riskFreeRate,
      pnl,
      roiPercent,
      volatility,
      sharpeRatio,
      riskAssessment);

  @override
  String toString() {
    return 'AnalyticsMetrics(portfolioId: $portfolioId, timeframe: $timeframe, baseCurrency: $baseCurrency, asOfDate: $asOfDate, riskFreeRate: $riskFreeRate, pnl: $pnl, roiPercent: $roiPercent, volatility: $volatility, sharpeRatio: $sharpeRatio, riskAssessment: $riskAssessment)';
  }
}

/// @nodoc
abstract mixin class $AnalyticsMetricsCopyWith<$Res> {
  factory $AnalyticsMetricsCopyWith(
          AnalyticsMetrics value, $Res Function(AnalyticsMetrics) _then) =
      _$AnalyticsMetricsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      AnalyticsTimeframe timeframe,
      @JsonKey(name: 'base_currency') String baseCurrency,
      @JsonKey(name: 'as_of_date', fromJson: _parseApiDate, toJson: _dateToJson)
      DateTime asOfDate,
      @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
      double riskFreeRate,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
      @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent,
      @JsonKey(name: 'volatility', fromJson: _safeDouble) double volatility,
      @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble) double sharpeRatio,
      @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
      AdvancedRiskMetricsResponse riskAssessment});

  $AdvancedRiskMetricsResponseCopyWith<$Res> get riskAssessment;
}

/// @nodoc
class _$AnalyticsMetricsCopyWithImpl<$Res>
    implements $AnalyticsMetricsCopyWith<$Res> {
  _$AnalyticsMetricsCopyWithImpl(this._self, this._then);

  final AnalyticsMetrics _self;
  final $Res Function(AnalyticsMetrics) _then;

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? portfolioId = null,
    Object? timeframe = null,
    Object? baseCurrency = null,
    Object? asOfDate = null,
    Object? riskFreeRate = null,
    Object? pnl = null,
    Object? roiPercent = null,
    Object? volatility = null,
    Object? sharpeRatio = null,
    Object? riskAssessment = null,
  }) {
    return _then(_self.copyWith(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      timeframe: null == timeframe
          ? _self.timeframe
          : timeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      baseCurrency: null == baseCurrency
          ? _self.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      asOfDate: null == asOfDate
          ? _self.asOfDate
          : asOfDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      riskFreeRate: null == riskFreeRate
          ? _self.riskFreeRate
          : riskFreeRate // ignore: cast_nullable_to_non_nullable
              as double,
      pnl: null == pnl
          ? _self.pnl
          : pnl // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
      volatility: null == volatility
          ? _self.volatility
          : volatility // ignore: cast_nullable_to_non_nullable
              as double,
      sharpeRatio: null == sharpeRatio
          ? _self.sharpeRatio
          : sharpeRatio // ignore: cast_nullable_to_non_nullable
              as double,
      riskAssessment: null == riskAssessment
          ? _self.riskAssessment
          : riskAssessment // ignore: cast_nullable_to_non_nullable
              as AdvancedRiskMetricsResponse,
    ));
  }

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdvancedRiskMetricsResponseCopyWith<$Res> get riskAssessment {
    return $AdvancedRiskMetricsResponseCopyWith<$Res>(_self.riskAssessment,
        (value) {
      return _then(_self.copyWith(riskAssessment: value));
    });
  }
}

/// Adds pattern-matching-related methods to [AnalyticsMetrics].
extension AnalyticsMetricsPatterns on AnalyticsMetrics {
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
    TResult Function(_AnalyticsMetrics value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics() when $default != null:
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
    TResult Function(_AnalyticsMetrics value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics():
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
    TResult? Function(_AnalyticsMetrics value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics() when $default != null:
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(
                name: 'as_of_date',
                fromJson: _parseApiDate,
                toJson: _dateToJson)
            DateTime asOfDate,
            @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
            double riskFreeRate,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent,
            @JsonKey(name: 'volatility', fromJson: _safeDouble)
            double volatility,
            @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
            double sharpeRatio,
            @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
            AdvancedRiskMetricsResponse riskAssessment)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics() when $default != null:
        return $default(
            _that.portfolioId,
            _that.timeframe,
            _that.baseCurrency,
            _that.asOfDate,
            _that.riskFreeRate,
            _that.pnl,
            _that.roiPercent,
            _that.volatility,
            _that.sharpeRatio,
            _that.riskAssessment);
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(
                name: 'as_of_date',
                fromJson: _parseApiDate,
                toJson: _dateToJson)
            DateTime asOfDate,
            @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
            double riskFreeRate,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent,
            @JsonKey(name: 'volatility', fromJson: _safeDouble)
            double volatility,
            @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
            double sharpeRatio,
            @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
            AdvancedRiskMetricsResponse riskAssessment)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics():
        return $default(
            _that.portfolioId,
            _that.timeframe,
            _that.baseCurrency,
            _that.asOfDate,
            _that.riskFreeRate,
            _that.pnl,
            _that.roiPercent,
            _that.volatility,
            _that.sharpeRatio,
            _that.riskAssessment);
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
            @JsonKey(
                name: 'timeframe',
                fromJson: _timeframeFromJson,
                toJson: _timeframeToJson)
            AnalyticsTimeframe timeframe,
            @JsonKey(name: 'base_currency') String baseCurrency,
            @JsonKey(
                name: 'as_of_date',
                fromJson: _parseApiDate,
                toJson: _dateToJson)
            DateTime asOfDate,
            @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
            double riskFreeRate,
            @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
            @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent,
            @JsonKey(name: 'volatility', fromJson: _safeDouble)
            double volatility,
            @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
            double sharpeRatio,
            @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
            AdvancedRiskMetricsResponse riskAssessment)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsMetrics() when $default != null:
        return $default(
            _that.portfolioId,
            _that.timeframe,
            _that.baseCurrency,
            _that.asOfDate,
            _that.riskFreeRate,
            _that.pnl,
            _that.roiPercent,
            _that.volatility,
            _that.sharpeRatio,
            _that.riskAssessment);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AnalyticsMetrics implements AnalyticsMetrics {
  const _AnalyticsMetrics(
      {@JsonKey(name: 'portfolio_id') required this.portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      required this.timeframe,
      @JsonKey(name: 'base_currency') required this.baseCurrency,
      @JsonKey(name: 'as_of_date', fromJson: _parseApiDate, toJson: _dateToJson)
      required this.asOfDate,
      @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
      this.riskFreeRate = 0,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) this.pnl = 0,
      @JsonKey(name: 'roi', fromJson: _safeDouble) this.roiPercent = 0,
      @JsonKey(name: 'volatility', fromJson: _safeDouble) this.volatility = 0,
      @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
      this.sharpeRatio = 0,
      @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
      this.riskAssessment = const AdvancedRiskMetricsResponse()});
  factory _AnalyticsMetrics.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsMetricsFromJson(json);

  @override
  @JsonKey(name: 'portfolio_id')
  final String portfolioId;
  @override
  @JsonKey(
      name: 'timeframe', fromJson: _timeframeFromJson, toJson: _timeframeToJson)
  final AnalyticsTimeframe timeframe;
  @override
  @JsonKey(name: 'base_currency')
  final String baseCurrency;
  @override
  @JsonKey(name: 'as_of_date', fromJson: _parseApiDate, toJson: _dateToJson)
  final DateTime asOfDate;
  @override
  @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
  final double riskFreeRate;
  @override
  @JsonKey(name: 'pnl', fromJson: _safeDouble)
  final double pnl;
  @override
  @JsonKey(name: 'roi', fromJson: _safeDouble)
  final double roiPercent;
  @override
  @JsonKey(name: 'volatility', fromJson: _safeDouble)
  final double volatility;
  @override
  @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble)
  final double sharpeRatio;
  @override
  @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
  final AdvancedRiskMetricsResponse riskAssessment;

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AnalyticsMetricsCopyWith<_AnalyticsMetrics> get copyWith =>
      __$AnalyticsMetricsCopyWithImpl<_AnalyticsMetrics>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AnalyticsMetricsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AnalyticsMetrics &&
            (identical(other.portfolioId, portfolioId) ||
                other.portfolioId == portfolioId) &&
            (identical(other.timeframe, timeframe) ||
                other.timeframe == timeframe) &&
            (identical(other.baseCurrency, baseCurrency) ||
                other.baseCurrency == baseCurrency) &&
            (identical(other.asOfDate, asOfDate) ||
                other.asOfDate == asOfDate) &&
            (identical(other.riskFreeRate, riskFreeRate) ||
                other.riskFreeRate == riskFreeRate) &&
            (identical(other.pnl, pnl) || other.pnl == pnl) &&
            (identical(other.roiPercent, roiPercent) ||
                other.roiPercent == roiPercent) &&
            (identical(other.volatility, volatility) ||
                other.volatility == volatility) &&
            (identical(other.sharpeRatio, sharpeRatio) ||
                other.sharpeRatio == sharpeRatio) &&
            (identical(other.riskAssessment, riskAssessment) ||
                other.riskAssessment == riskAssessment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      portfolioId,
      timeframe,
      baseCurrency,
      asOfDate,
      riskFreeRate,
      pnl,
      roiPercent,
      volatility,
      sharpeRatio,
      riskAssessment);

  @override
  String toString() {
    return 'AnalyticsMetrics(portfolioId: $portfolioId, timeframe: $timeframe, baseCurrency: $baseCurrency, asOfDate: $asOfDate, riskFreeRate: $riskFreeRate, pnl: $pnl, roiPercent: $roiPercent, volatility: $volatility, sharpeRatio: $sharpeRatio, riskAssessment: $riskAssessment)';
  }
}

/// @nodoc
abstract mixin class _$AnalyticsMetricsCopyWith<$Res>
    implements $AnalyticsMetricsCopyWith<$Res> {
  factory _$AnalyticsMetricsCopyWith(
          _AnalyticsMetrics value, $Res Function(_AnalyticsMetrics) _then) =
      __$AnalyticsMetricsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'portfolio_id') String portfolioId,
      @JsonKey(
          name: 'timeframe',
          fromJson: _timeframeFromJson,
          toJson: _timeframeToJson)
      AnalyticsTimeframe timeframe,
      @JsonKey(name: 'base_currency') String baseCurrency,
      @JsonKey(name: 'as_of_date', fromJson: _parseApiDate, toJson: _dateToJson)
      DateTime asOfDate,
      @JsonKey(name: 'risk_free_rate', fromJson: _safeDouble)
      double riskFreeRate,
      @JsonKey(name: 'pnl', fromJson: _safeDouble) double pnl,
      @JsonKey(name: 'roi', fromJson: _safeDouble) double roiPercent,
      @JsonKey(name: 'volatility', fromJson: _safeDouble) double volatility,
      @JsonKey(name: 'sharpe_ratio', fromJson: _safeDouble) double sharpeRatio,
      @JsonKey(name: 'risk_assessment', fromJson: _riskAssessmentFromJson)
      AdvancedRiskMetricsResponse riskAssessment});

  @override
  $AdvancedRiskMetricsResponseCopyWith<$Res> get riskAssessment;
}

/// @nodoc
class __$AnalyticsMetricsCopyWithImpl<$Res>
    implements _$AnalyticsMetricsCopyWith<$Res> {
  __$AnalyticsMetricsCopyWithImpl(this._self, this._then);

  final _AnalyticsMetrics _self;
  final $Res Function(_AnalyticsMetrics) _then;

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? portfolioId = null,
    Object? timeframe = null,
    Object? baseCurrency = null,
    Object? asOfDate = null,
    Object? riskFreeRate = null,
    Object? pnl = null,
    Object? roiPercent = null,
    Object? volatility = null,
    Object? sharpeRatio = null,
    Object? riskAssessment = null,
  }) {
    return _then(_AnalyticsMetrics(
      portfolioId: null == portfolioId
          ? _self.portfolioId
          : portfolioId // ignore: cast_nullable_to_non_nullable
              as String,
      timeframe: null == timeframe
          ? _self.timeframe
          : timeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      baseCurrency: null == baseCurrency
          ? _self.baseCurrency
          : baseCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      asOfDate: null == asOfDate
          ? _self.asOfDate
          : asOfDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      riskFreeRate: null == riskFreeRate
          ? _self.riskFreeRate
          : riskFreeRate // ignore: cast_nullable_to_non_nullable
              as double,
      pnl: null == pnl
          ? _self.pnl
          : pnl // ignore: cast_nullable_to_non_nullable
              as double,
      roiPercent: null == roiPercent
          ? _self.roiPercent
          : roiPercent // ignore: cast_nullable_to_non_nullable
              as double,
      volatility: null == volatility
          ? _self.volatility
          : volatility // ignore: cast_nullable_to_non_nullable
              as double,
      sharpeRatio: null == sharpeRatio
          ? _self.sharpeRatio
          : sharpeRatio // ignore: cast_nullable_to_non_nullable
              as double,
      riskAssessment: null == riskAssessment
          ? _self.riskAssessment
          : riskAssessment // ignore: cast_nullable_to_non_nullable
              as AdvancedRiskMetricsResponse,
    ));
  }

  /// Create a copy of AnalyticsMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdvancedRiskMetricsResponseCopyWith<$Res> get riskAssessment {
    return $AdvancedRiskMetricsResponseCopyWith<$Res>(_self.riskAssessment,
        (value) {
      return _then(_self.copyWith(riskAssessment: value));
    });
  }
}

/// @nodoc
mixin _$AdvancedRiskMetricsResponse {
  @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
  double? get sortinoRatio;
  @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
  double? get maximumDrawdown;
  @JsonKey(name: 'beta', fromJson: _safeNullableDouble)
  double? get beta;
  @JsonKey(name: 'alpha', fromJson: _safeNullableDouble)
  double? get alpha;
  @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
  ValueAtRiskDistribution get valueAtRisk;

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AdvancedRiskMetricsResponseCopyWith<AdvancedRiskMetricsResponse>
      get copyWith => _$AdvancedRiskMetricsResponseCopyWithImpl<
              AdvancedRiskMetricsResponse>(
          this as AdvancedRiskMetricsResponse, _$identity);

  /// Serializes this AdvancedRiskMetricsResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AdvancedRiskMetricsResponse &&
            (identical(other.sortinoRatio, sortinoRatio) ||
                other.sortinoRatio == sortinoRatio) &&
            (identical(other.maximumDrawdown, maximumDrawdown) ||
                other.maximumDrawdown == maximumDrawdown) &&
            (identical(other.beta, beta) || other.beta == beta) &&
            (identical(other.alpha, alpha) || other.alpha == alpha) &&
            (identical(other.valueAtRisk, valueAtRisk) ||
                other.valueAtRisk == valueAtRisk));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sortinoRatio, maximumDrawdown, beta, alpha, valueAtRisk);

  @override
  String toString() {
    return 'AdvancedRiskMetricsResponse(sortinoRatio: $sortinoRatio, maximumDrawdown: $maximumDrawdown, beta: $beta, alpha: $alpha, valueAtRisk: $valueAtRisk)';
  }
}

/// @nodoc
abstract mixin class $AdvancedRiskMetricsResponseCopyWith<$Res> {
  factory $AdvancedRiskMetricsResponseCopyWith(
          AdvancedRiskMetricsResponse value,
          $Res Function(AdvancedRiskMetricsResponse) _then) =
      _$AdvancedRiskMetricsResponseCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
      double? sortinoRatio,
      @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
      double? maximumDrawdown,
      @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
      @JsonKey(name: 'alpha', fromJson: _safeNullableDouble) double? alpha,
      @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
      ValueAtRiskDistribution valueAtRisk});

  $ValueAtRiskDistributionCopyWith<$Res> get valueAtRisk;
}

/// @nodoc
class _$AdvancedRiskMetricsResponseCopyWithImpl<$Res>
    implements $AdvancedRiskMetricsResponseCopyWith<$Res> {
  _$AdvancedRiskMetricsResponseCopyWithImpl(this._self, this._then);

  final AdvancedRiskMetricsResponse _self;
  final $Res Function(AdvancedRiskMetricsResponse) _then;

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sortinoRatio = freezed,
    Object? maximumDrawdown = freezed,
    Object? beta = freezed,
    Object? alpha = freezed,
    Object? valueAtRisk = null,
  }) {
    return _then(_self.copyWith(
      sortinoRatio: freezed == sortinoRatio
          ? _self.sortinoRatio
          : sortinoRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      maximumDrawdown: freezed == maximumDrawdown
          ? _self.maximumDrawdown
          : maximumDrawdown // ignore: cast_nullable_to_non_nullable
              as double?,
      beta: freezed == beta
          ? _self.beta
          : beta // ignore: cast_nullable_to_non_nullable
              as double?,
      alpha: freezed == alpha
          ? _self.alpha
          : alpha // ignore: cast_nullable_to_non_nullable
              as double?,
      valueAtRisk: null == valueAtRisk
          ? _self.valueAtRisk
          : valueAtRisk // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskDistribution,
    ));
  }

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskDistributionCopyWith<$Res> get valueAtRisk {
    return $ValueAtRiskDistributionCopyWith<$Res>(_self.valueAtRisk, (value) {
      return _then(_self.copyWith(valueAtRisk: value));
    });
  }
}

/// Adds pattern-matching-related methods to [AdvancedRiskMetricsResponse].
extension AdvancedRiskMetricsResponsePatterns on AdvancedRiskMetricsResponse {
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
    TResult Function(_AdvancedRiskMetricsResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse() when $default != null:
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
    TResult Function(_AdvancedRiskMetricsResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse():
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
    TResult? Function(_AdvancedRiskMetricsResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse() when $default != null:
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
            @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
            double? sortinoRatio,
            @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
            double? maximumDrawdown,
            @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
            @JsonKey(name: 'alpha', fromJson: _safeNullableDouble)
            double? alpha,
            @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
            ValueAtRiskDistribution valueAtRisk)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse() when $default != null:
        return $default(_that.sortinoRatio, _that.maximumDrawdown, _that.beta,
            _that.alpha, _that.valueAtRisk);
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
            @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
            double? sortinoRatio,
            @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
            double? maximumDrawdown,
            @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
            @JsonKey(name: 'alpha', fromJson: _safeNullableDouble)
            double? alpha,
            @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
            ValueAtRiskDistribution valueAtRisk)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse():
        return $default(_that.sortinoRatio, _that.maximumDrawdown, _that.beta,
            _that.alpha, _that.valueAtRisk);
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
            @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
            double? sortinoRatio,
            @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
            double? maximumDrawdown,
            @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
            @JsonKey(name: 'alpha', fromJson: _safeNullableDouble)
            double? alpha,
            @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
            ValueAtRiskDistribution valueAtRisk)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdvancedRiskMetricsResponse() when $default != null:
        return $default(_that.sortinoRatio, _that.maximumDrawdown, _that.beta,
            _that.alpha, _that.valueAtRisk);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AdvancedRiskMetricsResponse implements AdvancedRiskMetricsResponse {
  const _AdvancedRiskMetricsResponse(
      {@JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
      this.sortinoRatio,
      @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
      this.maximumDrawdown,
      @JsonKey(name: 'beta', fromJson: _safeNullableDouble) this.beta,
      @JsonKey(name: 'alpha', fromJson: _safeNullableDouble) this.alpha,
      @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
      this.valueAtRisk = const ValueAtRiskDistribution()});
  factory _AdvancedRiskMetricsResponse.fromJson(Map<String, dynamic> json) =>
      _$AdvancedRiskMetricsResponseFromJson(json);

  @override
  @JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
  final double? sortinoRatio;
  @override
  @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
  final double? maximumDrawdown;
  @override
  @JsonKey(name: 'beta', fromJson: _safeNullableDouble)
  final double? beta;
  @override
  @JsonKey(name: 'alpha', fromJson: _safeNullableDouble)
  final double? alpha;
  @override
  @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
  final ValueAtRiskDistribution valueAtRisk;

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AdvancedRiskMetricsResponseCopyWith<_AdvancedRiskMetricsResponse>
      get copyWith => __$AdvancedRiskMetricsResponseCopyWithImpl<
          _AdvancedRiskMetricsResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AdvancedRiskMetricsResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AdvancedRiskMetricsResponse &&
            (identical(other.sortinoRatio, sortinoRatio) ||
                other.sortinoRatio == sortinoRatio) &&
            (identical(other.maximumDrawdown, maximumDrawdown) ||
                other.maximumDrawdown == maximumDrawdown) &&
            (identical(other.beta, beta) || other.beta == beta) &&
            (identical(other.alpha, alpha) || other.alpha == alpha) &&
            (identical(other.valueAtRisk, valueAtRisk) ||
                other.valueAtRisk == valueAtRisk));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, sortinoRatio, maximumDrawdown, beta, alpha, valueAtRisk);

  @override
  String toString() {
    return 'AdvancedRiskMetricsResponse(sortinoRatio: $sortinoRatio, maximumDrawdown: $maximumDrawdown, beta: $beta, alpha: $alpha, valueAtRisk: $valueAtRisk)';
  }
}

/// @nodoc
abstract mixin class _$AdvancedRiskMetricsResponseCopyWith<$Res>
    implements $AdvancedRiskMetricsResponseCopyWith<$Res> {
  factory _$AdvancedRiskMetricsResponseCopyWith(
          _AdvancedRiskMetricsResponse value,
          $Res Function(_AdvancedRiskMetricsResponse) _then) =
      __$AdvancedRiskMetricsResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'sortino_ratio', fromJson: _safeNullableDouble)
      double? sortinoRatio,
      @JsonKey(name: 'maximum_drawdown', fromJson: _safeNullableDouble)
      double? maximumDrawdown,
      @JsonKey(name: 'beta', fromJson: _safeNullableDouble) double? beta,
      @JsonKey(name: 'alpha', fromJson: _safeNullableDouble) double? alpha,
      @JsonKey(name: 'value_at_risk', fromJson: _valueAtRiskFromJson)
      ValueAtRiskDistribution valueAtRisk});

  @override
  $ValueAtRiskDistributionCopyWith<$Res> get valueAtRisk;
}

/// @nodoc
class __$AdvancedRiskMetricsResponseCopyWithImpl<$Res>
    implements _$AdvancedRiskMetricsResponseCopyWith<$Res> {
  __$AdvancedRiskMetricsResponseCopyWithImpl(this._self, this._then);

  final _AdvancedRiskMetricsResponse _self;
  final $Res Function(_AdvancedRiskMetricsResponse) _then;

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sortinoRatio = freezed,
    Object? maximumDrawdown = freezed,
    Object? beta = freezed,
    Object? alpha = freezed,
    Object? valueAtRisk = null,
  }) {
    return _then(_AdvancedRiskMetricsResponse(
      sortinoRatio: freezed == sortinoRatio
          ? _self.sortinoRatio
          : sortinoRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      maximumDrawdown: freezed == maximumDrawdown
          ? _self.maximumDrawdown
          : maximumDrawdown // ignore: cast_nullable_to_non_nullable
              as double?,
      beta: freezed == beta
          ? _self.beta
          : beta // ignore: cast_nullable_to_non_nullable
              as double?,
      alpha: freezed == alpha
          ? _self.alpha
          : alpha // ignore: cast_nullable_to_non_nullable
              as double?,
      valueAtRisk: null == valueAtRisk
          ? _self.valueAtRisk
          : valueAtRisk // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskDistribution,
    ));
  }

  /// Create a copy of AdvancedRiskMetricsResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskDistributionCopyWith<$Res> get valueAtRisk {
    return $ValueAtRiskDistributionCopyWith<$Res>(_self.valueAtRisk, (value) {
      return _then(_self.copyWith(valueAtRisk: value));
    });
  }
}

/// @nodoc
mixin _$ValueAtRiskDistribution {
  @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
  ValueAtRiskBand get historical;
  @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
  ValueAtRiskBand get parametric;

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ValueAtRiskDistributionCopyWith<ValueAtRiskDistribution> get copyWith =>
      _$ValueAtRiskDistributionCopyWithImpl<ValueAtRiskDistribution>(
          this as ValueAtRiskDistribution, _$identity);

  /// Serializes this ValueAtRiskDistribution to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ValueAtRiskDistribution &&
            (identical(other.historical, historical) ||
                other.historical == historical) &&
            (identical(other.parametric, parametric) ||
                other.parametric == parametric));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, historical, parametric);

  @override
  String toString() {
    return 'ValueAtRiskDistribution(historical: $historical, parametric: $parametric)';
  }
}

/// @nodoc
abstract mixin class $ValueAtRiskDistributionCopyWith<$Res> {
  factory $ValueAtRiskDistributionCopyWith(ValueAtRiskDistribution value,
          $Res Function(ValueAtRiskDistribution) _then) =
      _$ValueAtRiskDistributionCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
      ValueAtRiskBand historical,
      @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
      ValueAtRiskBand parametric});

  $ValueAtRiskBandCopyWith<$Res> get historical;
  $ValueAtRiskBandCopyWith<$Res> get parametric;
}

/// @nodoc
class _$ValueAtRiskDistributionCopyWithImpl<$Res>
    implements $ValueAtRiskDistributionCopyWith<$Res> {
  _$ValueAtRiskDistributionCopyWithImpl(this._self, this._then);

  final ValueAtRiskDistribution _self;
  final $Res Function(ValueAtRiskDistribution) _then;

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? historical = null,
    Object? parametric = null,
  }) {
    return _then(_self.copyWith(
      historical: null == historical
          ? _self.historical
          : historical // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskBand,
      parametric: null == parametric
          ? _self.parametric
          : parametric // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskBand,
    ));
  }

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskBandCopyWith<$Res> get historical {
    return $ValueAtRiskBandCopyWith<$Res>(_self.historical, (value) {
      return _then(_self.copyWith(historical: value));
    });
  }

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskBandCopyWith<$Res> get parametric {
    return $ValueAtRiskBandCopyWith<$Res>(_self.parametric, (value) {
      return _then(_self.copyWith(parametric: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ValueAtRiskDistribution].
extension ValueAtRiskDistributionPatterns on ValueAtRiskDistribution {
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
    TResult Function(_ValueAtRiskDistribution value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution() when $default != null:
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
    TResult Function(_ValueAtRiskDistribution value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution():
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
    TResult? Function(_ValueAtRiskDistribution value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution() when $default != null:
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
            @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand historical,
            @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand parametric)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution() when $default != null:
        return $default(_that.historical, _that.parametric);
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
            @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand historical,
            @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand parametric)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution():
        return $default(_that.historical, _that.parametric);
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
            @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand historical,
            @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
            ValueAtRiskBand parametric)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskDistribution() when $default != null:
        return $default(_that.historical, _that.parametric);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ValueAtRiskDistribution implements ValueAtRiskDistribution {
  const _ValueAtRiskDistribution(
      {@JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
      this.historical = const ValueAtRiskBand(),
      @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
      this.parametric = const ValueAtRiskBand()});
  factory _ValueAtRiskDistribution.fromJson(Map<String, dynamic> json) =>
      _$ValueAtRiskDistributionFromJson(json);

  @override
  @JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
  final ValueAtRiskBand historical;
  @override
  @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
  final ValueAtRiskBand parametric;

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ValueAtRiskDistributionCopyWith<_ValueAtRiskDistribution> get copyWith =>
      __$ValueAtRiskDistributionCopyWithImpl<_ValueAtRiskDistribution>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ValueAtRiskDistributionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ValueAtRiskDistribution &&
            (identical(other.historical, historical) ||
                other.historical == historical) &&
            (identical(other.parametric, parametric) ||
                other.parametric == parametric));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, historical, parametric);

  @override
  String toString() {
    return 'ValueAtRiskDistribution(historical: $historical, parametric: $parametric)';
  }
}

/// @nodoc
abstract mixin class _$ValueAtRiskDistributionCopyWith<$Res>
    implements $ValueAtRiskDistributionCopyWith<$Res> {
  factory _$ValueAtRiskDistributionCopyWith(_ValueAtRiskDistribution value,
          $Res Function(_ValueAtRiskDistribution) _then) =
      __$ValueAtRiskDistributionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'historical', fromJson: _valueAtRiskBandFromJson)
      ValueAtRiskBand historical,
      @JsonKey(name: 'parametric', fromJson: _valueAtRiskBandFromJson)
      ValueAtRiskBand parametric});

  @override
  $ValueAtRiskBandCopyWith<$Res> get historical;
  @override
  $ValueAtRiskBandCopyWith<$Res> get parametric;
}

/// @nodoc
class __$ValueAtRiskDistributionCopyWithImpl<$Res>
    implements _$ValueAtRiskDistributionCopyWith<$Res> {
  __$ValueAtRiskDistributionCopyWithImpl(this._self, this._then);

  final _ValueAtRiskDistribution _self;
  final $Res Function(_ValueAtRiskDistribution) _then;

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? historical = null,
    Object? parametric = null,
  }) {
    return _then(_ValueAtRiskDistribution(
      historical: null == historical
          ? _self.historical
          : historical // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskBand,
      parametric: null == parametric
          ? _self.parametric
          : parametric // ignore: cast_nullable_to_non_nullable
              as ValueAtRiskBand,
    ));
  }

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskBandCopyWith<$Res> get historical {
    return $ValueAtRiskBandCopyWith<$Res>(_self.historical, (value) {
      return _then(_self.copyWith(historical: value));
    });
  }

  /// Create a copy of ValueAtRiskDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ValueAtRiskBandCopyWith<$Res> get parametric {
    return $ValueAtRiskBandCopyWith<$Res>(_self.parametric, (value) {
      return _then(_self.copyWith(parametric: value));
    });
  }
}

/// @nodoc
mixin _$ValueAtRiskBand {
  @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
  double? get confidence95;
  @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
  double? get confidence99;

  /// Create a copy of ValueAtRiskBand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ValueAtRiskBandCopyWith<ValueAtRiskBand> get copyWith =>
      _$ValueAtRiskBandCopyWithImpl<ValueAtRiskBand>(
          this as ValueAtRiskBand, _$identity);

  /// Serializes this ValueAtRiskBand to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ValueAtRiskBand &&
            (identical(other.confidence95, confidence95) ||
                other.confidence95 == confidence95) &&
            (identical(other.confidence99, confidence99) ||
                other.confidence99 == confidence99));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, confidence95, confidence99);

  @override
  String toString() {
    return 'ValueAtRiskBand(confidence95: $confidence95, confidence99: $confidence99)';
  }
}

/// @nodoc
abstract mixin class $ValueAtRiskBandCopyWith<$Res> {
  factory $ValueAtRiskBandCopyWith(
          ValueAtRiskBand value, $Res Function(ValueAtRiskBand) _then) =
      _$ValueAtRiskBandCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
      double? confidence95,
      @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
      double? confidence99});
}

/// @nodoc
class _$ValueAtRiskBandCopyWithImpl<$Res>
    implements $ValueAtRiskBandCopyWith<$Res> {
  _$ValueAtRiskBandCopyWithImpl(this._self, this._then);

  final ValueAtRiskBand _self;
  final $Res Function(ValueAtRiskBand) _then;

  /// Create a copy of ValueAtRiskBand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? confidence95 = freezed,
    Object? confidence99 = freezed,
  }) {
    return _then(_self.copyWith(
      confidence95: freezed == confidence95
          ? _self.confidence95
          : confidence95 // ignore: cast_nullable_to_non_nullable
              as double?,
      confidence99: freezed == confidence99
          ? _self.confidence99
          : confidence99 // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ValueAtRiskBand].
extension ValueAtRiskBandPatterns on ValueAtRiskBand {
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
    TResult Function(_ValueAtRiskBand value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand() when $default != null:
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
    TResult Function(_ValueAtRiskBand value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand():
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
    TResult? Function(_ValueAtRiskBand value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand() when $default != null:
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
            @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
            double? confidence95,
            @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
            double? confidence99)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand() when $default != null:
        return $default(_that.confidence95, _that.confidence99);
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
            @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
            double? confidence95,
            @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
            double? confidence99)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand():
        return $default(_that.confidence95, _that.confidence99);
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
            @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
            double? confidence95,
            @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
            double? confidence99)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ValueAtRiskBand() when $default != null:
        return $default(_that.confidence95, _that.confidence99);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ValueAtRiskBand implements ValueAtRiskBand {
  const _ValueAtRiskBand(
      {@JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
      this.confidence95,
      @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
      this.confidence99});
  factory _ValueAtRiskBand.fromJson(Map<String, dynamic> json) =>
      _$ValueAtRiskBandFromJson(json);

  @override
  @JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
  final double? confidence95;
  @override
  @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
  final double? confidence99;

  /// Create a copy of ValueAtRiskBand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ValueAtRiskBandCopyWith<_ValueAtRiskBand> get copyWith =>
      __$ValueAtRiskBandCopyWithImpl<_ValueAtRiskBand>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ValueAtRiskBandToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ValueAtRiskBand &&
            (identical(other.confidence95, confidence95) ||
                other.confidence95 == confidence95) &&
            (identical(other.confidence99, confidence99) ||
                other.confidence99 == confidence99));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, confidence95, confidence99);

  @override
  String toString() {
    return 'ValueAtRiskBand(confidence95: $confidence95, confidence99: $confidence99)';
  }
}

/// @nodoc
abstract mixin class _$ValueAtRiskBandCopyWith<$Res>
    implements $ValueAtRiskBandCopyWith<$Res> {
  factory _$ValueAtRiskBandCopyWith(
          _ValueAtRiskBand value, $Res Function(_ValueAtRiskBand) _then) =
      __$ValueAtRiskBandCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'confidence_95', fromJson: _safeNullableDouble)
      double? confidence95,
      @JsonKey(name: 'confidence_99', fromJson: _safeNullableDouble)
      double? confidence99});
}

/// @nodoc
class __$ValueAtRiskBandCopyWithImpl<$Res>
    implements _$ValueAtRiskBandCopyWith<$Res> {
  __$ValueAtRiskBandCopyWithImpl(this._self, this._then);

  final _ValueAtRiskBand _self;
  final $Res Function(_ValueAtRiskBand) _then;

  /// Create a copy of ValueAtRiskBand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? confidence95 = freezed,
    Object? confidence99 = freezed,
  }) {
    return _then(_ValueAtRiskBand(
      confidence95: freezed == confidence95
          ? _self.confidence95
          : confidence95 // ignore: cast_nullable_to_non_nullable
              as double?,
      confidence99: freezed == confidence99
          ? _self.confidence99
          : confidence99 // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
mixin _$AnalyticsAllocationSlice {
  String get ticker;
  @JsonKey(fromJson: _safeDouble)
  double get percentage;
  @JsonKey(fromJson: _safeDouble)
  double get value;

  /// Create a copy of AnalyticsAllocationSlice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AnalyticsAllocationSliceCopyWith<AnalyticsAllocationSlice> get copyWith =>
      _$AnalyticsAllocationSliceCopyWithImpl<AnalyticsAllocationSlice>(
          this as AnalyticsAllocationSlice, _$identity);

  /// Serializes this AnalyticsAllocationSlice to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AnalyticsAllocationSlice &&
            (identical(other.ticker, ticker) || other.ticker == ticker) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, ticker, percentage, value);

  @override
  String toString() {
    return 'AnalyticsAllocationSlice(ticker: $ticker, percentage: $percentage, value: $value)';
  }
}

/// @nodoc
abstract mixin class $AnalyticsAllocationSliceCopyWith<$Res> {
  factory $AnalyticsAllocationSliceCopyWith(AnalyticsAllocationSlice value,
          $Res Function(AnalyticsAllocationSlice) _then) =
      _$AnalyticsAllocationSliceCopyWithImpl;
  @useResult
  $Res call(
      {String ticker,
      @JsonKey(fromJson: _safeDouble) double percentage,
      @JsonKey(fromJson: _safeDouble) double value});
}

/// @nodoc
class _$AnalyticsAllocationSliceCopyWithImpl<$Res>
    implements $AnalyticsAllocationSliceCopyWith<$Res> {
  _$AnalyticsAllocationSliceCopyWithImpl(this._self, this._then);

  final AnalyticsAllocationSlice _self;
  final $Res Function(AnalyticsAllocationSlice) _then;

  /// Create a copy of AnalyticsAllocationSlice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ticker = null,
    Object? percentage = null,
    Object? value = null,
  }) {
    return _then(_self.copyWith(
      ticker: null == ticker
          ? _self.ticker
          : ticker // ignore: cast_nullable_to_non_nullable
              as String,
      percentage: null == percentage
          ? _self.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [AnalyticsAllocationSlice].
extension AnalyticsAllocationSlicePatterns on AnalyticsAllocationSlice {
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
    TResult Function(_AnalyticsAllocationSlice value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice() when $default != null:
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
    TResult Function(_AnalyticsAllocationSlice value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice():
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
    TResult? Function(_AnalyticsAllocationSlice value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice() when $default != null:
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
            String ticker,
            @JsonKey(fromJson: _safeDouble) double percentage,
            @JsonKey(fromJson: _safeDouble) double value)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice() when $default != null:
        return $default(_that.ticker, _that.percentage, _that.value);
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
            String ticker,
            @JsonKey(fromJson: _safeDouble) double percentage,
            @JsonKey(fromJson: _safeDouble) double value)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice():
        return $default(_that.ticker, _that.percentage, _that.value);
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
            String ticker,
            @JsonKey(fromJson: _safeDouble) double percentage,
            @JsonKey(fromJson: _safeDouble) double value)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsAllocationSlice() when $default != null:
        return $default(_that.ticker, _that.percentage, _that.value);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AnalyticsAllocationSlice implements AnalyticsAllocationSlice {
  const _AnalyticsAllocationSlice(
      {required this.ticker,
      @JsonKey(fromJson: _safeDouble) this.percentage = 0,
      @JsonKey(fromJson: _safeDouble) this.value = 0});
  factory _AnalyticsAllocationSlice.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsAllocationSliceFromJson(json);

  @override
  final String ticker;
  @override
  @JsonKey(fromJson: _safeDouble)
  final double percentage;
  @override
  @JsonKey(fromJson: _safeDouble)
  final double value;

  /// Create a copy of AnalyticsAllocationSlice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AnalyticsAllocationSliceCopyWith<_AnalyticsAllocationSlice> get copyWith =>
      __$AnalyticsAllocationSliceCopyWithImpl<_AnalyticsAllocationSlice>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AnalyticsAllocationSliceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AnalyticsAllocationSlice &&
            (identical(other.ticker, ticker) || other.ticker == ticker) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, ticker, percentage, value);

  @override
  String toString() {
    return 'AnalyticsAllocationSlice(ticker: $ticker, percentage: $percentage, value: $value)';
  }
}

/// @nodoc
abstract mixin class _$AnalyticsAllocationSliceCopyWith<$Res>
    implements $AnalyticsAllocationSliceCopyWith<$Res> {
  factory _$AnalyticsAllocationSliceCopyWith(_AnalyticsAllocationSlice value,
          $Res Function(_AnalyticsAllocationSlice) _then) =
      __$AnalyticsAllocationSliceCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String ticker,
      @JsonKey(fromJson: _safeDouble) double percentage,
      @JsonKey(fromJson: _safeDouble) double value});
}

/// @nodoc
class __$AnalyticsAllocationSliceCopyWithImpl<$Res>
    implements _$AnalyticsAllocationSliceCopyWith<$Res> {
  __$AnalyticsAllocationSliceCopyWithImpl(this._self, this._then);

  final _AnalyticsAllocationSlice _self;
  final $Res Function(_AnalyticsAllocationSlice) _then;

  /// Create a copy of AnalyticsAllocationSlice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? ticker = null,
    Object? percentage = null,
    Object? value = null,
  }) {
    return _then(_AnalyticsAllocationSlice(
      ticker: null == ticker
          ? _self.ticker
          : ticker // ignore: cast_nullable_to_non_nullable
              as String,
      percentage: null == percentage
          ? _self.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$AnalyticsViewState {
  AnalyticsTimeframe get selectedTimeframe;
  AnalyticsPerformanceSeries get performanceSeries;
  AnalyticsMetrics get metrics;
  List<AnalyticsAllocationSlice> get allocation;

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AnalyticsViewStateCopyWith<AnalyticsViewState> get copyWith =>
      _$AnalyticsViewStateCopyWithImpl<AnalyticsViewState>(
          this as AnalyticsViewState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AnalyticsViewState &&
            (identical(other.selectedTimeframe, selectedTimeframe) ||
                other.selectedTimeframe == selectedTimeframe) &&
            (identical(other.performanceSeries, performanceSeries) ||
                other.performanceSeries == performanceSeries) &&
            (identical(other.metrics, metrics) || other.metrics == metrics) &&
            const DeepCollectionEquality()
                .equals(other.allocation, allocation));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedTimeframe,
      performanceSeries,
      metrics,
      const DeepCollectionEquality().hash(allocation));

  @override
  String toString() {
    return 'AnalyticsViewState(selectedTimeframe: $selectedTimeframe, performanceSeries: $performanceSeries, metrics: $metrics, allocation: $allocation)';
  }
}

/// @nodoc
abstract mixin class $AnalyticsViewStateCopyWith<$Res> {
  factory $AnalyticsViewStateCopyWith(
          AnalyticsViewState value, $Res Function(AnalyticsViewState) _then) =
      _$AnalyticsViewStateCopyWithImpl;
  @useResult
  $Res call(
      {AnalyticsTimeframe selectedTimeframe,
      AnalyticsPerformanceSeries performanceSeries,
      AnalyticsMetrics metrics,
      List<AnalyticsAllocationSlice> allocation});

  $AnalyticsPerformanceSeriesCopyWith<$Res> get performanceSeries;
  $AnalyticsMetricsCopyWith<$Res> get metrics;
}

/// @nodoc
class _$AnalyticsViewStateCopyWithImpl<$Res>
    implements $AnalyticsViewStateCopyWith<$Res> {
  _$AnalyticsViewStateCopyWithImpl(this._self, this._then);

  final AnalyticsViewState _self;
  final $Res Function(AnalyticsViewState) _then;

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedTimeframe = null,
    Object? performanceSeries = null,
    Object? metrics = null,
    Object? allocation = null,
  }) {
    return _then(_self.copyWith(
      selectedTimeframe: null == selectedTimeframe
          ? _self.selectedTimeframe
          : selectedTimeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      performanceSeries: null == performanceSeries
          ? _self.performanceSeries
          : performanceSeries // ignore: cast_nullable_to_non_nullable
              as AnalyticsPerformanceSeries,
      metrics: null == metrics
          ? _self.metrics
          : metrics // ignore: cast_nullable_to_non_nullable
              as AnalyticsMetrics,
      allocation: null == allocation
          ? _self.allocation
          : allocation // ignore: cast_nullable_to_non_nullable
              as List<AnalyticsAllocationSlice>,
    ));
  }

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnalyticsPerformanceSeriesCopyWith<$Res> get performanceSeries {
    return $AnalyticsPerformanceSeriesCopyWith<$Res>(_self.performanceSeries,
        (value) {
      return _then(_self.copyWith(performanceSeries: value));
    });
  }

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnalyticsMetricsCopyWith<$Res> get metrics {
    return $AnalyticsMetricsCopyWith<$Res>(_self.metrics, (value) {
      return _then(_self.copyWith(metrics: value));
    });
  }
}

/// Adds pattern-matching-related methods to [AnalyticsViewState].
extension AnalyticsViewStatePatterns on AnalyticsViewState {
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
    TResult Function(_AnalyticsViewState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState() when $default != null:
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
    TResult Function(_AnalyticsViewState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState():
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
    TResult? Function(_AnalyticsViewState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState() when $default != null:
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
            AnalyticsTimeframe selectedTimeframe,
            AnalyticsPerformanceSeries performanceSeries,
            AnalyticsMetrics metrics,
            List<AnalyticsAllocationSlice> allocation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState() when $default != null:
        return $default(_that.selectedTimeframe, _that.performanceSeries,
            _that.metrics, _that.allocation);
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
            AnalyticsTimeframe selectedTimeframe,
            AnalyticsPerformanceSeries performanceSeries,
            AnalyticsMetrics metrics,
            List<AnalyticsAllocationSlice> allocation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState():
        return $default(_that.selectedTimeframe, _that.performanceSeries,
            _that.metrics, _that.allocation);
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
            AnalyticsTimeframe selectedTimeframe,
            AnalyticsPerformanceSeries performanceSeries,
            AnalyticsMetrics metrics,
            List<AnalyticsAllocationSlice> allocation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AnalyticsViewState() when $default != null:
        return $default(_that.selectedTimeframe, _that.performanceSeries,
            _that.metrics, _that.allocation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AnalyticsViewState implements AnalyticsViewState {
  const _AnalyticsViewState(
      {required this.selectedTimeframe,
      required this.performanceSeries,
      required this.metrics,
      final List<AnalyticsAllocationSlice> allocation =
          const <AnalyticsAllocationSlice>[]})
      : _allocation = allocation;

  @override
  final AnalyticsTimeframe selectedTimeframe;
  @override
  final AnalyticsPerformanceSeries performanceSeries;
  @override
  final AnalyticsMetrics metrics;
  final List<AnalyticsAllocationSlice> _allocation;
  @override
  @JsonKey()
  List<AnalyticsAllocationSlice> get allocation {
    if (_allocation is EqualUnmodifiableListView) return _allocation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allocation);
  }

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AnalyticsViewStateCopyWith<_AnalyticsViewState> get copyWith =>
      __$AnalyticsViewStateCopyWithImpl<_AnalyticsViewState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AnalyticsViewState &&
            (identical(other.selectedTimeframe, selectedTimeframe) ||
                other.selectedTimeframe == selectedTimeframe) &&
            (identical(other.performanceSeries, performanceSeries) ||
                other.performanceSeries == performanceSeries) &&
            (identical(other.metrics, metrics) || other.metrics == metrics) &&
            const DeepCollectionEquality()
                .equals(other._allocation, _allocation));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedTimeframe,
      performanceSeries,
      metrics,
      const DeepCollectionEquality().hash(_allocation));

  @override
  String toString() {
    return 'AnalyticsViewState(selectedTimeframe: $selectedTimeframe, performanceSeries: $performanceSeries, metrics: $metrics, allocation: $allocation)';
  }
}

/// @nodoc
abstract mixin class _$AnalyticsViewStateCopyWith<$Res>
    implements $AnalyticsViewStateCopyWith<$Res> {
  factory _$AnalyticsViewStateCopyWith(
          _AnalyticsViewState value, $Res Function(_AnalyticsViewState) _then) =
      __$AnalyticsViewStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {AnalyticsTimeframe selectedTimeframe,
      AnalyticsPerformanceSeries performanceSeries,
      AnalyticsMetrics metrics,
      List<AnalyticsAllocationSlice> allocation});

  @override
  $AnalyticsPerformanceSeriesCopyWith<$Res> get performanceSeries;
  @override
  $AnalyticsMetricsCopyWith<$Res> get metrics;
}

/// @nodoc
class __$AnalyticsViewStateCopyWithImpl<$Res>
    implements _$AnalyticsViewStateCopyWith<$Res> {
  __$AnalyticsViewStateCopyWithImpl(this._self, this._then);

  final _AnalyticsViewState _self;
  final $Res Function(_AnalyticsViewState) _then;

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedTimeframe = null,
    Object? performanceSeries = null,
    Object? metrics = null,
    Object? allocation = null,
  }) {
    return _then(_AnalyticsViewState(
      selectedTimeframe: null == selectedTimeframe
          ? _self.selectedTimeframe
          : selectedTimeframe // ignore: cast_nullable_to_non_nullable
              as AnalyticsTimeframe,
      performanceSeries: null == performanceSeries
          ? _self.performanceSeries
          : performanceSeries // ignore: cast_nullable_to_non_nullable
              as AnalyticsPerformanceSeries,
      metrics: null == metrics
          ? _self.metrics
          : metrics // ignore: cast_nullable_to_non_nullable
              as AnalyticsMetrics,
      allocation: null == allocation
          ? _self._allocation
          : allocation // ignore: cast_nullable_to_non_nullable
              as List<AnalyticsAllocationSlice>,
    ));
  }

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnalyticsPerformanceSeriesCopyWith<$Res> get performanceSeries {
    return $AnalyticsPerformanceSeriesCopyWith<$Res>(_self.performanceSeries,
        (value) {
      return _then(_self.copyWith(performanceSeries: value));
    });
  }

  /// Create a copy of AnalyticsViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnalyticsMetricsCopyWith<$Res> get metrics {
    return $AnalyticsMetricsCopyWith<$Res>(_self.metrics, (value) {
      return _then(_self.copyWith(metrics: value));
    });
  }
}

// dart format on
