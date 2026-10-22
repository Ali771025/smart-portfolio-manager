import 'package:flutter/material.dart';

import '../../../../core/theme/custom_theme_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsRiskStatsGrid extends StatelessWidget {
  const AnalyticsRiskStatsGrid({
    required this.risk,
    super.key,
  });

  final AdvancedRiskMetricsResponse risk;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final tiles = <_RiskStatTileSpec>[
      _RiskStatTileSpec(
        title: 'نسبت سورتینو',
        value: _formatFixed(risk.sortinoRatio, digits: 2),
        semanticColor:
            _sortinoColor(context: context, sortino: risk.sortinoRatio),
        helpTitle: 'نسبت سورتینو',
        helpBody: 'نسبت سورتینو بازده را فقط در برابر نوسان نزولی می‌سنجد. '
            'عدد بزرگ‌تر معمولا نشان‌دهنده عملکرد بهتر نسبت به ریسک است.',
      ),
      _RiskStatTileSpec(
        title: 'آلفا (جنسن)',
        value: _formatPercent(risk.alpha, signed: true),
        semanticColor: _alphaColor(context: context, alpha: risk.alpha),
        helpTitle: 'آلفا',
        helpBody: 'آلفا بازده مازاد نسبت به شاخص مبنا را پس از تعدیل بتا نشان می‌دهد. '
            'آلفای مثبت یعنی عملکرد بهتر از شاخص.',
      ),
      _RiskStatTileSpec(
        title: 'بتا',
        value: _formatFixed(risk.beta, digits: 3),
        semanticColor: _betaColor(context: context, beta: risk.beta),
        helpTitle: 'بتا',
        helpBody: 'بتا حساسیت پرتفوی به شاخص مبنا را اندازه می‌گیرد. '
            'بتای ۱ هم‌جهت بازار است و مقادیر بالاتر از ۱ نوسان بیشتری دارند.',
      ),
      _RiskStatTileSpec(
        title: 'حداکثر افت سرمایه',
        value: _formatPercent(risk.maximumDrawdown),
        semanticColor: _drawdownColor(
          context: context,
          drawdown: risk.maximumDrawdown,
        ),
        helpTitle: 'حداکثر افت سرمایه (MDD)',
        helpBody: 'MDD بیشترین افت از سقف تا کف را نشان می‌دهد. '
            'افت کمتر یعنی محافظت بهتر در روندهای نزولی.',
      ),
      _RiskStatTileSpec(
        title: 'ارزش در معرض ریسک',
        value: _formatPercent(_varRepresentative(risk)),
        semanticColor: _varColor(context: context, risk: risk),
        helpTitle: 'ارزش در معرض ریسک (VaR)',
        helpBody: 'VaR زیان احتمالی یک‌روزه را در سطوح اطمینان مختلف برآورد می‌کند. '
            'VaR بالاتر یعنی مواجهه بیشتر با ریسک‌های دنباله‌ای.',
        details: [
          'تاریخی 95/99: ${_formatPercent(risk.valueAtRisk.historical.confidence95)} / ${_formatPercent(risk.valueAtRisk.historical.confidence99)}',
          'پارامتریک 95/99: ${_formatPercent(risk.valueAtRisk.parametric.confidence95)} / ${_formatPercent(risk.valueAtRisk.parametric.confidence99)}',
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 18,
              color: customTheme.primarySemantic,
            ),
            const SizedBox(width: 8),
            Text(
              'شاخص‌های ریسک',
              style: customTheme.sectionTitleStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompactMobile = width < 520;
            final columns = switch (constraints.maxWidth) {
              >= 1200 => 5,
              >= 980 => 3,
              >= 520 => 2,
              >= 390 => 2,
              _ => 1,
            };
            final totalSpacing = (columns - 1) * 12;
            final cardWidth = (constraints.maxWidth - totalSpacing) / columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tiles
                  .map(
                    (tile) => SizedBox(
                      width: cardWidth,
                      child: _RiskStatCard(
                        tile: tile,
                        compact: isCompactMobile,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _RiskStatTileSpec {
  const _RiskStatTileSpec({
    required this.title,
    required this.value,
    required this.semanticColor,
    required this.helpTitle,
    required this.helpBody,
    this.details = const <String>[],
  });

  final String title;
  final String value;
  final Color semanticColor;
  final String helpTitle;
  final String helpBody;
  final List<String> details;
}

class _RiskStatCard extends StatelessWidget {
  const _RiskStatCard({
    required this.tile,
    this.compact = false,
  });

  final _RiskStatTileSpec tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tile.semanticColor.withValues(alpha: 0.08),
        border: Border.all(color: tile.semanticColor.withValues(alpha: 0.44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tile.title,
                  style: customTheme.kpiLabelStyle.copyWith(
                    color: customTheme.chartAxis,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkResponse(
                radius: 16,
                onTap: () => _showMetricHelp(
                  context: context,
                  title: tile.helpTitle,
                  body: tile.helpBody,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: customTheme.chartAxis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            tile.value,
            style: customTheme.kpiValueStyle.copyWith(
              color: tile.semanticColor,
              fontWeight: FontWeight.w700,
              fontFeatures: kFinancialNumericFontFeatures,
            ),
          ),
          if (tile.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...tile.details.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: customTheme.captionStyle.copyWith(
                    color: customTheme.chartAxis,
                    fontFeatures: kFinancialNumericFontFeatures,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showMetricHelp({
  required BuildContext context,
  required String title,
  required String body,
}) {
  final customTheme = CustomThemeExtension.resolve(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: customTheme.cardBackground,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: customTheme.bodyStyle,
            ),
          ],
        ),
      );
    },
  );
}

double? _varRepresentative(AdvancedRiskMetricsResponse risk) {
  final values = <double?>[
    risk.valueAtRisk.historical.confidence99,
    risk.valueAtRisk.parametric.confidence99,
    risk.valueAtRisk.historical.confidence95,
    risk.valueAtRisk.parametric.confidence95,
  ].whereType<double>();
  if (values.isEmpty) {
    return null;
  }
  return values.reduce((a, b) => a > b ? a : b);
}

String _formatFixed(double? value, {int digits = 2}) {
  if (value == null) {
    return '—';
  }
  return value.toStringAsFixed(digits);
}

String _formatPercent(double? value, {bool signed = false, int digits = 2}) {
  if (value == null) {
    return '—';
  }
  final scaled = value * 100;
  final sign = signed && scaled > 0 ? '+' : '';
  return '$sign${scaled.toStringAsFixed(digits)}%';
}

Color _sortinoColor({
  required BuildContext context,
  required double? sortino,
}) {
  final theme = CustomThemeExtension.resolve(context);
  if (sortino == null) {
    return theme.chartAxis;
  }
  if (sortino >= 2) {
    return theme.successSemantic;
  }
  if (sortino >= 1) {
    return theme.warningSemantic;
  }
  return theme.dangerSemantic;
}

Color _alphaColor({
  required BuildContext context,
  required double? alpha,
}) {
  final theme = CustomThemeExtension.resolve(context);
  if (alpha == null) {
    return theme.chartAxis;
  }
  if (alpha > 0) {
    return theme.successSemantic;
  }
  if (alpha < 0) {
    return theme.dangerSemantic;
  }
  return theme.chartAxis;
}

Color _betaColor({
  required BuildContext context,
  required double? beta,
}) {
  final theme = CustomThemeExtension.resolve(context);
  if (beta == null) {
    return theme.chartAxis;
  }
  final distance = (beta - 1).abs();
  if (distance <= 0.2) {
    return theme.primarySemantic;
  }
  if (distance <= 0.5) {
    return theme.warningSemantic;
  }
  return theme.dangerSemantic;
}

Color _drawdownColor({
  required BuildContext context,
  required double? drawdown,
}) {
  final theme = CustomThemeExtension.resolve(context);
  if (drawdown == null) {
    return theme.chartAxis;
  }
  if (drawdown <= 0.1) {
    return theme.successSemantic;
  }
  if (drawdown <= 0.2) {
    return theme.warningSemantic;
  }
  return theme.dangerSemantic;
}

Color _varColor({
  required BuildContext context,
  required AdvancedRiskMetricsResponse risk,
}) {
  final theme = CustomThemeExtension.resolve(context);
  final value = _varRepresentative(risk);
  if (value == null) {
    return theme.chartAxis;
  }
  if (value <= 0.02) {
    return theme.successSemantic;
  }
  if (value <= 0.04) {
    return theme.warningSemantic;
  }
  return theme.dangerSemantic;
}
