import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/network/app_failure.dart';
import '../../data/analytics_repository.dart';
import '../../domain/models/analytics_models.dart';
import '../../domain/models/realtime_pnl_tick.dart';

part 'analytics_controller.g.dart';

@Riverpod(keepAlive: true)
class AnalyticsController extends _$AnalyticsController {
  AnalyticsRepository get _repository => ref.read(analyticsRepositoryProvider);

  AnalyticsTimeframe _selectedTimeframe = AnalyticsTimeframe.oneMonth;
  StreamSubscription<Either<AppFailure, RealtimePnlTick>>?
      _realtimeSubscription;
  bool _isObserved = true;

  @override
  Future<AnalyticsViewState> build(String portfolioId) async {
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      providerName: 'analyticsControllerProvider',
      portfolioId: portfolioId,
      timeframe: _selectedTimeframe.name,
      repositoryMethod: 'AnalyticsController.build',
      endpointPath: '/analytics/performance|/analytics/metrics|/dashboard/overview',
    );
    ref.onCancel(() {
      _isObserved = false;
      _cancelRealtimePnlStream();
    });
    ref.onResume(() {
      _isObserved = true;
      if (state.hasValue) {
        _bindRealtimePnlStream();
      }
    });
    ref.onDispose(() {
      _isObserved = false;
      _cancelRealtimePnlStream();
    });

    final initialResult = await _loadEither();
    final initialState = initialResult.match(
      (failure) => throw failure,
      (viewState) => viewState,
    );

    if (_isObserved) {
      _bindRealtimePnlStream();
    }
    return initialState;
  }

  AnalyticsTimeframe get selectedTimeframe => _selectedTimeframe;

  Future<void> selectTimeframe(AnalyticsTimeframe nextTimeframe) async {
    if (nextTimeframe == _selectedTimeframe && state.hasValue) {
      return;
    }

    _selectedTimeframe = nextTimeframe;
    await _refresh();
  }

  Future<void> reload() => _refresh();

  Future<void> _refresh() async {
    state = const AsyncValue<AnalyticsViewState>.loading();
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      providerName: 'analyticsControllerProvider',
      portfolioId: portfolioId,
      timeframe: _selectedTimeframe.name,
      repositoryMethod: 'AnalyticsController.reload',
      endpointPath: '/analytics/performance|/analytics/metrics|/dashboard/overview',
    );

    final result = await _loadEither();
    state = result.match(
      (failure) => AsyncValue<AnalyticsViewState>.error(
        failure,
        StackTrace.current,
      ),
      AsyncValue<AnalyticsViewState>.data,
    );

    if (state.hasValue && _isObserved) {
      _bindRealtimePnlStream();
    }
  }

  Future<Either<AppFailure, AnalyticsViewState>> _loadEither() async {
    final performanceFuture = _repository.fetchPerformance(
      portfolioId: portfolioId,
      timeframe: _selectedTimeframe,
    );
    final metricsFuture = _repository.fetchMetrics(
      portfolioId: portfolioId,
      timeframe: _selectedTimeframe,
    );
    final allocationFuture = _repository.fetchAllocation(
      portfolioId: portfolioId,
    );

    final performanceResult = await performanceFuture;
    final metricsResult = await metricsFuture;
    final allocationResult = await allocationFuture;

    final merged = performanceResult.flatMap(
      (performance) => metricsResult.flatMap(
        (metrics) => allocationResult.map(
          (allocation) => AnalyticsViewState(
            selectedTimeframe: _selectedTimeframe,
            performanceSeries: performance,
            metrics: metrics,
            allocation: allocation,
          ),
        ),
      ),
    );
    final currentTraceId =
        ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);
    merged.match((_) {}, (viewState) {
      final points = viewState.performanceSeries.points;
      final window = ImportAnalyticsRefreshTrace.dateWindow(
        points.map((point) => point.date),
      );
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          viewState.performanceSeries.portfolioId,
          viewState.selectedTimeframe.name,
          points.length,
          points.isEmpty ? null : points.first.date.toUtc().millisecondsSinceEpoch,
          points.isEmpty ? null : points.last.date.toUtc().millisecondsSinceEpoch,
          points.isEmpty ? null : points.last.portfolioValue,
          viewState.metrics.pnl,
          viewState.allocation.length,
        ],
      );
      ImportAnalyticsRefreshTrace.logProviderDataReady(
        traceId: currentTraceId,
        providerName: 'analyticsControllerProvider',
        portfolioId: portfolioId,
        timeframe: viewState.selectedTimeframe.name,
        pointCount: points.length,
        firstDate: window.firstDate,
        lastDate: window.lastDate,
        dataFingerprint: fingerprint,
      );
    });
    return merged;
  }

  void _bindRealtimePnlStream() {
    _cancelRealtimePnlStream();
    _realtimeSubscription = _repository
        .watchRealtimePnl(portfolioId: portfolioId)
        .listen((event) {
      event.match(
        (_) {
          // Preserve previous successful data on transient stream failures.
        },
        (tick) {
          final current = state.value;
          if (current == null) {
            return;
          }

          final updatedPoints =
              List<AnalyticsPerformancePoint>.of(current.performanceSeries.points);
          if (updatedPoints.isNotEmpty) {
            final lastIndex = updatedPoints.length - 1;
            final lastPoint = updatedPoints[lastIndex];
            updatedPoints[lastIndex] = lastPoint.copyWith(
              portfolioValue: tick.totalNav,
              pnl: tick.totalPnl,
            );
          }

          final updatedSeries = current.performanceSeries.copyWith(
            points: updatedPoints,
          );
          final updatedMetrics = current.metrics.copyWith(
            pnl: tick.totalPnl,
          );

          state = AsyncValue.data(
            current.copyWith(
              performanceSeries: updatedSeries,
              metrics: updatedMetrics,
            ),
          );
        },
      );
    }, onError: (Object _, StackTrace __) {
      // A transient SSE transport failure must not escape into Flutter's zone.
      // The last successful analytics snapshot remains available to the UI.
    });
  }

  void _cancelRealtimePnlStream() {
    final subscription = _realtimeSubscription;
    _realtimeSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}

@riverpod
AnalyticsTimeframe analyticsSelectedTimeframe(
  Ref ref,
  String portfolioId,
) {
  return ref.watch(
    analyticsControllerProvider(portfolioId).select(
      (state) =>
          state.value?.selectedTimeframe ?? AnalyticsTimeframe.oneMonth,
    ),
  );
}

@riverpod
AppFailure? analyticsFailure(
  Ref ref,
  String portfolioId,
) {
  final error = ref.watch(
    analyticsControllerProvider(portfolioId).select((state) => state.error),
  );
  if (error is AppFailure) {
    return error;
  }
  return null;
}

final analyticsDataProvider = analyticsControllerProvider;
