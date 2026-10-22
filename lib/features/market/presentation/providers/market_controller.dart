/// Market data controller using Riverpod.
///
/// Manages state for:
/// - Live market snapshots
/// - Market status and freshness
/// - Symbol history
/// - Index snapshots
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/app_failure.dart';
import '../../data/market_repository.dart';
import '../../domain/models/market_models.dart';

part 'market_controller.g.dart';

/// State for live market data.
class MarketLiveState {
  const MarketLiveState({
    this.snapshots = const {},
    this.watch,
    this.overview,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  final Map<String, LiveMarketSnapshot> snapshots;
  final MarketWatchResponse? watch;
  final MarketOverview? overview;
  final bool isLoading;
  final AppFailure? error;
  final DateTime? lastUpdated;

  MarketLiveState copyWith({
    Map<String, LiveMarketSnapshot>? snapshots,
    MarketWatchResponse? watch,
    MarketOverview? overview,
    bool? isLoading,
    AppFailure? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return MarketLiveState(
      snapshots: snapshots ?? this.snapshots,
      watch: watch ?? this.watch,
      overview: overview ?? this.overview,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// State for market status.
class MarketStatusState {
  const MarketStatusState({
    this.status,
    this.isLoading = false,
    this.error,
  });

  final MarketStatus? status;
  final bool isLoading;
  final AppFailure? error;

  MarketStatusState copyWith({
    MarketStatus? status,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) {
    return MarketStatusState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for live market data.
@Riverpod(keepAlive: true)
class MarketLiveController extends _$MarketLiveController {
  @override
  MarketLiveState build() {
    return const MarketLiveState();
  }

  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  Future<void> fetchOverviewAndWatch({
    int page = 1,
    int pageSize = 80,
    bool compact = true,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final overviewResult = await _repository.getMarketOverview();
    final watchResult = await _repository.getMarketWatch(
      page: page,
      pageSize: pageSize,
      compact: compact,
    );

    AppFailure? failure;
    MarketOverview? overview = state.overview;
    MarketWatchResponse? watch = state.watch;

    overviewResult.fold((item) => failure ??= item, (item) => overview = item);
    watchResult.fold((item) => failure ??= item, (item) => watch = item);

    final snapshots = <String, LiveMarketSnapshot>{};
    for (final quote in watch?.items ?? const <MarketQuote>[]) {
      snapshots[quote.instrumentId ?? quote.symbol] =
          LiveMarketSnapshot.fromJson({
        'symbol': quote.symbol,
        'instrument_id': quote.instrumentId,
        'last_price': quote.lastPrice,
        'closing_price': quote.closingPrice,
        'volume': quote.volume,
        'event_time': quote.eventTime?.toIso8601String(),
        'received_at': quote.receivedAt?.toIso8601String(),
        'is_stale': quote.isStale,
      });
    }

    state = state.copyWith(
      isLoading: false,
      overview: overview,
      watch: watch,
      snapshots: snapshots.isEmpty ? state.snapshots : snapshots,
      error: failure,
      lastUpdated: DateTime.now().toUtc(),
      clearError: failure == null,
    );
  }

  /// Fetch live snapshot for a single instrument.
  Future<void> fetchLiveSnapshot(String insCode) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getLiveSnapshot(insCode: insCode);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure,
      ),
      (snapshot) {
        final updated = Map<String, LiveMarketSnapshot>.from(state.snapshots);
        updated[insCode] = snapshot;
        state = state.copyWith(
          isLoading: false,
          snapshots: updated,
          lastUpdated: DateTime.now().toUtc(),
          clearError: true,
        );
      },
    );
  }

  /// Fetch live snapshots for multiple instruments.
  Future<void> fetchLiveBatch(List<String> insCodes) async {
    if (insCodes.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getLiveBatch(insCodes: insCodes);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure,
      ),
      (batch) {
        final updated = Map<String, LiveMarketSnapshot>.from(state.snapshots);
        for (final snapshot in batch.snapshots) {
          updated[snapshot.insCode] = snapshot;
        }
        state = state.copyWith(
          isLoading: false,
          snapshots: updated,
          lastUpdated: DateTime.now().toUtc(),
          clearError: true,
        );
      },
    );
  }

  /// Get snapshot for a specific instrument (from cache).
  LiveMarketSnapshot? getSnapshot(String insCode) {
    return state.snapshots[insCode];
  }

  /// Clear all cached snapshots.
  void clearCache() {
    state = const MarketLiveState();
  }
}

/// Controller for market status.
@Riverpod(keepAlive: true)
class MarketStatusController extends _$MarketStatusController {
  Timer? _refreshTimer;

  @override
  MarketStatusState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
    return const MarketStatusState();
  }

  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  /// Fetch market status.
  Future<void> fetchStatus() async {
    state = state.copyWith(isLoading: true);

    final result = await _repository.getMarketStatus();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure,
      ),
      (status) => state = state.copyWith(
        isLoading: false,
        status: status,
      ),
    );
  }

  /// Start periodic status refresh.
  void startPeriodicRefresh({Duration interval = const Duration(minutes: 1)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => fetchStatus());
    fetchStatus(); // Initial fetch
  }

  /// Stop periodic refresh.
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}

/// Controller for symbol history.
@Riverpod(keepAlive: true)
class MarketHistoryController extends _$MarketHistoryController {
  @override
  AsyncValue<SymbolHistory?> build() {
    return const AsyncData(null);
  }

  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  /// Fetch symbol history.
  Future<void> fetchHistory({
    required String symbol,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = const AsyncLoading();

    final result = await _repository.getSymbolHistory(
      symbol: symbol,
      startDate: startDate,
      endDate: endDate,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (history) => AsyncData(history),
    );
  }

  /// Clear history data.
  void clear() {
    state = const AsyncData(null);
  }
}

/// Controller for index snapshots.
@Riverpod(keepAlive: true)
class MarketIndexController extends _$MarketIndexController {
  @override
  Map<String, IndexSnapshot> build() {
    return {};
  }

  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  /// Fetch index snapshot.
  Future<void> fetchIndex(String indexCode) async {
    final result = await _repository.getIndexSnapshot(indexCode: indexCode);

    result.fold(
      (failure) => null, // Silently fail for index snapshots
      (snapshot) {
        final updated = Map<String, IndexSnapshot>.from(state);
        updated[indexCode] = snapshot;
        // Trigger state update
        state = Map.unmodifiable(updated);
      },
    );
  }

  Future<void> fetchIndices() async {
    final result = await _repository.getMarketIndices();
    result.fold(
      (_) => null,
      (indices) {
        state = Map.unmodifiable({
          for (final item in indices) item.indexCode: item,
        });
      },
    );
  }

  /// Get snapshot for a specific index.
  IndexSnapshot? getSnapshot(String indexCode) {
    return state[indexCode];
  }
}
