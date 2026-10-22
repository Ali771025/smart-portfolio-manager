import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../../../core/theme/financial_palette_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsPerformanceLineChart extends StatefulWidget {
  const AnalyticsPerformanceLineChart({
    required this.points,
    this.portfolioLabel = 'پرتفوی',
    this.benchmarkLabel = 'شاخص مبنا',
    this.portfolioId,
    this.timeframe,
    super.key,
  });

  final List<AnalyticsPerformancePoint> points;
  final String portfolioLabel;
  final String benchmarkLabel;
  final String? portfolioId;
  final AnalyticsTimeframe? timeframe;

  @override
  State<AnalyticsPerformanceLineChart> createState() =>
      _AnalyticsPerformanceLineChartState();
}

class _AnalyticsPerformanceLineChartState
    extends State<AnalyticsPerformanceLineChart> {
  final ValueNotifier<_ChartTouchPayload?> _touchNotifier =
      ValueNotifier<_ChartTouchPayload?>(null);

  @override
  void dispose() {
    _touchNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final financialPalette = context.financialPalette;

    final points = widget.points
        .where((point) => point.portfolioValue.isFinite)
        .toList(growable: false);
    final normalizedPortfolioId = (widget.portfolioId ?? '').trim();
    if (normalizedPortfolioId.isNotEmpty) {
      final window = ImportAnalyticsRefreshTrace.dateWindow(
        points.map((item) => item.date),
      );
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          points.length,
          for (final point in points) point.date.toUtc().millisecondsSinceEpoch,
          for (final point in points) point.portfolioValue,
          for (final point in points) point.benchmarkValue,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'AnalyticsPerformanceLineChart',
        portfolioId: normalizedPortfolioId,
        timeframe: widget.timeframe?.name,
        pointCount: points.length,
        firstDate: window.firstDate,
        lastDate: window.lastDate,
        dataFingerprint: fingerprint,
      );
    }
    if (points.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: Text('داده‌ای برای نمایش نمودار عملکرد موجود نیست.'),
        ),
      );
    }

    final portfolioSpots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.portfolioValue))
        .toList(growable: false);
    final renderPortfolioSpots = _renderableSpots(portfolioSpots);

    final hasBenchmark =
        points.any((point) => point.benchmarkValue?.isFinite ?? false);
    final benchmarkSpots = hasBenchmark
        ? points
            .asMap()
            .entries
            .where((entry) => entry.value.benchmarkValue?.isFinite ?? false)
            .map(
              (entry) => FlSpot(
                entry.key.toDouble(),
                entry.value.benchmarkValue!,
              ),
            )
            .toList(growable: false)
        : const <FlSpot>[];
    final renderBenchmarkSpots = _renderableSpots(benchmarkSpots);

    final allValues = <double>[
      ...portfolioSpots.map((spot) => spot.y),
      if (hasBenchmark) ...benchmarkSpots.map((spot) => spot.y),
    ];

    final minY = allValues.reduce(math.min);
    final maxY = allValues.reduce(math.max);
    final range = (maxY - minY).abs();
    final chartPadding = range < 1
        ? (maxY.abs() * 0.08).clamp(1, double.infinity).toDouble()
        : range * 0.12;
    final chartMinY = minY - chartPadding;
    final chartMaxY = maxY + chartPadding;
    final horizontalInterval = ((chartMaxY - chartMinY) / 4)
        .clamp(1, double.infinity)
        .toDouble();

    return AspectRatio(
      aspectRatio: 1.9,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              ValueListenableBuilder<_ChartTouchPayload?>(
                valueListenable: _touchNotifier,
                builder: (context, payload, _) {
                  return RepaintBoundary(
                    child: LineChart(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      LineChartData(
                        minX: 0,
                        maxX: math.max(1, points.length - 1).toDouble(),
                        minY: chartMinY,
                        maxY: chartMaxY <= chartMinY ? chartMinY + 1 : chartMaxY,
                        extraLinesData: payload == null
                            ? const ExtraLinesData()
                            : ExtraLinesData(
                                extraLinesOnTop: true,
                                horizontalLines: [
                                  HorizontalLine(
                                    y: payload.portfolioValue,
                                    color: customTheme.chartAxis.withValues(alpha: 0.28),
                                    strokeWidth: 1,
                                    dashArray: const [6, 4],
                                  ),
                                ],
                                verticalLines: [
                                  VerticalLine(
                                    x: payload.xIndex.toDouble(),
                                    color: customTheme.chartAxis.withValues(alpha: 0.28),
                                    strokeWidth: 1,
                                    dashArray: const [6, 4],
                                  ),
                                ],
                              ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: horizontalInterval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: customTheme.chartGrid.withValues(alpha: 0.55),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 54,
                              interval: horizontalInterval,
                              getTitlesWidget: (value, _) {
                                return Text(
                                  NumberFormat.compactCurrency(
                                    symbol: '',
                                    decimalDigits: 1,
                                  ).format(value),
                                  style: customTheme.captionStyle.copyWith(
                                    color: customTheme.chartAxis,
                                    fontFeatures: kFinancialNumericFontFeatures,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (points.length / 4)
                                  .clamp(1, points.length.toDouble()),
                              getTitlesWidget: (value, _) {
                                final index = value.round();
                                if (index < 0 || index >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                final date = points[index].date;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat('MM/dd').format(date),
                                    style: customTheme.captionStyle.copyWith(
                                      color: customTheme.chartAxis,
                                      fontFeatures: kFinancialNumericFontFeatures,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchSpotThreshold: 28,
                          handleBuiltInTouches: false,
                          getTouchedSpotIndicator:
                              (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: customTheme.chartAxis.withValues(alpha: 0.3),
                                  strokeWidth: 1,
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter: (_, __, ___, ____) =>
                                      FlDotCirclePainter(
                                    radius: 4.2,
                                    color: customTheme.cardBackground,
                                    strokeWidth: 2.2,
                                    strokeColor: barData.color ??
                                        financialPalette.portfolioLine,
                                  ),
                                ),
                              );
                            }).toList(growable: false);
                          },
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) {
                              _touchNotifier.value = null;
                              return;
                            }

                            final touched = response?.lineBarSpots;
                            if (touched == null || touched.isEmpty) {
                              return;
                            }

                            final portfolioSpot = touched.firstWhere(
                              (spot) => spot.barIndex == 0,
                              orElse: () => touched.first,
                            );

                            final pointIndex = portfolioSpot.x
                                .round()
                                .clamp(0, points.length - 1)
                                .toInt();
                            if (pointIndex < 0 || pointIndex >= points.length) {
                              return;
                            }

                            final benchmarkSpot =
                                touched.where((spot) => spot.barIndex == 1).firstOrNull;
                            final model = points[pointIndex];
                            final benchmarkValue = benchmarkSpot?.y ??
                                ((model.benchmarkValue?.isFinite ?? false)
                                    ? model.benchmarkValue
                                    : null);

                            _touchNotifier.value = _ChartTouchPayload(
                              xIndex: pointIndex,
                              date: model.date,
                              portfolioValue: portfolioSpot.y,
                              benchmarkValue: benchmarkValue,
                            );
                          },
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: renderPortfolioSpots,
                            isCurved: true,
                            curveSmoothness: 0.28,
                            color: financialPalette.portfolioLine,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  financialPalette.portfolioLine.withValues(alpha: 0.34),
                                  financialPalette.portfolioLine.withValues(alpha: 0.05),
                                  financialPalette.portfolioLine.withValues(alpha: 0.01),
                                ],
                              ),
                            ),
                          ),
                          if (hasBenchmark)
                            LineChartBarData(
                              spots: renderBenchmarkSpots,
                              isCurved: true,
                              curveSmoothness: 0.28,
                              color: financialPalette.benchmarkLine.withValues(alpha: 0.9),
                              barWidth: 2,
                              isStrokeCapRound: true,
                              dashArray: const [8, 4],
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<_ChartTouchPayload?>(
                valueListenable: _touchNotifier,
                builder: (context, payload, _) {
                  if (payload == null) {
                    return const SizedBox.shrink();
                  }

                  const width = 198.0;
                  final xRatio = points.length <= 1
                      ? 0.5
                      : (payload.xIndex / (points.length - 1)).clamp(0.0, 1.0);
                  final left = (constraints.maxWidth - width) * xRatio;

                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    left: left.clamp(0, constraints.maxWidth - width),
                    top: 10,
                    width: width,
                    child: _PerformanceTooltip(
                      date: payload.date,
                      portfolioLabel: widget.portfolioLabel,
                      portfolioValue: payload.portfolioValue,
                      benchmarkLabel: widget.benchmarkLabel,
                      benchmarkValue: payload.benchmarkValue,
                      hasBenchmark: hasBenchmark,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PerformanceTooltip extends StatelessWidget {
  const _PerformanceTooltip({
    required this.date,
    required this.portfolioLabel,
    required this.portfolioValue,
    required this.benchmarkLabel,
    required this.benchmarkValue,
    required this.hasBenchmark,
  });

  final DateTime date;
  final String portfolioLabel;
  final double portfolioValue;
  final String benchmarkLabel;
  final double? benchmarkValue;
  final bool hasBenchmark;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final compact = NumberFormat.compactCurrency(symbol: '', decimalDigits: 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: customTheme.cardBackground.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: customTheme.cardStroke.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: customTheme.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('yyyy/MM/dd').format(date),
              style: customTheme.captionStyle.copyWith(
                color: customTheme.chartAxis,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$portfolioLabel: ${compact.format(portfolioValue)}',
              style: customTheme.bodyStyle.copyWith(
                color: customTheme.primarySemantic,
                fontWeight: FontWeight.w700,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$benchmarkLabel: ${hasBenchmark && benchmarkValue != null ? compact.format(benchmarkValue) : '-'}',
              style: customTheme.bodyStyle.copyWith(
                color: customTheme.chartAxis.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<FlSpot> _renderableSpots(List<FlSpot> spots) {
  if (spots.length != 1) {
    return spots;
  }
  final point = spots.first;
  return <FlSpot>[
    point,
    FlSpot(point.x + 1, point.y),
  ];
}

class _ChartTouchPayload {
  const _ChartTouchPayload({
    required this.xIndex,
    required this.date,
    required this.portfolioValue,
    required this.benchmarkValue,
  });

  final int xIndex;
  final DateTime date;
  final double portfolioValue;
  final double? benchmarkValue;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
