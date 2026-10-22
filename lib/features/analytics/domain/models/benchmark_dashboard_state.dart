import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'benchmark_chart_series.dart';

enum BenchmarkLineKind {
  portfolio,
  totalIndex,
  equalWeighted,
  bankDeposit,
  fixedIncome,
}

class BenchmarkBrushWindow {
  const BenchmarkBrushWindow({
    required this.minX,
    required this.maxX,
  });

  final double minX;
  final double maxX;

  BenchmarkBrushWindow copyWith({
    double? minX,
    double? maxX,
  }) {
    return BenchmarkBrushWindow(
      minX: minX ?? this.minX,
      maxX: maxX ?? this.maxX,
    );
  }
}

class BenchmarkDashboardState {
  const BenchmarkDashboardState({
    required this.series,
    required this.visibleLines,
    required this.maxPointsPerSeries,
    this.brushWindow,
    this.lastUpdatedAt,
  });

  final BenchmarkChartSeries series;
  final ISet<BenchmarkLineKind> visibleLines;
  final int maxPointsPerSeries;
  final BenchmarkBrushWindow? brushWindow;
  final DateTime? lastUpdatedAt;

  static final BenchmarkDashboardState initial = BenchmarkDashboardState(
    series: BenchmarkChartSeries.empty,
    visibleLines: ISet<BenchmarkLineKind>(
      const <BenchmarkLineKind>[
        BenchmarkLineKind.portfolio,
        BenchmarkLineKind.totalIndex,
      ],
    ),
    maxPointsPerSeries: 500,
  );

  BenchmarkDashboardState copyWith({
    BenchmarkChartSeries? series,
    ISet<BenchmarkLineKind>? visibleLines,
    int? maxPointsPerSeries,
    BenchmarkBrushWindow? brushWindow,
    bool clearBrushWindow = false,
    DateTime? lastUpdatedAt,
  }) {
    return BenchmarkDashboardState(
      series: series ?? this.series,
      visibleLines: visibleLines ?? this.visibleLines,
      maxPointsPerSeries: maxPointsPerSeries ?? this.maxPointsPerSeries,
      brushWindow: clearBrushWindow ? null : (brushWindow ?? this.brushWindow),
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
