// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_chart_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(portfolioChartRepository)
final portfolioChartRepositoryProvider = PortfolioChartRepositoryProvider._();

final class PortfolioChartRepositoryProvider extends $FunctionalProvider<
    PortfolioChartRepository,
    PortfolioChartRepository,
    PortfolioChartRepository> with $Provider<PortfolioChartRepository> {
  PortfolioChartRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'portfolioChartRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioChartRepositoryHash();

  @$internal
  @override
  $ProviderElement<PortfolioChartRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PortfolioChartRepository create(Ref ref) {
    return portfolioChartRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PortfolioChartRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PortfolioChartRepository>(value),
    );
  }
}

String _$portfolioChartRepositoryHash() =>
    r'15ae3eefa483d08c479534c743bbfc70ff78ce19';
