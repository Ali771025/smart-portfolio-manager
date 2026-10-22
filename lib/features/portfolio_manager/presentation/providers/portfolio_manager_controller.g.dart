// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_manager_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PortfolioManagerController)
final portfolioManagerControllerProvider =
    PortfolioManagerControllerProvider._();

final class PortfolioManagerControllerProvider extends $AsyncNotifierProvider<
    PortfolioManagerController, List<PortfolioCardDto>> {
  PortfolioManagerControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'portfolioManagerControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioManagerControllerHash();

  @$internal
  @override
  PortfolioManagerController create() => PortfolioManagerController();
}

String _$portfolioManagerControllerHash() =>
    r'17a8c31f69c89595c59f349845747b127b2522e0';

abstract class _$PortfolioManagerController
    extends $AsyncNotifier<List<PortfolioCardDto>> {
  FutureOr<List<PortfolioCardDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<List<PortfolioCardDto>>, List<PortfolioCardDto>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<PortfolioCardDto>>, List<PortfolioCardDto>>,
        AsyncValue<List<PortfolioCardDto>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(portfolioOptions)
final portfolioOptionsProvider = PortfolioOptionsProvider._();

final class PortfolioOptionsProvider extends $FunctionalProvider<
    List<PortfolioOptionDto>,
    List<PortfolioOptionDto>,
    List<PortfolioOptionDto>> with $Provider<List<PortfolioOptionDto>> {
  PortfolioOptionsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'portfolioOptionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioOptionsHash();

  @$internal
  @override
  $ProviderElement<List<PortfolioOptionDto>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<PortfolioOptionDto> create(Ref ref) {
    return portfolioOptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PortfolioOptionDto> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PortfolioOptionDto>>(value),
    );
  }
}

String _$portfolioOptionsHash() => r'f15fb30e9f637cf4aaeb13953ee1811d45309fa4';
