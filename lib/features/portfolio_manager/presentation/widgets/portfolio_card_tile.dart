import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/portfolio_card_dto.dart';

class PortfolioCardTile extends StatelessWidget {
  const PortfolioCardTile({
    required this.item,
    this.onDelete,
    super.key,
  });

  final PortfolioCardDto item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fintech = context.fintechColors;
    final positive = item.roiPercent >= 0;
    final roiColor = positive ? fintech.pnlSuccess : fintech.pnlDanger;
    final sparklineSpots = _sparklineSpots(item.sparklineValues, item.totalValue);
    final sparklineBounds = _bounds(sparklineSpots);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isDefault
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (item.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'پیش‌فرض',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'حذف پرتفو',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: scheme.error,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _Formatters.currency(item.totalValue),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: LineChart(
                LineChartData(
                  minY: sparklineBounds.$1,
                  maxY: sparklineBounds.$2,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sparklineSpots,
                      isCurved: true,
                      color: const Color(0xFF38BDF8),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Badge(
                  label: 'ROI',
                  value: '${_Formatters.percent(item.roiPercent)}٪',
                  color: roiColor,
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: 'Risk',
                  value: '${_Formatters.percent(item.riskStdDeviation)}٪',
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _sparklineSpots(List<double> values, double fallbackValue) {
    final clean = values.where((value) => value.isFinite).toList(growable: false);
    if (clean.length >= 2) {
      return clean
          .asMap()
          .entries
          .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
          .toList(growable: false);
    }

    final value = fallbackValue.isFinite && fallbackValue > 0 ? fallbackValue : 0.0;
    return <FlSpot>[
      FlSpot(0, value),
      FlSpot(1, value),
    ];
  }

  (double, double) _bounds(List<FlSpot> spots) {
    final minY = spots.map((item) => item.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((item) => item.y).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range <= 0
        ? (maxY.abs() * 0.08).clamp(1, double.infinity).toDouble()
        : range * 0.12;
    final bottom = minY - padding;
    final top = maxY + padding;
    return (bottom, top <= bottom ? bottom + 1 : top);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'fa_IR',
    symbol: 'ریال ',
    decimalDigits: 2,
  );
  static final NumberFormat _percent = NumberFormat('#,##0.00', 'fa_IR');

  static String currency(double value) => _currency.format(value);
  static String percent(double value) => _percent.format(value);
}
