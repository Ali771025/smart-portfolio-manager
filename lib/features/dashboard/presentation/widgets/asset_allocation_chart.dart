import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../domain/models/dashboard_state.dart';
import 'dashboard_glass_card.dart';

class AssetAllocationChart extends StatefulWidget {
  const AssetAllocationChart({
    required this.allocations,
    required this.currency,
    this.portfolioId,
    super.key,
  });

  final List<AssetAllocation> allocations;
  final String currency;
  final String? portfolioId;

  @override
  State<AssetAllocationChart> createState() => _AssetAllocationChartState();
}

class _AssetAllocationChartState extends State<AssetAllocationChart> {
  int _touchedIndex = -1;

  static const _palette = <Color>[
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];

  static final NumberFormat _percentFormatter = NumberFormat('#,##0.00', 'fa_IR');
  static final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'fa_IR');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = widget.allocations
        .where(
          (item) =>
              item.value.isFinite &&
              item.value > 0 &&
              item.percentage.isFinite &&
              item.ticker.trim().isNotEmpty,
        )
        .toList(growable: false);
    final normalizedPortfolioId = (widget.portfolioId ?? '').trim();
    if (kDebugMode && normalizedPortfolioId.isNotEmpty) {
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          list.length,
          for (final item in list) item.ticker,
          for (final item in list) item.value,
          for (final item in list) item.percentage,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'AssetAllocationChart.dashboard',
        portfolioId: normalizedPortfolioId,
        pointCount: list.length,
        dataFingerprint: fingerprint,
      );
    }
    if (list.isEmpty) {
      return const DashboardEmptyState(
        title: 'داده تخصیص دارایی موجود نیست',
        subtitle: 'پس از ورود داده واقعی پرتفوی، ترکیب دارایی اینجا نمایش داده می‌شود.',
      );
    }

    final activeIndex = (_touchedIndex >= 0 && _touchedIndex < list.length) ? _touchedIndex : 0;
    final active = list[activeIndex];

    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ترکیب دارایی‌ها',
            style: AppTypography.sectionTitle(Theme.of(context).textTheme),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 620;
              final chartSize = isMobile
                  ? math.min(constraints.maxWidth - 28, 210.0)
                  : 220.0;
              final chartWidget = SizedBox(
                width: chartSize,
                height: chartSize,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: isMobile ? 50 : 58,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        final touched = response?.touchedSection;
                        if (!event.isInterestedForInteractions || touched == null) {
                          setState(() => _touchedIndex = -1);
                          return;
                        }
                        setState(() => _touchedIndex = touched.touchedSectionIndex);
                      },
                    ),
                    sections: list.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final touched = _touchedIndex == index;
                      final color =
                          _tryParseHexColor(item.colorHint) ?? _palette[index % _palette.length];
                      return PieChartSectionData(
                        color: color,
                        value: math.max(item.percentage, 0.01),
                        radius: touched ? (isMobile ? 72 : 80) : (isMobile ? 64 : 72),
                        title: '${_percentFormatter.format(item.percentage)}٪',
                        titleStyle: TextStyle(
                          fontSize: touched ? 12 : 10,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimary,
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                ),
              );

              final legend = _LegendList(
                items: list,
                touchedIndex: _touchedIndex,
                palette: _palette,
                percentFormatter: _percentFormatter,
              );

              if (isMobile) {
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: chartWidget,
                    ),
                    const SizedBox(height: 12),
                    legend,
                  ],
                );
              }

              return SizedBox(
                height: 250,
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Center(child: chartWidget),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: legend,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سهم ${active.ticker}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                LtrLogText(
                  '${_currencyFormatter.format(active.value)} ${widget.currency}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color? _tryParseHexColor(String source) {
  final sanitized = source.trim();
  if (!RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(sanitized)) {
    return null;
  }
  final withHash = sanitized.startsWith('#') ? sanitized : '#$sanitized';
  final value = int.tryParse(withHash.replaceFirst('#', '0xFF'));
  if (value == null) {
    return null;
  }
  return Color(value);
}

class _LegendList extends StatelessWidget {
  const _LegendList({
    required this.items,
    required this.touchedIndex,
    required this.palette,
    required this.percentFormatter,
  });

  final List<AssetAllocation> items;
  final int touchedIndex;
  final List<Color> palette;
  final NumberFormat percentFormatter;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = index == touchedIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _tryParseHexColor(item.colorHint) ?? palette[index % palette.length],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LtrLogText(
                  item.ticker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              LtrLogText(
                '${percentFormatter.format(item.percentage)}٪',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemCount: math.min(items.length, 6),
    );
  }
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DashboardGlassCard(
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 34,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
