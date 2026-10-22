import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/custom_theme_extension.dart';

class AnalyticsKpiHeaderSkeleton extends StatelessWidget {
  const AnalyticsKpiHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List<Widget>.generate(
          5,
          (_) => const SizedBox(
            width: 220,
            child: _KpiTileSkeleton(),
          ),
        ),
      ),
    );
  }
}

class AnalyticsChartSkeleton extends StatelessWidget {
  const AnalyticsChartSkeleton({
    super.key,
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);

    return Skeletonizer(
      enabled: true,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: customTheme.segmentedBackground.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 130,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: customTheme.segmentedPill.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: customTheme.segmentedPill.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTileSkeleton extends StatelessWidget {
  const _KpiTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomThemeExtension.resolve(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: customTheme.segmentedBackground.withValues(alpha: 0.42),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('برچسب شاخص'),
          SizedBox(height: 8),
          Text('123,456.78'),
        ],
      ),
    );
  }
}
