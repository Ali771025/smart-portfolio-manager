// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_entry_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TradeEntryController)
final tradeEntryControllerProvider = TradeEntryControllerProvider._();

final class TradeEntryControllerProvider
    extends $NotifierProvider<TradeEntryController, AsyncValue<Unit>> {
  TradeEntryControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tradeEntryControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tradeEntryControllerHash();

  @$internal
  @override
  TradeEntryController create() => TradeEntryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<Unit> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<Unit>>(value),
    );
  }
}

String _$tradeEntryControllerHash() =>
    r'731fe743d2b1fc6c3f2df509a39467250ce4708e';

abstract class _$TradeEntryController extends $Notifier<AsyncValue<Unit>> {
  AsyncValue<Unit> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Unit>, AsyncValue<Unit>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Unit>, AsyncValue<Unit>>,
        AsyncValue<Unit>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
