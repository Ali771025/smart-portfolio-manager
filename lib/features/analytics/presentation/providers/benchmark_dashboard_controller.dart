import 'dart:async';
import 'dart:typed_data';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/network/app_failure.dart';
import '../../data/parsers/benchmark_msgpack_isolate_pipeline.dart';
import '../../domain/models/benchmark_chart_series.dart';
import '../../domain/models/benchmark_dashboard_state.dart';

part 'benchmark_dashboard_controller.g.dart';

@Riverpod(keepAlive: true)
class BenchmarkDashboardController extends _$BenchmarkDashboardController {
  @override
  Future<BenchmarkDashboardState> build(String portfolioId) async {
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      providerName: 'benchmarkDashboardControllerProvider',
      portfolioId: portfolioId,
      repositoryMethod: 'BenchmarkDashboardController.build',
      endpointPath: 'local:messagepack-ingest',
    );
    return BenchmarkDashboardState.initial;
  }

  Future<void> ingestMessagePack(
    Uint8List payload, {
    int? maxPointsPerSeries,
  }) async {
    final previous = state.value ?? BenchmarkDashboardState.initial;
    final downsampleTarget = maxPointsPerSeries ?? previous.maxPointsPerSeries;

    state = const AsyncLoading<BenchmarkDashboardState>();
    final decoded = await parseBenchmarkMsgPackToSeries(
      payload,
      maxPointsPerSeries: downsampleTarget,
    );

    state = decoded.match(
      (failure) => AsyncError<BenchmarkDashboardState>(failure, StackTrace.current),
      (series) {
        final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(
          portfolioId,
        );
        final firstX = _firstX(series);
        final lastX = _lastX(series);
        final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
          <Object?>[
            series.portfolio.length,
            series.totalIndex.length,
            series.equalWeighted.length,
            series.bankDeposit.length,
            series.fixedIncome.length,
            firstX,
            lastX,
            downsampleTarget,
          ],
        );
        ImportAnalyticsRefreshTrace.logProviderDataReady(
          traceId: traceId,
          providerName: 'benchmarkDashboardControllerProvider',
          portfolioId: portfolioId,
          pointCount: series.portfolio.length,
          firstDate: _toUtcDate(firstX),
          lastDate: _toUtcDate(lastX),
          dataFingerprint: fingerprint,
        );
        final next = previous.copyWith(
          series: series,
          maxPointsPerSeries: downsampleTarget,
          clearBrushWindow: true,
          lastUpdatedAt: DateTime.now().toUtc(),
        );
        return AsyncData<BenchmarkDashboardState>(next);
      },
    );
  }

  void toggleLine(BenchmarkLineKind line) {
    final current = state.value;
    if (current == null) {
      return;
    }

    var nextVisible = current.visibleLines;
    if (nextVisible.contains(line)) {
      if (nextVisible.length == 1) {
        return;
      }
      nextVisible = nextVisible.remove(line);
    } else {
      nextVisible = nextVisible.add(line);
    }

    state = AsyncData<BenchmarkDashboardState>(
      current.copyWith(visibleLines: nextVisible),
    );
  }

  void setBrushWindow({
    required double minX,
    required double maxX,
  }) {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (!minX.isFinite || !maxX.isFinite || maxX <= minX) {
      return;
    }

    state = AsyncData<BenchmarkDashboardState>(
      current.copyWith(
        brushWindow: BenchmarkBrushWindow(minX: minX, maxX: maxX),
      ),
    );
  }

  void clearBrushWindow() {
    final current = state.value;
    if (current == null || current.brushWindow == null) {
      return;
    }

    state = AsyncData<BenchmarkDashboardState>(
      current.copyWith(clearBrushWindow: true),
    );
  }
}

@riverpod
IMap<BenchmarkLineKind, IList<FlSpot>> benchmarkVisibleSeries(
  Ref ref,
  String portfolioId,
) {
  ImportAnalyticsRefreshTrace.logProviderFetchStart(
    providerName: 'benchmarkVisibleSeriesProvider',
    portfolioId: portfolioId,
    repositoryMethod: 'derived from benchmarkDashboardControllerProvider',
    endpointPath: 'local:derived-visible-series',
  );
  final dashboard = ref.watch(benchmarkDashboardControllerProvider(portfolioId));
  final model = dashboard.value;
  if (model == null) {
    return const IMapConst<BenchmarkLineKind, IList<FlSpot>>({});
  }

  final visible = model.visibleLines;
  final brush = model.brushWindow;

  IList<FlSpot> selectSpots(BenchmarkLineKind kind) {
    final source = switch (kind) {
      BenchmarkLineKind.portfolio => model.series.portfolio,
      BenchmarkLineKind.totalIndex => model.series.totalIndex,
      BenchmarkLineKind.equalWeighted => model.series.equalWeighted,
      BenchmarkLineKind.bankDeposit => model.series.bankDeposit,
      BenchmarkLineKind.fixedIncome => model.series.fixedIncome,
    };
    if (brush == null || source.isEmpty) {
      return source;
    }
    return _windowSpots(
      source,
      minX: brush.minX,
      maxX: brush.maxX,
    );
  }

  final mapped = <BenchmarkLineKind, IList<FlSpot>>{};
  for (final line in visible) {
    final spots = selectSpots(line);
    if (spots.isNotEmpty) {
      mapped[line] = spots;
    }
  }
  final result = IMap<BenchmarkLineKind, IList<FlSpot>>(mapped);
  final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(portfolioId);
  final pointCount = result.values.fold<int>(
    0,
    (total, item) => total + item.length,
  );
  final firstX = _minX(result);
  final lastX = _maxX(result);
  final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
    <Object?>[
      for (final entry in result.entries) entry.key.name,
      for (final entry in result.entries) entry.value.length,
      firstX,
      lastX,
    ],
  );
  ImportAnalyticsRefreshTrace.logProviderDataReady(
    traceId: traceId,
    providerName: 'benchmarkVisibleSeriesProvider',
    portfolioId: portfolioId,
    pointCount: pointCount,
    firstDate: _toUtcDate(firstX),
    lastDate: _toUtcDate(lastX),
    dataFingerprint: fingerprint,
  );
  return result;
}

@riverpod
AppFailure? benchmarkDashboardFailure(
  Ref ref,
  String portfolioId,
) {
  final error = ref.watch(
    benchmarkDashboardControllerProvider(portfolioId).select((state) => state.error),
  );
  if (error is AppFailure) {
    return error;
  }
  return null;
}

IList<FlSpot> _windowSpots(
  IList<FlSpot> input, {
  required double minX,
  required double maxX,
}) {
  final clipped = <FlSpot>[];
  for (final spot in input) {
    if (spot.x >= minX && spot.x <= maxX) {
      clipped.add(spot);
    }
  }
  if (clipped.isEmpty) {
    return const IListConst<FlSpot>([]);
  }
  return IList<FlSpot>(clipped);
}

double? _firstX(BenchmarkChartSeries series) {
  final values = <double>[
    if (series.portfolio.isNotEmpty) series.portfolio.first.x,
    if (series.totalIndex.isNotEmpty) series.totalIndex.first.x,
    if (series.equalWeighted.isNotEmpty) series.equalWeighted.first.x,
    if (series.bankDeposit.isNotEmpty) series.bankDeposit.first.x,
    if (series.fixedIncome.isNotEmpty) series.fixedIncome.first.x,
  ];
  if (values.isEmpty) {
    return null;
  }
  values.sort();
  return values.first;
}

double? _lastX(BenchmarkChartSeries series) {
  final values = <double>[
    if (series.portfolio.isNotEmpty) series.portfolio.last.x,
    if (series.totalIndex.isNotEmpty) series.totalIndex.last.x,
    if (series.equalWeighted.isNotEmpty) series.equalWeighted.last.x,
    if (series.bankDeposit.isNotEmpty) series.bankDeposit.last.x,
    if (series.fixedIncome.isNotEmpty) series.fixedIncome.last.x,
  ];
  if (values.isEmpty) {
    return null;
  }
  values.sort();
  return values.last;
}

double? _minX(IMap<BenchmarkLineKind, IList<FlSpot>> seriesMap) {
  double? minX;
  for (final series in seriesMap.values) {
    if (series.isEmpty) {
      continue;
    }
    final x = series.first.x;
    if (minX == null || x < minX) {
      minX = x;
    }
  }
  return minX;
}

double? _maxX(IMap<BenchmarkLineKind, IList<FlSpot>> seriesMap) {
  double? maxX;
  for (final series in seriesMap.values) {
    if (series.isEmpty) {
      continue;
    }
    final x = series.last.x;
    if (maxX == null || x > maxX) {
      maxX = x;
    }
  }
  return maxX;
}

DateTime? _toUtcDate(double? epochMs) {
  if (epochMs == null || !epochMs.isFinite) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    epochMs.round(),
    isUtc: true,
  );
}
