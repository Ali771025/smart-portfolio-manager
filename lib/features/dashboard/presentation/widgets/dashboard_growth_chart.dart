import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../domain/models/dashboard_state.dart';
import 'dashboard_glass_card.dart';
import 'asset_allocation_chart.dart';

class DashboardGrowthChart extends StatelessWidget {
  const DashboardGrowthChart({
    required this.points,
    required this.currency,
    this.portfolioId,
    super.key,
  });

  final List<GrowthPoint> points;
  final String currency;
  final String? portfolioId;

  @override
  Widget build(BuildContext context) {
    final validPoints = points
        .where(
          (point) =>
              point.totalValue.isFinite &&
              point.totalValue >= 0 &&
              point.date.isNotEmpty,
        )
        .toList(growable: false);
    final normalizedPortfolioId = (portfolioId ?? '').trim();
    if (kDebugMode && normalizedPortfolioId.isNotEmpty) {
      final parsedDates = validPoints
          .map((item) => DateTime.tryParse(item.date))
          .whereType<DateTime>()
          .map((item) => item.toUtc());
      final window = ImportAnalyticsRefreshTrace.dateWindow(parsedDates);
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          validPoints.length,
          for (final point in validPoints) point.date,
          for (final point in validPoints) point.totalValue,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'DashboardGrowthChart',
        portfolioId: normalizedPortfolioId,
        pointCount: validPoints.length,
        firstDate: window.firstDate,
        lastDate: window.lastDate,
        dataFingerprint: fingerprint,
      );
    }
    if (validPoints.length < 2) {
      return const DashboardEmptyState(
        title: 'تاریخچه رشد کافی نیست',
        subtitle: 'پس از ثبت اسنپ‌شات‌های واقعی، نمودار رشد در این بخش نمایش داده می‌شود.',
      );
    }

    final spots = validPoints
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.totalValue))
        .toList(growable: false);
    final rawMinY = spots.map((item) => item.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = spots.map((item) => item.y).reduce((a, b) => a > b ? a : b);
    final range = (rawMaxY - rawMinY).abs();
    final padding = range <= 0
        ? (rawMaxY.abs() * 0.08).clamp(1, double.infinity).toDouble()
        : range * 0.12;
    final minY = (rawMinY - padding).clamp(0, double.infinity).toDouble();
    final maxY = rawMaxY + padding;
    final interval = ((maxY - minY).abs() / 4).clamp(1, double.infinity).toDouble();
    final money = NumberFormat.compactCurrency(
      locale: 'fa_IR',
      symbol: '$currency ',
      decimalDigits: 0,
    );

    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'روند ۳۰ روزه ارزش پرتفوی',
            style: AppTypography.sectionTitle(Theme.of(context).textTheme),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY <= minY ? minY + 1 : maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 58,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: LtrLogText(
                          money.format(value),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (spots.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= validPoints.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: LtrLogText(
                            validPoints[index].date,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.96),
                    tooltipBorderRadius: BorderRadius.circular(12),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((item) {
                        final point = validPoints[item.x.toInt()];
                        return LineTooltipItem(
                          '${point.date}\n${money.format(item.y)}',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(growable: false);
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF38BDF8),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF38BDF8).withValues(alpha: 0.26),
                          const Color(0xFF38BDF8).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 820),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
