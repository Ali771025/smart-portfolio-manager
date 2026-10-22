import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsAllocationDonutChart extends StatefulWidget {
  const AnalyticsAllocationDonutChart({
    required this.slices,
    this.portfolioId,
    this.timeframe,
    super.key,
  });

  final List<AnalyticsAllocationSlice> slices;
  final String? portfolioId;
  final AnalyticsTimeframe? timeframe;

  @override
  State<AnalyticsAllocationDonutChart> createState() =>
      _AnalyticsAllocationDonutChartState();
}

class _AnalyticsAllocationDonutChartState
    extends State<AnalyticsAllocationDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final scheme = Theme.of(context).colorScheme;
    final slices = widget.slices
        .where(
          (slice) =>
              slice.value.isFinite &&
              slice.value > 0 &&
              slice.percentage.isFinite &&
              slice.ticker.trim().isNotEmpty,
        )
        .toList(growable: false);
    final normalizedPortfolioId = (widget.portfolioId ?? '').trim();
    if (kDebugMode && normalizedPortfolioId.isNotEmpty) {
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          slices.length,
          for (final slice in slices) slice.ticker,
          for (final slice in slices) slice.percentage,
          for (final slice in slices) slice.value,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'AnalyticsAllocationDonutChart',
        portfolioId: normalizedPortfolioId,
        timeframe: widget.timeframe?.name,
        pointCount: slices.length,
        dataFingerprint: fingerprint,
      );
    }

    if (slices.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text('داده‌ای برای تخصیص دارایی موجود نیست.'),
        ),
      );
    }

    final palette = <Color>[
      customTheme.primarySemantic,
      customTheme.benchmarkSemantic,
      customTheme.successSemantic,
      customTheme.warningSemantic,
      customTheme.dangerSemantic,
      customTheme.chartAxis,
      customTheme.primarySemantic.withValues(alpha: 0.72),
    ];

    final activeIndex = _touchedIndex < 0
        ? 0
        : _touchedIndex.clamp(0, slices.length - 1);
    final activeSlice = slices[activeIndex];
    final number = NumberFormat.compactCurrency(symbol: '', decimalDigits: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;
        final chartSize = isMobile
            ? math.min(constraints.maxWidth - 24, 200.0)
            : 220.0;

        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: RepaintBoundary(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: isMobile ? 46 : 52,
                sectionsSpace: 2,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      if (mounted) {
                        setState(() => _touchedIndex = -1);
                      }
                      return;
                    }
                    if (mounted) {
                      setState(
                        () => _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex,
                      );
                    }
                  },
                ),
                sections: slices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final slice = entry.value;
                  final isTouched = index == _touchedIndex;
                  final radius = isTouched
                      ? (isMobile ? 72.0 : 82.0)
                      : (isMobile ? 64.0 : 72.0);
                  final color = palette[index % palette.length];

                  return PieChartSectionData(
                    value: math.max(slice.percentage, 0.01),
                    color: color,
                    radius: radius,
                    title: '${slice.percentage.toStringAsFixed(1)}%',
                    titleStyle: customTheme.captionStyle.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kFinancialNumericFontFeatures,
                    ),
                  );
                }).toList(growable: false),
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeSlice.ticker,
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 6),
            Text(
              '${activeSlice.percentage.toStringAsFixed(2)}%',
              style: customTheme.bodyStyle.copyWith(
                color: customTheme.chartAxis,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              number.format(activeSlice.value),
              style: customTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: kFinancialNumericFontFeatures,
              ),
            ),
            const SizedBox(height: 14),
            ...slices.asMap().entries.map((entry) {
              final index = entry.key;
              final slice = entry.value;
              final selected = index == _touchedIndex;
              final color = palette[index % palette.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selected
                        ? color.withValues(alpha: 0.16)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slice.ticker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: customTheme.bodyStyle.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${slice.percentage.toStringAsFixed(1)}%',
                        style: customTheme.captionStyle.copyWith(
                          color: customTheme.chartAxis,
                          fontFeatures: kFinancialNumericFontFeatures,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );

        if (isMobile) {
          return Column(
            children: [
              Align(alignment: Alignment.center, child: chart),
              const SizedBox(height: 12),
              details,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 5,
              child: Center(child: chart),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: details,
            ),
          ],
        );
      },
    );
  }
}
