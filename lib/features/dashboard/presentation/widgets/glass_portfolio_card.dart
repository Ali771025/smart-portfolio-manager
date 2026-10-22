import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../domain/models/dashboard_state.dart';
import 'dashboard_glass_card.dart';

class GlassPortfolioCard extends StatelessWidget {
  const GlassPortfolioCard({
    required this.metrics,
    required this.totalAssets,
    required this.currency,
    super.key,
  });

  final DashboardMetrics metrics;
  final int totalAssets;
  final String currency;

  static final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'fa_IR');
  static final NumberFormat _percentFormatter = NumberFormat('#,##0.00', 'fa_IR');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fintech = context.fintechColors;
    final pnlColor =
        metrics.totalProfitLoss >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;

    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'ارزش کل دارایی‌ها',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: metrics.totalCurrentValue),
            duration: const Duration(milliseconds: 980),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LtrLogText(
                '${_currencyFormatter.format(value)} $currency',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pnlColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pnlColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      metrics.totalProfitLoss >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 15,
                      color: pnlColor,
                    ),
                    const SizedBox(width: 6),
                    LtrLogText(
                      '${_percentFormatter.format(metrics.overallRoiPercent)}٪',
                      style: TextStyle(
                        color: pnlColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تعداد نماد: $totalAssets',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
