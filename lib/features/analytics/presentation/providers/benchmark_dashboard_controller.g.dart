// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'benchmark_dashboard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BenchmarkDashboardController)
final benchmarkDashboardControllerProvider =
    BenchmarkDashboardControllerFamily._();

final class BenchmarkDashboardControllerProvider extends $AsyncNotifierProvider<
    BenchmarkDashboardController, BenchmarkDashboardState> {
  BenchmarkDashboardControllerProvider._(
      {required BenchmarkDashboardControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'benchmarkDashboardControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$benchmarkDashboardControllerHash();

  @override
  String toString() {
    return r'benchmarkDashboardControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BenchmarkDashboardController create() => BenchmarkDashboardController();

  @override
  bool operator ==(Object other) {
    return other is BenchmarkDashboardControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$benchmarkDashboardControllerHash() =>
    r'54b1368448c081066fe138484fb0dd89dd61a331';

final class BenchmarkDashboardControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            BenchmarkDashboardController,
            AsyncValue<BenchmarkDashboardState>,
            BenchmarkDashboardState,
            FutureOr<BenchmarkDashboardState>,
            String> {
  BenchmarkDashboardControllerFamily._()
      : super(
          retry: null,
          name: r'benchmarkDashboardControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  BenchmarkDashboardControllerProvider call(
    String portfolioId,
  ) =>
      BenchmarkDashboardControllerProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'benchmarkDashboardControllerProvider';
}

abstract class _$BenchmarkDashboardController
    extends $AsyncNotifier<BenchmarkDashboardState> {
  late final _$args = ref.$arg as String;
  String get portfolioId => _$args;

  FutureOr<BenchmarkDashboardState> build(
    String portfolioId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<BenchmarkDashboardState>, BenchmarkDashboardState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<BenchmarkDashboardState>,
            BenchmarkDashboardState>,
        AsyncValue<BenchmarkDashboardState>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

@ProviderFor(benchmarkVisibleSeries)
final benchmarkVisibleSeriesProvider = BenchmarkVisibleSeriesFamily._();

final class BenchmarkVisibleSeriesProvider extends $FunctionalProvider<
        IMap<BenchmarkLineKind, IList<FlSpot>>,
        IMap<BenchmarkLineKind, IList<FlSpot>>,
        IMap<BenchmarkLineKind, IList<FlSpot>>>
    with $Provider<IMap<BenchmarkLineKind, IList<FlSpot>>> {
  BenchmarkVisibleSeriesProvider._(
      {required BenchmarkVisibleSeriesFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'benchmarkVisibleSeriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$benchmarkVisibleSeriesHash();

  @override
  String toString() {
    return r'benchmarkVisibleSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<IMap<BenchmarkLineKind, IList<FlSpot>>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IMap<BenchmarkLineKind, IList<FlSpot>> create(Ref ref) {
    final argument = this.argument as String;
    return benchmarkVisibleSeries(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMap<BenchmarkLineKind, IList<FlSpot>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<IMap<BenchmarkLineKind, IList<FlSpot>>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BenchmarkVisibleSeriesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$benchmarkVisibleSeriesHash() =>
    r'de4c6a623a9aef60ca02e2690dbc436da3cbe451';

final class BenchmarkVisibleSeriesFamily extends $Family
    with
        $FunctionalFamilyOverride<IMap<BenchmarkLineKind, IList<FlSpot>>,
            String> {
  BenchmarkVisibleSeriesFamily._()
      : super(
          retry: null,
          name: r'benchmarkVisibleSeriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BenchmarkVisibleSeriesProvider call(
    String portfolioId,
  ) =>
      BenchmarkVisibleSeriesProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'benchmarkVisibleSeriesProvider';
}

@ProviderFor(benchmarkDashboardFailure)
final benchmarkDashboardFailureProvider = BenchmarkDashboardFailureFamily._();

final class BenchmarkDashboardFailureProvider
    extends $FunctionalProvider<AppFailure?, AppFailure?, AppFailure?>
    with $Provider<AppFailure?> {
  BenchmarkDashboardFailureProvider._(
      {required BenchmarkDashboardFailureFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'benchmarkDashboardFailureProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$benchmarkDashboardFailureHash();

  @override
  String toString() {
    return r'benchmarkDashboardFailureProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AppFailure?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppFailure? create(Ref ref) {
    final argument = this.argument as String;
    return benchmarkDashboardFailure(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppFailure? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppFailure?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BenchmarkDashboardFailureProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$benchmarkDashboardFailureHash() =>
    r'beb5440ebd1ebbab6053e244f2c20a52a0e18fd8';

final class BenchmarkDashboardFailureFamily extends $Family
    with $FunctionalFamilyOverride<AppFailure?, String> {
  BenchmarkDashboardFailureFamily._()
      : super(
          retry: null,
          name: r'benchmarkDashboardFailureProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BenchmarkDashboardFailureProvider call(
    String portfolioId,
  ) =>
      BenchmarkDashboardFailureProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'benchmarkDashboardFailureProvider';
}
