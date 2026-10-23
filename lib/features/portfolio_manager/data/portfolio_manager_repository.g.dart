// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_manager_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(portfolioManagerRepository)
final portfolioManagerRepositoryProvider =
    PortfolioManagerRepositoryProvider._();

final class PortfolioManagerRepositoryProvider extends $FunctionalProvider<
    PortfolioManagerRepository,
    PortfolioManagerRepository,
    PortfolioManagerRepository> with $Provider<PortfolioManagerRepository> {
  PortfolioManagerRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'portfolioManagerRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioManagerRepositoryHash();

  @$internal
  @override
  $ProviderElement<PortfolioManagerRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PortfolioManagerRepository create(Ref ref) {
    return portfolioManagerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PortfolioManagerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PortfolioManagerRepository>(value),
    );
  }
}

String _$portfolioManagerRepositoryHash() =>
    r'aa02db1335ad8e7b58d95401296933d076e0d039';
