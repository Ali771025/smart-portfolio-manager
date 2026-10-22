import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DashboardGlassCard extends StatelessWidget {
  const DashboardGlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? <Color>[
                      semantic.card.withValues(alpha: 0.92),
                      semantic.surface.withValues(alpha: 0.86),
                    ]
                  : [
                      semantic.card,
                      semantic.elevatedSurface.withValues(alpha: 0.9),
                    ],
            ),
            border: Border.all(
              color: scheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
