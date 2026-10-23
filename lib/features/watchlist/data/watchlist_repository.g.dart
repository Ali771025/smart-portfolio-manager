// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watchlist_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for watchlist repository.

@ProviderFor(watchlistRepository)
final watchlistRepositoryProvider = WatchlistRepositoryProvider._();

/// Riverpod provider for watchlist repository.

final class WatchlistRepositoryProvider extends $FunctionalProvider<
    WatchlistRepository,
    WatchlistRepository,
    WatchlistRepository> with $Provider<WatchlistRepository> {
  /// Riverpod provider for watchlist repository.
  WatchlistRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'watchlistRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$watchlistRepositoryHash();

  @$internal
  @override
  $ProviderElement<WatchlistRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WatchlistRepository create(Ref ref) {
    return watchlistRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchlistRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchlistRepository>(value),
    );
  }
}

String _$watchlistRepositoryHash() =>
    r'bbbf90b6e65ff722fd66ac363b4c090c9d17dc13';
