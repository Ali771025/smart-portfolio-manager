import 'package:flutter/material.dart';

import '../../../../core/theme/custom_theme_extension.dart';
import '../../domain/models/analytics_models.dart';
import 'financial_numeric_text.dart';

class AnalyticsRiskScoreCard extends StatelessWidget {
  const AnalyticsRiskScoreCard({
    required this.metrics,
    super.key,
  });

  final AnalyticsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);
    final score = metrics.riskScore ?? _fallbackRiskScore(metrics);
    final level = _riskLevelFromMetrics(metrics, score);
    final tone = _riskTone(level, customTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shield_moon_outlined,
              size: 19,
              color: tone,
            ),
            const SizedBox(width: 8),
            Text(
              'امتیاز ریسک',
              style: customTheme.sectionTitleStyle,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tone.withValues(alpha: 0.18),
                tone.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: tone.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: tone,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scoreLabel(score),
                      style: customTheme.kpiValueStyle.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w800,
                        fontFeatures: kFinancialNumericFontFeatures,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _riskLabel(level),
                      style: customTheme.bodyStyle.copyWith(
                        color: customTheme.chartAxis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double? _fallbackRiskScore(AnalyticsMetrics metrics) {
  final volatility = metrics.volatility;
  if (!volatility.isFinite || volatility <= 0) {
    return null;
  }
  final volatilityPercent = volatility <= 1 ? volatility * 100 : volatility;
  return ((volatilityPercent / 40).clamp(0, 1) * 100).toDouble();
}

String _riskLevelFromMetrics(AnalyticsMetrics metrics, double? score) {
  final backendLevel = metrics.riskLevel;
  if (backendLevel != null && backendLevel.trim().isNotEmpty) {
    return backendLevel.toLowerCase();
  }
  if (score == null) {
    return 'medium';
  }
  if (score < 34) {
    return 'low';
  }
  if (score < 67) {
    return 'medium';
  }
  return 'high';
}

Color _riskTone(String level, CustomThemeExtension theme) {
  return switch (level) {
    'low' => theme.successSemantic,
    'high' => theme.dangerSemantic,
    _ => theme.warningSemantic,
  };
}

String _scoreLabel(double? score) {
  if (score == null) {
    return '3 / 5';
  }
  final normalized = (score / 20).clamp(1, 5).round();
  return '$normalized / 5';
}

String _riskLabel(String level) {
  return switch (level) {
    'low' => 'ریسک پایین',
    'high' => 'ریسک بالا',
    _ => 'ریسک متوسط',
  };
}
