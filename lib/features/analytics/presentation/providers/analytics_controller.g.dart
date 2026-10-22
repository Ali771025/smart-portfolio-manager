// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AnalyticsController)
final analyticsControllerProvider = AnalyticsControllerFamily._();

final class AnalyticsControllerProvider
    extends $AsyncNotifierProvider<AnalyticsController, AnalyticsViewState> {
  AnalyticsControllerProvider._(
      {required AnalyticsControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'analyticsControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$analyticsControllerHash();

  @override
  String toString() {
    return r'analyticsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AnalyticsController create() => AnalyticsController();

  @override
  bool operator ==(Object other) {
    return other is AnalyticsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$analyticsControllerHash() =>
    r'7b7a60d4be91bc674ad199116cca2123ae4884eb';

final class AnalyticsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            AnalyticsController,
            AsyncValue<AnalyticsViewState>,
            AnalyticsViewState,
            FutureOr<AnalyticsViewState>,
            String> {
  AnalyticsControllerFamily._()
      : super(
          retry: null,
          name: r'analyticsControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  AnalyticsControllerProvider call(
    String portfolioId,
  ) =>
      AnalyticsControllerProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'analyticsControllerProvider';
}

abstract class _$AnalyticsController
    extends $AsyncNotifier<AnalyticsViewState> {
  late final _$args = ref.$arg as String;
  String get portfolioId => _$args;

  FutureOr<AnalyticsViewState> build(
    String portfolioId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AnalyticsViewState>, AnalyticsViewState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AnalyticsViewState>, AnalyticsViewState>,
        AsyncValue<AnalyticsViewState>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

@ProviderFor(analyticsSelectedTimeframe)
final analyticsSelectedTimeframeProvider = AnalyticsSelectedTimeframeFamily._();

final class AnalyticsSelectedTimeframeProvider extends $FunctionalProvider<
    AnalyticsTimeframe,
    AnalyticsTimeframe,
    AnalyticsTimeframe> with $Provider<AnalyticsTimeframe> {
  AnalyticsSelectedTimeframeProvider._(
      {required AnalyticsSelectedTimeframeFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'analyticsSelectedTimeframeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$analyticsSelectedTimeframeHash();

  @override
  String toString() {
    return r'analyticsSelectedTimeframeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AnalyticsTimeframe> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsTimeframe create(Ref ref) {
    final argument = this.argument as String;
    return analyticsSelectedTimeframe(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsTimeframe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsTimeframe>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AnalyticsSelectedTimeframeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$analyticsSelectedTimeframeHash() =>
    r'ee916331111a93c213f9ff448561635217fa55cc';

final class AnalyticsSelectedTimeframeFamily extends $Family
    with $FunctionalFamilyOverride<AnalyticsTimeframe, String> {
  AnalyticsSelectedTimeframeFamily._()
      : super(
          retry: null,
          name: r'analyticsSelectedTimeframeProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AnalyticsSelectedTimeframeProvider call(
    String portfolioId,
  ) =>
      AnalyticsSelectedTimeframeProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'analyticsSelectedTimeframeProvider';
}

@ProviderFor(analyticsFailure)
final analyticsFailureProvider = AnalyticsFailureFamily._();

final class AnalyticsFailureProvider
    extends $FunctionalProvider<AppFailure?, AppFailure?, AppFailure?>
    with $Provider<AppFailure?> {
  AnalyticsFailureProvider._(
      {required AnalyticsFailureFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'analyticsFailureProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$analyticsFailureHash();

  @override
  String toString() {
    return r'analyticsFailureProvider'
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
    return analyticsFailure(
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
    return other is AnalyticsFailureProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$analyticsFailureHash() => r'ace2870f4eb3014b1c4225f92b3b3bfed7a2ec4d';

final class AnalyticsFailureFamily extends $Family
    with $FunctionalFamilyOverride<AppFailure?, String> {
  AnalyticsFailureFamily._()
      : super(
          retry: null,
          name: r'analyticsFailureProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AnalyticsFailureProvider call(
    String portfolioId,
  ) =>
      AnalyticsFailureProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'analyticsFailureProvider';
}
