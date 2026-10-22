import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/widgets/animated_theme_toggle_button.dart';
import 'glow_action_button.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.onRefresh,
    required this.isRefreshing,
    super.key,
  });

  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'داشبورد پرتفوی',
                style: AppTypography.screenTitle(Theme.of(context).textTheme),
              ),
              const SizedBox(height: 6),
              Text(
                'نمای زنده‌ی عملکرد واردشده از داده‌های واقعی شما',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const AnimatedThemeToggleButton(),
        const SizedBox(width: 8),
        GlowActionButton(
          onPressed: onRefresh,
          child: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}
