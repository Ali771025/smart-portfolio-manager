import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsDrawdownAreaChart extends StatelessWidget {
  const AnalyticsDrawdownAreaChart({
    required this.points,
    this.portfolioId,
    this.timeframe,
    super.key,
  });

  final List<AnalyticsPerformancePoint> points;
  final String? portfolioId;
  final AnalyticsTimeframe? timeframe;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final drawdownPoints = _buildDrawdownSeries(points);
    final normalizedPortfolioId = (portfolioId ?? '').trim();
    if (kDebugMode && normalizedPortfolioId.isNotEmpty) {
      final window = ImportAnalyticsRefreshTrace.dateWindow(
        drawdownPoints.map((point) => point.date),
      );
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          drawdownPoints.length,
          for (final point in drawdownPoints) point.date.toUtc().millisecondsSinceEpoch,
          for (final point in drawdownPoints) point.drawdownPct,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'AnalyticsDrawdownAreaChart',
        portfolioId: normalizedPortfolioId,
        timeframe: timeframe?.name,
        pointCount: drawdownPoints.length,
        firstDate: window.firstDate,
        lastDate: window.lastDate,
        dataFingerprint: fingerprint,
      );
    }
    if (drawdownPoints.isEmpty) {
      return const SizedBox(
        height: 230,
        child: Center(
          child: Text('داده‌ای برای نمایش افت سرمایه موجود نیست.'),
        ),
      );
    }

    final spots = drawdownPoints
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.drawdownPct))
        .toList(growable: false);
    final renderSpots = _renderableDrawdownSpots(spots);

    final minDrawdown = drawdownPoints
        .map((point) => point.drawdownPct)
        .fold<double>(0, (minValue, value) => math.min(minValue, value));

    final minY = (minDrawdown * 1.12).clamp(-100.0, 0.0).toDouble();
    final maxY = 1.5;
    final interval =
        ((maxY - minY) / 4).abs().clamp(2.0, double.infinity).toDouble();

    return AspectRatio(
      aspectRatio: 1.9,
      child: RepaintBoundary(
        child: LineChart(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          LineChartData(
          minX: 0,
          maxX: math.max(1, drawdownPoints.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: value == 0
                  ? customTheme.dangerSemantic.withValues(alpha: 0.34)
                  : customTheme.chartGrid.withValues(alpha: 0.5),
              strokeWidth: value == 0 ? 1.4 : 1,
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
                reservedSize: 56,
                interval: interval,
                getTitlesWidget: (value, _) {
                  return Text(
                    '${value.toStringAsFixed(0)}%',
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
                interval: (drawdownPoints.length / 4)
                    .clamp(1, drawdownPoints.length)
                    .toDouble(),
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= drawdownPoints.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd').format(drawdownPoints[index].date),
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
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => customTheme.cardBackground,
              tooltipBorder: BorderSide(
                color: customTheme.cardStroke.withValues(alpha: 0.86),
              ),
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x
                      .round()
                      .clamp(0, drawdownPoints.length - 1)
                      .toInt();
                  final model = drawdownPoints[index];
                  final drawdownText =
                      '${model.drawdownPct.toStringAsFixed(2)}%';
                  return LineTooltipItem(
                    '${DateFormat('yyyy/MM/dd').format(model.date)}\n$drawdownText',
                    customTheme.bodyStyle.copyWith(
                      color: customTheme.dangerSemantic,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kFinancialNumericFontFeatures,
                    ),
                  );
                }).toList(growable: false);
              },
            ),
            getTouchedSpotIndicator:
                (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes
                  .map(
                    (index) => TouchedSpotIndicatorData(
                      FlLine(
                        color: customTheme.chartAxis.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 4.2,
                          color: customTheme.cardBackground,
                          strokeWidth: 2,
                          strokeColor: customTheme.dangerSemantic,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false);
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: renderSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: customTheme.dangerSemantic,
              barWidth: 2.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    customTheme.dangerSemantic.withValues(alpha: 0.06),
                    customTheme.dangerSemantic.withValues(alpha: 0.2),
                    customTheme.dangerSemantic.withValues(alpha: 0.36),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _DrawdownPoint {
  const _DrawdownPoint({
    required this.date,
    required this.drawdownPct,
  });

  final DateTime date;
  final double drawdownPct;
}

List<_DrawdownPoint> _buildDrawdownSeries(
  List<AnalyticsPerformancePoint> points,
) {
  if (points.isEmpty) {
    return const <_DrawdownPoint>[];
  }

  final sorted = points
      .where((point) => point.portfolioValue.isFinite)
      .toList(growable: false)
    ..sort(
      (left, right) => left.date.compareTo(right.date),
    );
  if (sorted.isEmpty) {
    return const <_DrawdownPoint>[];
  }

  double peak = math.max(sorted.first.portfolioValue, 0);
  final result = <_DrawdownPoint>[];

  for (final point in sorted) {
    peak = math.max(peak, point.portfolioValue);
    if (peak <= 0 || point.portfolioValue <= 0) {
      result.add(
        _DrawdownPoint(
          date: point.date,
          drawdownPct: 0,
        ),
      );
      continue;
    }

    final drawdown = ((point.portfolioValue / peak) - 1) * 100;
    result.add(
      _DrawdownPoint(
        date: point.date,
        drawdownPct: drawdown.clamp(-100, 0).toDouble(),
      ),
    );
  }

  return result;
}

List<FlSpot> _renderableDrawdownSpots(List<FlSpot> spots) {
  if (spots.length != 1) {
    return spots;
  }
  final point = spots.first;
  return <FlSpot>[
    point,
    FlSpot(point.x + 1, point.y),
  ];
}
