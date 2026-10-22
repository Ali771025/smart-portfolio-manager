// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'import_report_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImportReportModel {
  @JsonKey(name: 'inserted_count', fromJson: _toInt)
  int get insertedCount;
  @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
  int get duplicatesSkippedCount;
  @JsonKey(name: 'failed_count', fromJson: _toInt)
  int get failedCount;
  List<RowErrorModel> get errors;
  @JsonKey(name: 'inserted_reference_hashes')
  List<String> get insertedReferenceHashes;
  Map<String, dynamic> get analysis;
  Map<String, dynamic>? get job;

  /// Create a copy of ImportReportModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImportReportModelCopyWith<ImportReportModel> get copyWith =>
      _$ImportReportModelCopyWithImpl<ImportReportModel>(
          this as ImportReportModel, _$identity);

  /// Serializes this ImportReportModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImportReportModel &&
            (identical(other.insertedCount, insertedCount) ||
                other.insertedCount == insertedCount) &&
            (identical(other.duplicatesSkippedCount, duplicatesSkippedCount) ||
                other.duplicatesSkippedCount == duplicatesSkippedCount) &&
            (identical(other.failedCount, failedCount) ||
                other.failedCount == failedCount) &&
            const DeepCollectionEquality().equals(other.errors, errors) &&
            const DeepCollectionEquality().equals(
                other.insertedReferenceHashes, insertedReferenceHashes) &&
            const DeepCollectionEquality().equals(other.analysis, analysis) &&
            const DeepCollectionEquality().equals(other.job, job));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      insertedCount,
      duplicatesSkippedCount,
      failedCount,
      const DeepCollectionEquality().hash(errors),
      const DeepCollectionEquality().hash(insertedReferenceHashes),
      const DeepCollectionEquality().hash(analysis),
      const DeepCollectionEquality().hash(job));

  @override
  String toString() {
    return 'ImportReportModel(insertedCount: $insertedCount, duplicatesSkippedCount: $duplicatesSkippedCount, failedCount: $failedCount, errors: $errors, insertedReferenceHashes: $insertedReferenceHashes, analysis: $analysis, job: $job)';
  }
}

/// @nodoc
abstract mixin class $ImportReportModelCopyWith<$Res> {
  factory $ImportReportModelCopyWith(
          ImportReportModel value, $Res Function(ImportReportModel) _then) =
      _$ImportReportModelCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'inserted_count', fromJson: _toInt) int insertedCount,
      @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
      int duplicatesSkippedCount,
      @JsonKey(name: 'failed_count', fromJson: _toInt) int failedCount,
      List<RowErrorModel> errors,
      @JsonKey(name: 'inserted_reference_hashes')
      List<String> insertedReferenceHashes,
      Map<String, dynamic> analysis,
      Map<String, dynamic>? job});
}

/// @nodoc
class _$ImportReportModelCopyWithImpl<$Res>
    implements $ImportReportModelCopyWith<$Res> {
  _$ImportReportModelCopyWithImpl(this._self, this._then);

  final ImportReportModel _self;
  final $Res Function(ImportReportModel) _then;

  /// Create a copy of ImportReportModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? insertedCount = null,
    Object? duplicatesSkippedCount = null,
    Object? failedCount = null,
    Object? errors = null,
    Object? insertedReferenceHashes = null,
    Object? analysis = null,
    Object? job = freezed,
  }) {
    return _then(_self.copyWith(
      insertedCount: null == insertedCount
          ? _self.insertedCount
          : insertedCount // ignore: cast_nullable_to_non_nullable
              as int,
      duplicatesSkippedCount: null == duplicatesSkippedCount
          ? _self.duplicatesSkippedCount
          : duplicatesSkippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _self.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      errors: null == errors
          ? _self.errors
          : errors // ignore: cast_nullable_to_non_nullable
              as List<RowErrorModel>,
      insertedReferenceHashes: null == insertedReferenceHashes
          ? _self.insertedReferenceHashes
          : insertedReferenceHashes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      analysis: null == analysis
          ? _self.analysis
          : analysis // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      job: freezed == job
          ? _self.job
          : job // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ImportReportModel].
extension ImportReportModelPatterns on ImportReportModel {
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
    TResult Function(_ImportReportModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel() when $default != null:
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
    TResult Function(_ImportReportModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel():
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
    TResult? Function(_ImportReportModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel() when $default != null:
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
            @JsonKey(name: 'inserted_count', fromJson: _toInt)
            int insertedCount,
            @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
            int duplicatesSkippedCount,
            @JsonKey(name: 'failed_count', fromJson: _toInt) int failedCount,
            List<RowErrorModel> errors,
            @JsonKey(name: 'inserted_reference_hashes')
            List<String> insertedReferenceHashes,
            Map<String, dynamic> analysis,
            Map<String, dynamic>? job)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel() when $default != null:
        return $default(
            _that.insertedCount,
            _that.duplicatesSkippedCount,
            _that.failedCount,
            _that.errors,
            _that.insertedReferenceHashes,
            _that.analysis,
            _that.job);
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
            @JsonKey(name: 'inserted_count', fromJson: _toInt)
            int insertedCount,
            @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
            int duplicatesSkippedCount,
            @JsonKey(name: 'failed_count', fromJson: _toInt) int failedCount,
            List<RowErrorModel> errors,
            @JsonKey(name: 'inserted_reference_hashes')
            List<String> insertedReferenceHashes,
            Map<String, dynamic> analysis,
            Map<String, dynamic>? job)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel():
        return $default(
            _that.insertedCount,
            _that.duplicatesSkippedCount,
            _that.failedCount,
            _that.errors,
            _that.insertedReferenceHashes,
            _that.analysis,
            _that.job);
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
            @JsonKey(name: 'inserted_count', fromJson: _toInt)
            int insertedCount,
            @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
            int duplicatesSkippedCount,
            @JsonKey(name: 'failed_count', fromJson: _toInt) int failedCount,
            List<RowErrorModel> errors,
            @JsonKey(name: 'inserted_reference_hashes')
            List<String> insertedReferenceHashes,
            Map<String, dynamic> analysis,
            Map<String, dynamic>? job)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImportReportModel() when $default != null:
        return $default(
            _that.insertedCount,
            _that.duplicatesSkippedCount,
            _that.failedCount,
            _that.errors,
            _that.insertedReferenceHashes,
            _that.analysis,
            _that.job);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ImportReportModel extends ImportReportModel {
  const _ImportReportModel(
      {@JsonKey(name: 'inserted_count', fromJson: _toInt)
      this.insertedCount = 0,
      @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
      this.duplicatesSkippedCount = 0,
      @JsonKey(name: 'failed_count', fromJson: _toInt) this.failedCount = 0,
      final List<RowErrorModel> errors = const <RowErrorModel>[],
      @JsonKey(name: 'inserted_reference_hashes')
      final List<String> insertedReferenceHashes = const <String>[],
      final Map<String, dynamic> analysis = const <String, dynamic>{},
      final Map<String, dynamic>? job})
      : _errors = errors,
        _insertedReferenceHashes = insertedReferenceHashes,
        _analysis = analysis,
        _job = job,
        super._();
  factory _ImportReportModel.fromJson(Map<String, dynamic> json) =>
      _$ImportReportModelFromJson(json);

  @override
  @JsonKey(name: 'inserted_count', fromJson: _toInt)
  final int insertedCount;
  @override
  @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
  final int duplicatesSkippedCount;
  @override
  @JsonKey(name: 'failed_count', fromJson: _toInt)
  final int failedCount;
  final List<RowErrorModel> _errors;
  @override
  @JsonKey()
  List<RowErrorModel> get errors {
    if (_errors is EqualUnmodifiableListView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_errors);
  }

  final List<String> _insertedReferenceHashes;
  @override
  @JsonKey(name: 'inserted_reference_hashes')
  List<String> get insertedReferenceHashes {
    if (_insertedReferenceHashes is EqualUnmodifiableListView)
      return _insertedReferenceHashes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_insertedReferenceHashes);
  }

  final Map<String, dynamic> _analysis;
  @override
  @JsonKey()
  Map<String, dynamic> get analysis {
    if (_analysis is EqualUnmodifiableMapView) return _analysis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_analysis);
  }

  final Map<String, dynamic>? _job;
  @override
  Map<String, dynamic>? get job {
    final value = _job;
    if (value == null) return null;
    if (_job is EqualUnmodifiableMapView) return _job;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of ImportReportModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImportReportModelCopyWith<_ImportReportModel> get copyWith =>
      __$ImportReportModelCopyWithImpl<_ImportReportModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImportReportModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ImportReportModel &&
            (identical(other.insertedCount, insertedCount) ||
                other.insertedCount == insertedCount) &&
            (identical(other.duplicatesSkippedCount, duplicatesSkippedCount) ||
                other.duplicatesSkippedCount == duplicatesSkippedCount) &&
            (identical(other.failedCount, failedCount) ||
                other.failedCount == failedCount) &&
            const DeepCollectionEquality().equals(other._errors, _errors) &&
            const DeepCollectionEquality().equals(
                other._insertedReferenceHashes, _insertedReferenceHashes) &&
            const DeepCollectionEquality().equals(other._analysis, _analysis) &&
            const DeepCollectionEquality().equals(other._job, _job));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      insertedCount,
      duplicatesSkippedCount,
      failedCount,
      const DeepCollectionEquality().hash(_errors),
      const DeepCollectionEquality().hash(_insertedReferenceHashes),
      const DeepCollectionEquality().hash(_analysis),
      const DeepCollectionEquality().hash(_job));

  @override
  String toString() {
    return 'ImportReportModel(insertedCount: $insertedCount, duplicatesSkippedCount: $duplicatesSkippedCount, failedCount: $failedCount, errors: $errors, insertedReferenceHashes: $insertedReferenceHashes, analysis: $analysis, job: $job)';
  }
}

/// @nodoc
abstract mixin class _$ImportReportModelCopyWith<$Res>
    implements $ImportReportModelCopyWith<$Res> {
  factory _$ImportReportModelCopyWith(
          _ImportReportModel value, $Res Function(_ImportReportModel) _then) =
      __$ImportReportModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'inserted_count', fromJson: _toInt) int insertedCount,
      @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
      int duplicatesSkippedCount,
      @JsonKey(name: 'failed_count', fromJson: _toInt) int failedCount,
      List<RowErrorModel> errors,
      @JsonKey(name: 'inserted_reference_hashes')
      List<String> insertedReferenceHashes,
      Map<String, dynamic> analysis,
      Map<String, dynamic>? job});
}

/// @nodoc
class __$ImportReportModelCopyWithImpl<$Res>
    implements _$ImportReportModelCopyWith<$Res> {
  __$ImportReportModelCopyWithImpl(this._self, this._then);

  final _ImportReportModel _self;
  final $Res Function(_ImportReportModel) _then;

  /// Create a copy of ImportReportModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? insertedCount = null,
    Object? duplicatesSkippedCount = null,
    Object? failedCount = null,
    Object? errors = null,
    Object? insertedReferenceHashes = null,
    Object? analysis = null,
    Object? job = freezed,
  }) {
    return _then(_ImportReportModel(
      insertedCount: null == insertedCount
          ? _self.insertedCount
          : insertedCount // ignore: cast_nullable_to_non_nullable
              as int,
      duplicatesSkippedCount: null == duplicatesSkippedCount
          ? _self.duplicatesSkippedCount
          : duplicatesSkippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _self.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      errors: null == errors
          ? _self._errors
          : errors // ignore: cast_nullable_to_non_nullable
              as List<RowErrorModel>,
      insertedReferenceHashes: null == insertedReferenceHashes
          ? _self._insertedReferenceHashes
          : insertedReferenceHashes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      analysis: null == analysis
          ? _self._analysis
          : analysis // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      job: freezed == job
          ? _self._job
          : job // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

// dart format on
