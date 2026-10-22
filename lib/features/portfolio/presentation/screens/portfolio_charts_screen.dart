import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/portfolio_chart_models.dart';
import '../providers/portfolio_chart_providers.dart';

class PortfolioChartsScreen extends ConsumerWidget {
  const PortfolioChartsScreen({super.key, required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            const SliverAppBar(pinned: true, title: Text('نمودارها'), bottom: TabBar(isScrollable: true, tabs: [Tab(text: 'رشد سرمایه'), Tab(text: 'ارزش دارایی‌ها'), Tab(text: 'عملکرد سهام'), Tab(text: 'بازدهی ماهانه')])),
          ],
          body: TabBarView(children: [
            _CapitalGrowthTab(portfolioId: portfolioId),
            _AssetValueTab(portfolioId: portfolioId),
            _SymbolPerformanceTab(portfolioId: portfolioId),
            _MonthlyReturnsTab(portfolioId: portfolioId),
          ]),
        ),
      ),
    );
  }
}

class _CapitalGrowthTab extends ConsumerWidget {
  const _CapitalGrowthTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(capitalGrowthChartProvider((portfolioId: portfolioId, period: '1Y')));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        return _ChartPagePadding(
          child: _CapitalGrowthChart(response: data),
        );
      },
    );
  }
}

class _AssetValueTab extends ConsumerWidget {
  const _AssetValueTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(assetValueChartProvider((portfolioId: portfolioId, period: '1Y')));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        return _ChartPagePadding(
          child: _SeriesLineChart(
            title: 'ارزش دارایی‌ها در طول زمان',
            response: data,
            currency: true,
          ),
        );
      },
    );
  }
}

class _SymbolPerformanceTab extends ConsumerWidget {
  const _SymbolPerformanceTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(symbolPerformanceChartProvider((portfolioId: portfolioId, period: '1Y')));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        return _ChartPagePadding(
          child: _SeriesLineChart(
            title: 'عملکرد سهام',
            response: data,
            currency: false,
          ),
        );
      },
    );
  }
}

class _MonthlyReturnsTab extends ConsumerWidget {
  const _MonthlyReturnsTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(monthlyReturnsChartProvider((portfolioId: portfolioId, year: null)));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        final monthly = data.portfolioMonthlyReturns;
        return _ChartPagePadding(
          child: _MonthlyReturnsChart(points: monthly),
        );
      },
    );
  }
}

class _ChartPagePadding extends StatelessWidget {
  const _ChartPagePadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [child],
    );
  }
}

class _CapitalGrowthChart extends StatelessWidget {
  const _CapitalGrowthChart({required this.response});

  final CapitalGrowthResponse response;

  @override
  Widget build(BuildContext context) {
    final points = response.points
        .where((point) => point.portfolioValue != null || point.costBasis != null)
        .toList(growable: false);
    if (points.isEmpty) {
      return _EmptyChartCard(
        title: 'رشد سرمایه',
        subtitle: 'برای رسم نمودار، تراکنش یا قیمت تاریخی کافی وجود ندارد.',
      );
    }

    final valueSpots = <FlSpot>[];
    final costSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final value = points[i].portfolioValue;
      final cost = points[i].costBasis;
      if (value != null && value.isFinite) {
        valueSpots.add(FlSpot(i.toDouble(), value));
      }
      if (cost != null && cost.isFinite) {
        costSpots.add(FlSpot(i.toDouble(), cost));
      }
    }

    return _LineChartCard(
      title: 'رشد سرمایه',
      subtitle: _metaText(response.metadata),
      series: [
        _ChartLine(label: 'ارزش پرتفوی', color: const Color(0xFF2563EB), spots: valueSpots),
        _ChartLine(label: 'بهای تمام‌شده', color: const Color(0xFF64748B), spots: costSpots),
      ],
      currency: true,
    );
  }
}

class _SeriesLineChart extends StatelessWidget {
  const _SeriesLineChart({
    required this.title,
    required this.response,
    required this.currency,
  });

  final String title;
  final PortfolioChartResponse response;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    final lines = <_ChartLine>[];
    for (var i = 0; i < response.series.length; i++) {
      final source = response.series[i];
      final spots = <FlSpot>[];
      for (var j = 0; j < source.dataPoints.length; j++) {
        final value = source.dataPoints[j].value;
        if (value != null && value.isFinite) {
          spots.add(FlSpot(j.toDouble(), value));
        }
      }
      if (spots.isNotEmpty) {
        lines.add(_ChartLine(
          label: source.name.isNotEmpty ? source.name : source.key,
          color: _palette[i % _palette.length],
          spots: spots,
        ));
      }
    }

    if (lines.isEmpty) {
      return _EmptyChartCard(
        title: title,
        subtitle: 'داده قابل رسم برای این نمودار وجود ندارد.',
      );
    }

    return _LineChartCard(
      title: title,
      subtitle: _metaText(response.metadata),
      series: lines,
      currency: currency,
    );
  }
}

class _MonthlyReturnsChart extends StatelessWidget {
  const _MonthlyReturnsChart({required this.points});

  final List<MonthlyReturnPoint> points;

  @override
  Widget build(BuildContext context) {
    final drawable = points
        .where((point) => point.returnPct?.isFinite ?? false)
        .toList(growable: false);
    if (drawable.isEmpty) {
      return const _EmptyChartCard(
        title: 'بازدهی ماهانه',
        subtitle: 'بازده ماهانه قابل محاسبه نیست.',
      );
    }

    final values = drawable.map((point) => point.returnPct ?? 0).toList();
    final minY = math.min(0, values.reduce(math.min)) * 1.2;
    final maxY = math.max(0, values.reduce(math.max)) * 1.2;
    final range = _normalizeRange(minY, maxY);

    return _ChartShell(
      title: 'بازدهی ماهانه',
      subtitle: '${drawable.length} ماه دارای داده',
      child: BarChart(
        BarChartData(
          minY: range.$1,
          maxY: range.$2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  '${value.toStringAsFixed(0)}٪',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= drawable.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${drawable[index].month}',
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < drawable.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: drawable[i].returnPct ?? 0,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                    color: (drawable[i].returnPct ?? 0) >= 0
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.title,
    required this.subtitle,
    required this.series,
    required this.currency,
  });

  final String title;
  final String subtitle;
  final List<_ChartLine> series;
  final bool currency;

  @override
  Widget build(BuildContext context) {
    final visible = series
        .map(
          (line) => _ChartLine(
            label: line.label,
            color: line.color,
            spots: line.spots
                .where((spot) => spot.x.isFinite && spot.y.isFinite)
                .toList(growable: false),
          ),
        )
        .where((line) => line.spots.length >= 2)
        .toList();
    final allSpots = visible.expand((line) => line.spots).toList();
    if (allSpots.isEmpty) {
      return _EmptyChartCard(title: title, subtitle: 'داده قابل رسم وجود ندارد.');
    }

    final minX = allSpots.map((spot) => spot.x).reduce(math.min);
    final maxX = allSpots.map((spot) => spot.x).reduce(math.max);
    final minY = allSpots.map((spot) => spot.y).reduce(math.min);
    final maxY = allSpots.map((spot) => spot.y).reduce(math.max);
    final yRange = _normalizeRange(minY, maxY);
    final xRange = _normalizeRange(minX, maxX);

    return _ChartShell(
      title: title,
      subtitle: subtitle,
      legend: visible,
      child: LineChart(
        LineChartData(
          minX: xRange.$1,
          maxX: xRange.$2,
          minY: yRange.$1,
          maxY: yRange.$2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 58,
                getTitlesWidget: (value, _) => Text(
                  currency ? _compactMoney(value) : value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
              getTooltipItems: (items) => items
                  .map((item) => LineTooltipItem(
                        currency
                            ? _formatNumber(item.y)
                            : item.y.toStringAsFixed(2),
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            for (final line in visible)
              LineChartBarData(
                spots: line.spots,
                isCurved: line.spots.length > 2,
                preventCurveOverShooting: true,
                color: line.color,
                barWidth: 2.4,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: visible.length == 1,
                  color: line.color.withValues(alpha: 0.12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  const _ChartShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.legend = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<_ChartLine> legend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  for (final item in legend.take(8))
                    _LegendDot(label: item.label, color: item.color),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(height: 320, child: child),
          ],
        ),
      ),
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  const _EmptyChartCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.show_chart_rounded, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _ChartLine {
  const _ChartLine({
    required this.label,
    required this.color,
    required this.spots,
  });

  final String label;
  final Color color;
  final List<FlSpot> spots;
}

const _palette = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFDC2626),
  Color(0xFF9333EA),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
  Color(0xFF4F46E5),
  Color(0xFF65A30D),
];

(double, double) _normalizeRange(double min, double max) {
  if (!min.isFinite || !max.isFinite) return (0, 1);
  if (min == max) {
    final pad = min.abs() < 1 ? 1.0 : min.abs() * 0.08;
    return (min - pad, max + pad);
  }
  final pad = (max - min).abs() * 0.08;
  return (min - pad, max + pad);
}

String _metaText(ChartMetadata metadata) {
  return '${metadata.availableDataPoints}/${metadata.totalDataPoints} نقطه داده • ${_completenessLabel(metadata.completeness)}';
}

String _completenessLabel(String value) {
  return switch (value) {
    'complete' => 'کامل',
    'partial' => 'نسبی',
    'insufficient' => 'ناکافی',
    _ => value,
  };
}

String _compactMoney(double value) {
  final abs = value.abs();
  if (abs >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}

String _formatNumber(double value) {
  if (!value.isFinite) return '0';
  final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  final parts = text.split('.');
  final sign = parts.first.startsWith('-') ? '-' : '';
  final digits = parts.first.replaceFirst('-', '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '$sign$buffer${parts.length > 1 ? '.${parts[1]}' : ''}';
}
