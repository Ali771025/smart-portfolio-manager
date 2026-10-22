// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_ledger_notifiers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(assetScope)
final assetScopeProvider = AssetScopeFamily._();

final class AssetScopeProvider extends $FunctionalProvider<
        AsyncValue<AssetScope>, AssetScope, FutureOr<AssetScope>>
    with $FutureModifier<AssetScope>, $FutureProvider<AssetScope> {
  AssetScopeProvider._(
      {required AssetScopeFamily super.from,
      required ({
        String portfolioId,
        String ticker,
      })
          super.argument})
      : super(
          retry: null,
          name: r'assetScopeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$assetScopeHash();

  @override
  String toString() {
    return r'assetScopeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<AssetScope> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AssetScope> create(Ref ref) {
    final argument = this.argument as ({
      String portfolioId,
      String ticker,
    });
    return assetScope(
      ref,
      portfolioId: argument.portfolioId,
      ticker: argument.ticker,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetScopeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetScopeHash() => r'c93ac340d7f17d2e502463718c402d857d2df367';

final class AssetScopeFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<AssetScope>,
            ({
              String portfolioId,
              String ticker,
            })> {
  AssetScopeFamily._()
      : super(
          retry: null,
          name: r'assetScopeProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AssetScopeProvider call({
    required String portfolioId,
    required String ticker,
  }) =>
      AssetScopeProvider._(argument: (
        portfolioId: portfolioId,
        ticker: ticker,
      ), from: this);

  @override
  String toString() => r'assetScopeProvider';
}

@ProviderFor(AssetPositionController)
final assetPositionControllerProvider = AssetPositionControllerFamily._();

final class AssetPositionControllerProvider
    extends $AsyncNotifierProvider<AssetPositionController, AssetPositionDto> {
  AssetPositionControllerProvider._(
      {required AssetPositionControllerFamily super.from,
      required AssetScope super.argument})
      : super(
          retry: null,
          name: r'assetPositionControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$assetPositionControllerHash();

  @override
  String toString() {
    return r'assetPositionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AssetPositionController create() => AssetPositionController();

  @override
  bool operator ==(Object other) {
    return other is AssetPositionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetPositionControllerHash() =>
    r'c513699ffa58e8b2a8d769daaf3eef6d8ca2129a';

final class AssetPositionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            AssetPositionController,
            AsyncValue<AssetPositionDto>,
            AssetPositionDto,
            FutureOr<AssetPositionDto>,
            AssetScope> {
  AssetPositionControllerFamily._()
      : super(
          retry: null,
          name: r'assetPositionControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AssetPositionControllerProvider call(
    AssetScope scope,
  ) =>
      AssetPositionControllerProvider._(argument: scope, from: this);

  @override
  String toString() => r'assetPositionControllerProvider';
}

abstract class _$AssetPositionController
    extends $AsyncNotifier<AssetPositionDto> {
  late final _$args = ref.$arg as AssetScope;
  AssetScope get scope => _$args;

  FutureOr<AssetPositionDto> build(
    AssetScope scope,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AssetPositionDto>, AssetPositionDto>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AssetPositionDto>, AssetPositionDto>,
        AsyncValue<AssetPositionDto>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

@ProviderFor(assetValuationSeries)
final assetValuationSeriesProvider = AssetValuationSeriesFamily._();

final class AssetValuationSeriesProvider extends $FunctionalProvider<
        AsyncValue<AssetValuationSeriesDto>,
        AssetValuationSeriesDto,
        FutureOr<AssetValuationSeriesDto>>
    with
        $FutureModifier<AssetValuationSeriesDto>,
        $FutureProvider<AssetValuationSeriesDto> {
  AssetValuationSeriesProvider._(
      {required AssetValuationSeriesFamily super.from,
      required (
        AssetScope, {
        DateTime startDate,
        DateTime endDate,
        bool adjustedPrices,
      })
          super.argument})
      : super(
          retry: null,
          name: r'assetValuationSeriesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$assetValuationSeriesHash();

  @override
  String toString() {
    return r'assetValuationSeriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<AssetValuationSeriesDto> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AssetValuationSeriesDto> create(Ref ref) {
    final argument = this.argument as (
      AssetScope, {
      DateTime startDate,
      DateTime endDate,
      bool adjustedPrices,
    });
    return assetValuationSeries(
      ref,
      argument.$1,
      startDate: argument.startDate,
      endDate: argument.endDate,
      adjustedPrices: argument.adjustedPrices,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssetValuationSeriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetValuationSeriesHash() =>
    r'753229713d8e44001c8adb495868d0cd39cf4ac9';

final class AssetValuationSeriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<AssetValuationSeriesDto>,
            (
              AssetScope, {
              DateTime startDate,
              DateTime endDate,
              bool adjustedPrices,
            })> {
  AssetValuationSeriesFamily._()
      : super(
          retry: null,
          name: r'assetValuationSeriesProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AssetValuationSeriesProvider call(
    AssetScope scope, {
    required DateTime startDate,
    required DateTime endDate,
    bool adjustedPrices = true,
  }) =>
      AssetValuationSeriesProvider._(argument: (
        scope,
        startDate: startDate,
        endDate: endDate,
        adjustedPrices: adjustedPrices,
      ), from: this);

  @override
  String toString() => r'assetValuationSeriesProvider';
}

@ProviderFor(portfolioPositions)
final portfolioPositionsProvider = PortfolioPositionsFamily._();

final class PortfolioPositionsProvider extends $FunctionalProvider<
        AsyncValue<PortfolioPositionsDto>,
        PortfolioPositionsDto,
        FutureOr<PortfolioPositionsDto>>
    with
        $FutureModifier<PortfolioPositionsDto>,
        $FutureProvider<PortfolioPositionsDto> {
  PortfolioPositionsProvider._(
      {required PortfolioPositionsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'portfolioPositionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioPositionsHash();

  @override
  String toString() {
    return r'portfolioPositionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PortfolioPositionsDto> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PortfolioPositionsDto> create(Ref ref) {
    final argument = this.argument as String;
    return portfolioPositions(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PortfolioPositionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$portfolioPositionsHash() =>
    r'39cd3cd3bd285298e6a350b440680858263ee5b3';

final class PortfolioPositionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PortfolioPositionsDto>, String> {
  PortfolioPositionsFamily._()
      : super(
          retry: null,
          name: r'portfolioPositionsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  PortfolioPositionsProvider call(
    String portfolioId,
  ) =>
      PortfolioPositionsProvider._(argument: portfolioId, from: this);

  @override
  String toString() => r'portfolioPositionsProvider';
}

@ProviderFor(portfolioTwr)
final portfolioTwrProvider = PortfolioTwrFamily._();

final class PortfolioTwrProvider extends $FunctionalProvider<
        AsyncValue<PortfolioTwrDto>, PortfolioTwrDto, FutureOr<PortfolioTwrDto>>
    with $FutureModifier<PortfolioTwrDto>, $FutureProvider<PortfolioTwrDto> {
  PortfolioTwrProvider._(
      {required PortfolioTwrFamily super.from,
      required (
        String, {
        DateTime startDate,
        DateTime endDate,
      })
          super.argument})
      : super(
          retry: null,
          name: r'portfolioTwrProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$portfolioTwrHash();

  @override
  String toString() {
    return r'portfolioTwrProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PortfolioTwrDto> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PortfolioTwrDto> create(Ref ref) {
    final argument = this.argument as (
      String, {
      DateTime startDate,
      DateTime endDate,
    });
    return portfolioTwr(
      ref,
      argument.$1,
      startDate: argument.startDate,
      endDate: argument.endDate,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PortfolioTwrProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$portfolioTwrHash() => r'98e174f6426baa6a9fa9ac955f8e0cf2bbc54f2a';

final class PortfolioTwrFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<PortfolioTwrDto>,
            (
              String, {
              DateTime startDate,
              DateTime endDate,
            })> {
  PortfolioTwrFamily._()
      : super(
          retry: null,
          name: r'portfolioTwrProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  PortfolioTwrProvider call(
    String portfolioId, {
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      PortfolioTwrProvider._(argument: (
        portfolioId,
        startDate: startDate,
        endDate: endDate,
      ), from: this);

  @override
  String toString() => r'portfolioTwrProvider';
}

@ProviderFor(AssetLedgerController)
final assetLedgerControllerProvider = AssetLedgerControllerFamily._();

final class AssetLedgerControllerProvider extends $AsyncNotifierProvider<
    AssetLedgerController, LedgerPaginationState> {
  AssetLedgerControllerProvider._(
      {required AssetLedgerControllerFamily super.from,
      required AssetScope super.argument})
      : super(
          retry: null,
          name: r'assetLedgerControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$assetLedgerControllerHash();

  @override
  String toString() {
    return r'assetLedgerControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AssetLedgerController create() => AssetLedgerController();

  @override
  bool operator ==(Object other) {
    return other is AssetLedgerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$assetLedgerControllerHash() =>
    r'09875750545701c52595b6a69443184072036eb4';

final class AssetLedgerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            AssetLedgerController,
            AsyncValue<LedgerPaginationState>,
            LedgerPaginationState,
            FutureOr<LedgerPaginationState>,
            AssetScope> {
  AssetLedgerControllerFamily._()
      : super(
          retry: null,
          name: r'assetLedgerControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AssetLedgerControllerProvider call(
    AssetScope scope,
  ) =>
      AssetLedgerControllerProvider._(argument: scope, from: this);

  @override
  String toString() => r'assetLedgerControllerProvider';
}

abstract class _$AssetLedgerController
    extends $AsyncNotifier<LedgerPaginationState> {
  late final _$args = ref.$arg as AssetScope;
  AssetScope get scope => _$args;

  FutureOr<LedgerPaginationState> build(
    AssetScope scope,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<LedgerPaginationState>, LedgerPaginationState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<LedgerPaginationState>, LedgerPaginationState>,
        AsyncValue<LedgerPaginationState>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}

@ProviderFor(TransactionFormController)
final transactionFormControllerProvider = TransactionFormControllerFamily._();

final class TransactionFormControllerProvider extends $AsyncNotifierProvider<
    TransactionFormController, TransactionFormState> {
  TransactionFormControllerProvider._(
      {required TransactionFormControllerFamily super.from,
      required AssetScope super.argument})
      : super(
          retry: null,
          name: r'transactionFormControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$transactionFormControllerHash();

  @override
  String toString() {
    return r'transactionFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TransactionFormController create() => TransactionFormController();

  @override
  bool operator ==(Object other) {
    return other is TransactionFormControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionFormControllerHash() =>
    r'aaf0a05015e8ef3a767059bbc0a2de9f9b0d9ca2';

final class TransactionFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            TransactionFormController,
            AsyncValue<TransactionFormState>,
            TransactionFormState,
            FutureOr<TransactionFormState>,
            AssetScope> {
  TransactionFormControllerFamily._()
      : super(
          retry: null,
          name: r'transactionFormControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  TransactionFormControllerProvider call(
    AssetScope scope,
  ) =>
      TransactionFormControllerProvider._(argument: scope, from: this);

  @override
  String toString() => r'transactionFormControllerProvider';
}

abstract class _$TransactionFormController
    extends $AsyncNotifier<TransactionFormState> {
  late final _$args = ref.$arg as AssetScope;
  AssetScope get scope => _$args;

  FutureOr<TransactionFormState> build(
    AssetScope scope,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<TransactionFormState>, TransactionFormState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<TransactionFormState>, TransactionFormState>,
        AsyncValue<TransactionFormState>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              _$args,
            ));
  }
}
