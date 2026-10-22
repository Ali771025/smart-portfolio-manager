import 'package:fl_chart/fl_chart.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/asset_ledger_models.dart';
import 'lttb_downsample.dart';

class ValuationChartCard extends StatefulWidget {
  const ValuationChartCard({
    required this.points,
    this.endpointMarketValue,
    super.key,
  });

  final List<AssetValuationPointDto> points;
  final Decimal? endpointMarketValue;

  @override
  State<ValuationChartCard> createState() => _ValuationChartCardState();
}

class _ValuationChartCardState extends State<ValuationChartCard> {
  Future<List<LttbOutputPoint>>? _downsampleFuture;

  @override
  void initState() {
    super.initState();
    _downsampleFuture = _buildDownsampleFuture(widget.points);
  }

  @override
  void didUpdateWidget(covariant ValuationChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.endpointMarketValue != widget.endpointMarketValue) {
      _downsampleFuture = _buildDownsampleFuture(widget.points);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نمودار ارزش‌گذاری دارایی',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: FutureBuilder<List<LttbOutputPoint>>(
              future: _downsampleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                final sampled = (snapshot.data ?? const <LttbOutputPoint>[])
                    .where((point) => point.y.isFinite)
                    .toList(growable: false);
                if (sampled.isEmpty) {
                  return const _EmptyChart();
                }

                final spots = sampled
                    .asMap()
                    .entries
                    .map((entry) => FlSpot(entry.key.toDouble(), entry.value.y))
                    .toList(growable: false);

                var minY = sampled.first.y;
                var maxY = sampled.first.y;
                for (final row in sampled) {
                  if (row.y < minY) {
                    minY = row.y;
                  }
                  if (row.y > maxY) {
                    maxY = row.y;
                  }
                }

                final range = (maxY - minY).abs();
                final padding = range <= 0
                    ? (maxY.abs() * 0.08).clamp(1.0, double.infinity).toDouble()
                    : range * 0.12;
                final chartMinY = minY - padding;
                final chartMaxY = maxY + padding;
                final interval = ((chartMaxY - chartMinY).abs() / 4)
                    .clamp(1.0, double.infinity)
                    .toDouble();

                return LineChart(
                  LineChartData(
                    minY: chartMinY,
                    maxY: chartMaxY <= chartMinY ? chartMinY + 1 : chartMaxY,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: (spots.length / 4).clamp(1, double.infinity).toDouble(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= sampled.length) {
                              return const SizedBox.shrink();
                            }
                            final originalIndex = sampled[index].x;
                            if (originalIndex < 0 || originalIndex >= widget.points.length) {
                              return const SizedBox.shrink();
                            }
                            final date = widget.points[originalIndex].timestamp;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MM/dd', 'en_US').format(date),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              NumberFormat.compact(locale: 'fa_IR').format(value),
                              style: Theme.of(context).textTheme.labelSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 2.6,
                        color: const Color(0xFF0EA5E9),
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0EA5E9).withValues(alpha: 0.22),
                              const Color(0xFF0EA5E9).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<LttbOutputPoint>> _buildDownsampleFuture(List<AssetValuationPointDto> points) {
    final input = List<LttbInputPoint>.generate(
      points.length,
      (index) {
        final isLast = index == points.length - 1;
        final endpoint = widget.endpointMarketValue;
        return LttbInputPoint(
          x: index,
          y: isLast && endpoint != null ? endpoint : points[index].marketValue,
        );
      },
      growable: false,
    );
    return downsampleLttbInIsolate(points: input, threshold: 300);
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'داده‌ای برای نمودار در دسترس نیست.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
