import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../transactions/domain/transaction_request.dart';
import '../../../assets/presentation/providers/asset_ledger_notifiers.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../data/portfolio_api.dart';
import '../../domain/portfolio_summary.dart';
import 'portfolio_providers.dart';

const _defaultAccessToken = String.fromEnvironment(
  'ACCESS_TOKEN',
  defaultValue: '',
);

final authTokenProvider = StateProvider<String>((ref) => _defaultAccessToken);

final portfolioApiProvider = Provider<PortfolioApi>((ref) => PortfolioApi());

final _portfolioSummaryCacheProvider =
    StateProvider<Map<String, PortfolioSummary>>(
        (ref) => <String, PortfolioSummary>{});

final portfolioSummaryProvider = StateNotifierProvider.autoDispose
    .family<PortfolioSummaryController, AsyncValue<PortfolioSummary>, String>(
        (ref, portfolioId) {
  ref.keepAlive();
  final cached = ref.read(_portfolioSummaryCacheProvider)[portfolioId];
  final controller = PortfolioSummaryController(
    ref: ref,
    portfolioId: portfolioId,
    initialSummary: cached,
  );
  if (cached == null) {
    unawaited(controller.load());
  }
  return controller;
});

class PortfolioSummaryController
    extends StateNotifier<AsyncValue<PortfolioSummary>> {
  PortfolioSummaryController({
    required this.ref,
    required this.portfolioId,
    PortfolioSummary? initialSummary,
  }) : super(
          initialSummary == null
              ? const AsyncLoading()
              : AsyncValue.data(initialSummary),
        );

  final Ref ref;
  final String portfolioId;

  Future<void> load() async {
    final api = ref.read(portfolioApiProvider);
    final token = ref.read(authTokenProvider);
    if (portfolioId.trim().isEmpty ||
        portfolioId == '00000000-0000-0000-0000-000000000000') {
      state = AsyncError(
        StateError('Missing PORTFOLIO_ID dart-define.'),
        StackTrace.empty,
      );
      return;
    }
    if (token.trim().isEmpty) {
      state = AsyncError(
        StateError('Missing ACCESS_TOKEN dart-define.'),
        StackTrace.empty,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => api.getPortfolioSummary(
        portfolioId: portfolioId,
        accessToken: token,
      ),
    );
    final summary = state.value;
    if (summary != null) {
      _cacheSummary(summary);
    }
  }

  Future<void> refreshWithSync() async {
    final api = ref.read(portfolioApiProvider);
    final token = ref.read(authTokenProvider);
    await api.triggerMarketSync(accessToken: token);
    ref.invalidate(portfolioPositionsProvider(portfolioId));
    ref.invalidate(portfolioManagerControllerProvider);
    ref.invalidate(portfolioListProvider);
    await load();
  }

  Future<void> submitTransactionOptimistic(TransactionRequest request) async {
    final api = ref.read(portfolioApiProvider);
    final token = ref.read(authTokenProvider);
    try {
      await api.submitTransaction(
        portfolioId: portfolioId,
        accessToken: token,
        request: request,
      );
      await load();
    } catch (_) {
      rethrow;
    }
  }

  void _cacheSummary(PortfolioSummary summary) {
    final nextCache = Map<String, PortfolioSummary>.from(
      ref.read(_portfolioSummaryCacheProvider),
    )..[portfolioId] = summary;
    ref.read(_portfolioSummaryCacheProvider.notifier).state = nextCache;
  }
}
