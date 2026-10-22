// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for live market data.

@ProviderFor(MarketLiveController)
final marketLiveControllerProvider = MarketLiveControllerProvider._();

/// Controller for live market data.
final class MarketLiveControllerProvider
    extends $NotifierProvider<MarketLiveController, MarketLiveState> {
  /// Controller for live market data.
  MarketLiveControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketLiveControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketLiveControllerHash();

  @$internal
  @override
  MarketLiveController create() => MarketLiveController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketLiveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketLiveState>(value),
    );
  }
}

String _$marketLiveControllerHash() =>
    r'7ac1ed4524425f355dee4cf7c10669bb5355e0c5';

/// Controller for live market data.

abstract class _$MarketLiveController extends $Notifier<MarketLiveState> {
  MarketLiveState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MarketLiveState, MarketLiveState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<MarketLiveState, MarketLiveState>,
        MarketLiveState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Controller for market status.

@ProviderFor(MarketStatusController)
final marketStatusControllerProvider = MarketStatusControllerProvider._();

/// Controller for market status.
final class MarketStatusControllerProvider
    extends $NotifierProvider<MarketStatusController, MarketStatusState> {
  /// Controller for market status.
  MarketStatusControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketStatusControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketStatusControllerHash();

  @$internal
  @override
  MarketStatusController create() => MarketStatusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketStatusState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketStatusState>(value),
    );
  }
}

String _$marketStatusControllerHash() =>
    r'7dbefb4809fbd69bbdbec225dbcf7a68d077176c';

/// Controller for market status.

abstract class _$MarketStatusController extends $Notifier<MarketStatusState> {
  MarketStatusState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MarketStatusState, MarketStatusState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<MarketStatusState, MarketStatusState>,
        MarketStatusState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Controller for symbol history.

@ProviderFor(MarketHistoryController)
final marketHistoryControllerProvider = MarketHistoryControllerProvider._();

/// Controller for symbol history.
final class MarketHistoryControllerProvider extends $NotifierProvider<
    MarketHistoryController, AsyncValue<SymbolHistory?>> {
  /// Controller for symbol history.
  MarketHistoryControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketHistoryControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketHistoryControllerHash();

  @$internal
  @override
  MarketHistoryController create() => MarketHistoryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<SymbolHistory?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<SymbolHistory?>>(value),
    );
  }
}

String _$marketHistoryControllerHash() =>
    r'0055795b8fa7a6c09ba607e8b0d7f3cb61ed5cf5';

/// Controller for symbol history.

abstract class _$MarketHistoryController
    extends $Notifier<AsyncValue<SymbolHistory?>> {
  AsyncValue<SymbolHistory?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<SymbolHistory?>, AsyncValue<SymbolHistory?>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<SymbolHistory?>, AsyncValue<SymbolHistory?>>,
        AsyncValue<SymbolHistory?>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Controller for index snapshots.

@ProviderFor(MarketIndexController)
final marketIndexControllerProvider = MarketIndexControllerProvider._();

/// Controller for index snapshots.
final class MarketIndexControllerProvider extends $NotifierProvider<
    MarketIndexController, Map<String, IndexSnapshot>> {
  /// Controller for index snapshots.
  MarketIndexControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketIndexControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketIndexControllerHash();

  @$internal
  @override
  MarketIndexController create() => MarketIndexController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, IndexSnapshot> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, IndexSnapshot>>(value),
    );
  }
}

String _$marketIndexControllerHash() =>
    r'40db6cdfa33488389195f6c8ed47536be5b69d3f';

/// Controller for index snapshots.

abstract class _$MarketIndexController
    extends $Notifier<Map<String, IndexSnapshot>> {
  Map<String, IndexSnapshot> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<Map<String, IndexSnapshot>, Map<String, IndexSnapshot>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Map<String, IndexSnapshot>, Map<String, IndexSnapshot>>,
        Map<String, IndexSnapshot>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
