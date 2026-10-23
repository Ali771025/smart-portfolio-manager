// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for market repository.

@ProviderFor(marketRepository)
final marketRepositoryProvider = MarketRepositoryProvider._();

/// Riverpod provider for market repository.

final class MarketRepositoryProvider extends $FunctionalProvider<
    MarketRepository,
    MarketRepository,
    MarketRepository> with $Provider<MarketRepository> {
  /// Riverpod provider for market repository.
  MarketRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketRepositoryHash();

  @$internal
  @override
  $ProviderElement<MarketRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MarketRepository create(Ref ref) {
    return marketRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketRepository>(value),
    );
  }
}

String _$marketRepositoryHash() => r'4b969ae588bdf73bb33f96153aaeefd744edd2af';
