import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../../../core/theme/financial_palette_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsKpiHeader extends StatelessWidget {
  const AnalyticsKpiHeader({
    super.key,
    required this.metrics,
    required this.totalNav,
    this.portfolioId,
    this.timeframe,
  });

  final AnalyticsMetrics metrics;
  final double totalNav;
  final String? portfolioId;
  final AnalyticsTimeframe? timeframe;

  @override
  Widget build(BuildContext context) {
    final normalizedPortfolioId = (portfolioId ?? '').trim();
    if (normalizedPortfolioId.isNotEmpty) {
      final fingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          totalNav,
          metrics.pnl,
          metrics.roiPercent,
          metrics.volatility,
          metrics.sharpeRatio,
          metrics.asOfDate.toUtc().millisecondsSinceEpoch,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId:
            ImportAnalyticsRefreshTrace.traceIdForPortfolio(normalizedPortfolioId),
        widgetName: 'AnalyticsKpiHeader',
        portfolioId: normalizedPortfolioId,
        timeframe: timeframe?.name,
        pointCount: 5,
        firstDate: metrics.asOfDate,
        lastDate: metrics.asOfDate,
        dataFingerprint: fingerprint,
      );
    }
    final compact = NumberFormat.compactCurrency(symbol: '', decimalDigits: 2);

    final cards = <_KpiCardSpec>[
      _KpiCardSpec(
        title: 'ارزش خالص دارایی',
        value: totalNav,
        formatter: compact.format,
        tone: _KpiTone.primary,
      ),
      _KpiCardSpec(
        title: 'سود و زیان کل',
        value: metrics.pnl,
        formatter: compact.format,
        tone: _profitLossTone(metrics.pnl),
      ),
      _KpiCardSpec(
        title: 'بازدهی',
        value: metrics.roiPercent,
        formatter: (value) => '${value.toStringAsFixed(2)}%',
        tone: _profitLossTone(metrics.roiPercent),
      ),
      _KpiCardSpec(
        title: 'نوسان',
        value: metrics.volatility,
        formatter: (value) => '${_volatilityPercent(value).toStringAsFixed(2)}%',
        tone: _KpiTone.neutral,
      ),
      _KpiCardSpec(
        title: 'نسبت شارپ',
        value: metrics.sharpeRatio,
        formatter: (value) => value.toStringAsFixed(2),
        tone: _KpiTone.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 5
            : width >= 900
                ? 3
                : width >= 560
                    ? 3
                    : 2;

        final availableWidth = width - ((columns - 1) * 12);
        final cardWidth = availableWidth / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _AnimatedKpiCard(spec: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

double _volatilityPercent(double rawVolatility) {
  if (!rawVolatility.isFinite) {
    return 0;
  }
  return rawVolatility <= 1 ? rawVolatility * 100 : rawVolatility;
}

enum _KpiTone { profit, loss, neutral, primary }

class _KpiCardSpec {
  const _KpiCardSpec({
    required this.title,
    required this.value,
    required this.formatter,
    required this.tone,
  });

  final String title;
  final double? value;
  final String Function(double value) formatter;
  final _KpiTone tone;
}

class _AnimatedKpiCard extends StatelessWidget {
  const _AnimatedKpiCard({required this.spec});

  final _KpiCardSpec spec;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final financialPalette = context.financialPalette;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color valueColor;
    final Color glowColor;

    switch (spec.tone) {
      case _KpiTone.profit:
        valueColor = financialPalette.profitColor;
        glowColor = financialPalette.liveTickUpGlow;
        break;
      case _KpiTone.loss:
        valueColor = financialPalette.lossColor;
        glowColor = financialPalette.liveTickDownGlow;
        break;
      case _KpiTone.neutral:
        valueColor = financialPalette.neutralDrawdown;
        glowColor = financialPalette.neutralDrawdown.withValues(alpha: 0.20);
        break;
      case _KpiTone.primary:
        valueColor = financialPalette.portfolioLine;
        glowColor = financialPalette.portfolioLine.withValues(alpha: 0.20);
        break;
    }

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? customTheme.segmentedBackground.withValues(alpha: 0.52)
              : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? customTheme.cardStroke.withValues(alpha: 0.7)
                : scheme.outlineVariant,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isDark ? glowColor : scheme.shadow.withValues(alpha: 0.08),
              blurRadius: isDark ? 18 : 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spec.title,
              style: customTheme.kpiLabelStyle.copyWith(color: customTheme.chartAxis),
            ),
            const SizedBox(height: 8),
            if (spec.value != null)
              AnimatedFinancialNumericText(
                value: spec.value!,
                formatter: spec.formatter,
                style: customTheme.kpiValueStyle,
                color: valueColor,
              )
            else
              Text(
                '—',
                style: customTheme.kpiValueStyle.copyWith(
                  color: customTheme.chartAxis,
                  fontWeight: FontWeight.w700,
                  fontFeatures: kFinancialNumericFontFeatures,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

_KpiTone _profitLossTone(double? value) {
  if (value == null) {
    return _KpiTone.neutral;
  }
  return value >= 0 ? _KpiTone.profit : _KpiTone.loss;
}
