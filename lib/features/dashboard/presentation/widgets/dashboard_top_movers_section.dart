import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../domain/models/dashboard_state.dart';
import 'asset_allocation_chart.dart';
import 'dashboard_glass_card.dart';

class DashboardTopMoversSection extends StatelessWidget {
  const DashboardTopMoversSection({
    required this.movers,
    required this.currency,
    super.key,
  });

  final List<TopMoverItem> movers;
  final String currency;

  static final NumberFormat _money = NumberFormat('#,##0.00', 'fa_IR');
  static final NumberFormat _percent = NumberFormat('#,##0.00', 'fa_IR');

  @override
  Widget build(BuildContext context) {
    if (movers.isEmpty) {
      return const DashboardEmptyState(
        title: 'داده‌ای برای بیشترین تغییرات نیست',
        subtitle: 'پس از ورود داده‌های واقعی سود/زیان، این بخش فعال می‌شود.',
      );
    }

    final fintech = context.fintechColors;
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بیشترین تغییرات',
            style: AppTypography.sectionTitle(Theme.of(context).textTheme),
          ),
          const SizedBox(height: 10),
          ...movers.take(5).map((item) {
            final color =
                item.profitLoss >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LtrLogText(
                            item.symbol,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LtrLogText(
                          '${_money.format(item.profitLoss)} $currency',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LtrLogText(
                          '${_percent.format(item.profitLossPercent)}٪',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
