import 'package:flutter/material.dart';

class ChartPlaceholderWidget extends StatelessWidget {
  const ChartPlaceholderWidget({
    super.key,
    required this.title,
    this.pointCount = 0,
    this.completeness = 'complete',
    this.seriesCount = 0,
  });

  final String title;
  final int pointCount;
  final String completeness;
  final int seriesCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completenessColor = switch (completeness) {
      'complete' => Colors.green,
      'partial' => Colors.orange,
      _ => scheme.error,
    };
    final completenessLabel = switch (completeness) {
      'complete' => 'داده کامل',
      'partial' => 'داده ناقص',
      _ => 'داده ناکافی',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: scheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pointCount > 0)
              Text('$pointCount نقطه داده', style: Theme.of(context).textTheme.bodyMedium),
            if (seriesCount > 0)
              Text('$seriesCount سری داده', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: completenessColor.withAlpha(20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: completenessColor.withAlpha(60)),
              ),
              child: Text(completenessLabel, style: TextStyle(color: completenessColor, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Text(
              'نمودار واقعی پس از اتصال کتابخانه Chart در فرانت‌اند نمایش داده می‌شود.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
