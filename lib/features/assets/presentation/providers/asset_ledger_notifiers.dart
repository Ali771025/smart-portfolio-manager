import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../../../../core/network/problem_details_parser.dart';
import '../../data/asset_ledger_repository.dart';
import '../../domain/models/asset_ledger_models.dart';
import '../../domain/models/asset_notifier_state.dart';

part 'asset_ledger_notifiers.g.dart';

class AssetScope {
  const AssetScope({
    required this.portfolioId,
    required this.assetId,
  });

  final String portfolioId;
  final String assetId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AssetScope &&
            other.portfolioId == portfolioId &&
            other.assetId == assetId);
  }

  @override
  int get hashCode => Object.hash(portfolioId, assetId);
}

@Riverpod()
Future<AssetScope> assetScope(
  Ref ref, {
  required String portfolioId,
  required String ticker,
}) async {
  final repository = ref.read(assetLedgerRepositoryProvider);
  final resolved = await repository.resolveAsset(symbol: ticker);
  final assetId = resolved.assetId;
  return AssetScope(portfolioId: portfolioId, assetId: assetId);
}

@Riverpod()
class AssetPositionController extends _$AssetPositionController {
  AssetLedgerRepository get _repository =>
      ref.read(assetLedgerRepositoryProvider);

  @override
  Future<AssetPositionDto> build(AssetScope scope) {
    return _repository.fetchAssetPosition(
      portfolioId: scope.portfolioId,
      assetId: scope.assetId,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(
      () => _repository.fetchAssetPosition(
        portfolioId: scope.portfolioId,
        assetId: scope.assetId,
      ),
    );
    if (!ref.mounted) {
      return;
    }
    state = nextState;
  }

  Future<void> retry() => refresh();
}

@Riverpod()
Future<AssetValuationSeriesDto> assetValuationSeries(
  Ref ref,
  AssetScope scope, {
  required DateTime startDate,
  required DateTime endDate,
  bool adjustedPrices = true,
}) {
  final repository = ref.read(assetLedgerRepositoryProvider);
  return repository.fetchAssetValuationSeries(
    portfolioId: scope.portfolioId,
    assetId: scope.assetId,
    startDate: startDate,
    endDate: endDate,
    adjustedPrices: adjustedPrices,
  );
}

@Riverpod()
Future<PortfolioPositionsDto> portfolioPositions(
  Ref ref,
  String portfolioId,
) {
  final repository = ref.read(assetLedgerRepositoryProvider);
  return repository.fetchPortfolioPositions(portfolioId: portfolioId);
}

final portfolioHoldingsProvider =
    riverpod.FutureProvider.family<PortfolioHoldingsDto, String>(
  (ref, portfolioId) {
    return ref
        .read(assetLedgerRepositoryProvider)
        .fetchHoldings(portfolioId: portfolioId);
  },
);

final portfolioFrontendSummaryProvider =
    riverpod.FutureProvider.family<PortfolioFrontendSummaryDto, String>(
  (ref, portfolioId) {
    return ref
        .read(assetLedgerRepositoryProvider)
        .fetchFrontendSummary(portfolioId: portfolioId);
  },
);

final assetBreakEvenInfoProvider =
    riverpod.FutureProvider.family<AssetBreakEvenInfo, AssetScope>(
        (ref, scope) {
  final repository = ref.read(assetLedgerRepositoryProvider);
  return repository.fetchBreakEvenInfo(
    portfolioId: scope.portfolioId,
    assetId: scope.assetId,
  );
});

@Riverpod()
Future<PortfolioTwrDto> portfolioTwr(
  Ref ref,
  String portfolioId, {
  required DateTime startDate,
  required DateTime endDate,
}) {
  final repository = ref.read(assetLedgerRepositoryProvider);
  return repository.fetchPortfolioTwr(
    portfolioId: portfolioId,
    startDate: startDate,
    endDate: endDate,
  );
}

@Riverpod()
class AssetLedgerController extends _$AssetLedgerController {
  static const int _defaultLimit = 50;

  AssetLedgerRepository get _repository =>
      ref.read(assetLedgerRepositoryProvider);

  @override
  Future<LedgerPaginationState> build(AssetScope scope) async {
    return _fetchPage(limit: _defaultLimit, offset: 0);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(
        () => _fetchPage(limit: _defaultLimit, offset: 0));
    if (!ref.mounted) {
      return;
    }
    state = nextState;
  }

  Future<void> retry() => refresh();

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final pageResult = await AsyncValue.guard(
      () => _repository.fetchAssetLedger(
        portfolioId: scope.portfolioId,
        assetId: scope.assetId,
        limit: current.limit,
        offset: current.items.length,
      ),
    );
    if (!ref.mounted) {
      return;
    }

    pageResult.when(
      data: (page) {
        if (!ref.mounted) {
          return;
        }
        final merged = current.copyWith(
          items: <LedgerEntryDto>[...current.items, ...page.items],
          total: page.total,
          limit: page.limit,
          offset: page.offset,
          isLoadingMore: false,
        );
        state = AsyncValue.data(merged);
      },
      error: (error, stackTrace) {
        if (!ref.mounted) {
          return;
        }
        state = AsyncValue.error(error, stackTrace);
      },
      loading: () {},
    );
  }

  Future<LedgerPaginationState> _fetchPage({
    required int limit,
    required int offset,
  }) async {
    final page = await _repository.fetchAssetLedger(
      portfolioId: scope.portfolioId,
      assetId: scope.assetId,
      limit: limit,
      offset: offset,
    );
    return LedgerPaginationState(
      items: page.items,
      total: page.total,
      limit: page.limit,
      offset: page.offset,
      isLoadingMore: false,
    );
  }
}

@Riverpod()
class TransactionFormController extends _$TransactionFormController {
  AssetLedgerRepository get _repository =>
      ref.read(assetLedgerRepositoryProvider);

  @override
  Future<TransactionFormState> build(AssetScope scope) async {
    return TransactionFormState(
      portfolioId: scope.portfolioId,
      assetId: scope.assetId,
    );
  }

  void updateQuantity(String value) {
    state = state.whenData((current) =>
        current.copyWith(quantityInput: value, errorMessage: null));
  }

  void updatePrice(String value) {
    state = state.whenData(
        (current) => current.copyWith(priceInput: value, errorMessage: null));
  }

  void updateFees(String value) {
    state = state.whenData(
        (current) => current.copyWith(feesInput: value, errorMessage: null));
  }

  void updateNotes(String value) {
    state = state.whenData(
        (current) => current.copyWith(notes: value, errorMessage: null));
  }

  void updateDividendPerUnit(String value) {
    state = state.whenData((current) =>
        current.copyWith(dividendPerUnitInput: value, errorMessage: null));
  }

  void updateBonusRatio(String value) {
    state = state.whenData((current) =>
        current.copyWith(bonusRatioInput: value, errorMessage: null));
  }

  void updateSplitFrom(String value) {
    state = state.whenData((current) =>
        current.copyWith(splitFromInput: value, errorMessage: null));
  }

  void updateSplitTo(String value) {
    state = state.whenData(
        (current) => current.copyWith(splitToInput: value, errorMessage: null));
  }

  void updateRightsRatio(String value) {
    state = state.whenData((current) =>
        current.copyWith(rightsRatioInput: value, errorMessage: null));
  }

  void updateSubscriptionPrice(String value) {
    state = state.whenData((current) =>
        current.copyWith(subscriptionPriceInput: value, errorMessage: null));
  }

  void updateType(String value) {
    state = state.whenData((current) =>
        current.copyWith(transactionType: value, errorMessage: null));
  }

  Future<void> submit() async {
    final snapshot = state.asData?.value;
    if (snapshot == null) {
      return;
    }

    final availableQuantity = await _readAvailableQuantity();
    if (!ref.mounted) {
      return;
    }
    final validationMessage =
        _validate(snapshot, availableQuantity: availableQuantity);
    if (validationMessage != null) {
      state = AsyncValue.data(
        snapshot.copyWith(
          submitting: false,
          submitSuccess: false,
          errorMessage: validationMessage,
        ),
      );
      return;
    }

    state = AsyncValue.data(
      snapshot.copyWith(
        submitting: true,
        submitSuccess: false,
        errorMessage: null,
      ),
    );

    final result = await AsyncValue.guard(() async {
      final payload = TransactionCreateDto(
        assetId: snapshot.assetId,
        transactionType: snapshot.transactionType,
        quantity: snapshot.quantity,
        pricePerUnit:
            snapshot.transactionType == 'STOCK_SPLIT' ? null : snapshot.price,
        fees: (snapshot.transactionType == 'CASH_DIVIDEND' ||
                snapshot.transactionType == 'STOCK_SPLIT')
            ? null
            : snapshot.fees,
        dividendPerUnit: snapshot.transactionType == 'CASH_DIVIDEND'
            ? snapshot.dividendPerUnit
            : null,
        bonusRatio: snapshot.transactionType == 'CAPITAL_INCREASE_BONUS'
            ? snapshot.bonusRatio
            : null,
        splitFrom: snapshot.transactionType == 'STOCK_SPLIT'
            ? snapshot.splitFrom
            : null,
        splitTo:
            snapshot.transactionType == 'STOCK_SPLIT' ? snapshot.splitTo : null,
        rightsRatio: snapshot.transactionType == 'PRE_EMPTIVE_RIGHTS'
            ? snapshot.rightsRatio
            : null,
        subscriptionPrice: snapshot.transactionType == 'PRE_EMPTIVE_RIGHTS'
            ? snapshot.subscriptionPrice
            : null,
        executedAt: DateTime.now().toUtc(),
        notes: snapshot.notes.isEmpty ? null : snapshot.notes,
      );
      await _repository.createTransaction(
        portfolioId: snapshot.portfolioId,
        payload: payload,
        idempotencyKey:
            '${snapshot.assetId}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (ref.mounted) {
        ref.invalidate(assetPositionControllerProvider(scope));
        ref.invalidate(assetLedgerControllerProvider(scope));
        ref.invalidate(portfolioPositionsProvider(scope.portfolioId));
      }
      return snapshot.copyWith(
        submitting: false,
        submitSuccess: true,
      );
    });
    if (!ref.mounted) {
      return;
    }

    result.when(
      data: (next) {
        state = AsyncValue.data(next);
      },
      error: (error, stackTrace) {
        final message = _errorMessage(error);
        state = AsyncValue.data(snapshot.copyWith(
          submitting: false,
          submitSuccess: false,
          errorMessage: message,
        ));
      },
      loading: () {},
    );
  }

  Future<void> retrySubmit() => submit();

  Future<Decimal?> _readAvailableQuantity() async {
    try {
      final position = await _repository.fetchAssetPosition(
        portfolioId: scope.portfolioId,
        assetId: scope.assetId,
      );
      return position.quantity;
    } catch (_) {
      return null;
    }
  }

  String? _validate(
    TransactionFormState form, {
    required Decimal? availableQuantity,
  }) {
    final errors = <String>[];

    if (form.quantity <= Decimal.zero) {
      errors.add('تعداد باید بزرگ‌تر از صفر باشد.');
    }

    if (form.fees < Decimal.zero) {
      errors.add('کارمزد/هزینه نباید منفی باشد.');
    }

    if (form.transactionType == 'BUY' || form.transactionType == 'SELL') {
      if (form.price <= Decimal.zero) {
        errors.add('قیمت باید بزرگ‌تر از صفر باشد.');
      }
      if (form.transactionType == 'SELL' &&
          availableQuantity != null &&
          form.quantity > availableQuantity) {
        errors.add('تعداد فروش نمی‌تواند بیشتر از دارایی موجود باشد.');
      }
    }

    if (form.transactionType == 'CASH_DIVIDEND' &&
        form.dividendPerUnit <= Decimal.zero) {
      errors.add('سود نقدی هر سهم باید بزرگ‌تر از صفر باشد.');
    }

    if (form.transactionType == 'CAPITAL_INCREASE_BONUS' &&
        form.bonusRatio <= Decimal.zero) {
      errors.add('نسبت جایزه باید بزرگ‌تر از صفر باشد.');
    }

    if (form.transactionType == 'STOCK_SPLIT') {
      if (form.splitFrom < 1 ||
          form.splitTo < 1 ||
          form.splitTo <= form.splitFrom) {
        errors.add('نسبت تجزیه معتبر نیست.');
      }
    }

    if (form.transactionType == 'PRE_EMPTIVE_RIGHTS') {
      if (form.rightsRatio <= Decimal.zero) {
        errors.add('نسبت حق تقدم باید بزرگ‌تر از صفر باشد.');
      }
      if (form.subscriptionPrice <= Decimal.zero) {
        errors.add('قیمت پذیره‌نویسی باید بزرگ‌تر از صفر باشد.');
      }
    }

    if (errors.isEmpty) {
      return null;
    }
    return errors.first;
  }

  String _errorMessage(Object error) {
    if (error is AssetLedgerException) {
      return error.problem.detail;
    }
    if (error is ProblemDetailsException) {
      return error.problem.detail;
    }
    return 'Unexpected error while submitting transaction.';
  }
}
