import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/ltr_log_text.dart';
import 'dashboard_glass_card.dart';

class PortfolioKpiTile extends StatelessWidget {
  const PortfolioKpiTile({
    required this.title,
    required this.value,
    required this.valueColor,
    super.key,
    this.trailingIcon,
    this.isPercent = false,
    this.currency = 'IRR',
  });

  final String title;
  final double value;
  final Color valueColor;
  final IconData? trailingIcon;
  final bool isPercent;
  final String currency;

  static final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'fa_IR');
  static final NumberFormat _percentFormatter = NumberFormat('#,##0.00', 'fa_IR');

  String _formatValue(double source) {
    if (isPercent) {
      return '${_percentFormatter.format(source)}٪';
    }
    return '${_currencyFormatter.format(source)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DashboardGlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (trailingIcon != null)
                Icon(
                  trailingIcon,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return LtrLogText(
                _formatValue(animatedValue),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w800,
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
