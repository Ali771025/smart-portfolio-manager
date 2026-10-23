// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_entry_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tradeEntryRepository)
final tradeEntryRepositoryProvider = TradeEntryRepositoryProvider._();

final class TradeEntryRepositoryProvider extends $FunctionalProvider<
    TradeEntryRepository,
    TradeEntryRepository,
    TradeEntryRepository> with $Provider<TradeEntryRepository> {
  TradeEntryRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tradeEntryRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tradeEntryRepositoryHash();

  @$internal
  @override
  $ProviderElement<TradeEntryRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TradeEntryRepository create(Ref ref) {
    return tradeEntryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TradeEntryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TradeEntryRepository>(value),
    );
  }
}

String _$tradeEntryRepositoryHash() =>
    r'326a25ca8ae11f19b0280d51ff6a54813cedc160';
