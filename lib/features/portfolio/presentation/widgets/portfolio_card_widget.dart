import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/portfolio_providers.dart';

class PortfolioCardWidget extends StatelessWidget {
  const PortfolioCardWidget({
    required this.item,
    this.onTap,
    super.key,
  });

  final PortfolioListItem item;
  final VoidCallback? onTap;

  static final NumberFormat _moneyFormatter = NumberFormat.currency(
    locale: 'fa_IR',
    symbol: 'ریال ',
    decimalDigits: 0,
  );
  static final NumberFormat _percentFormatter = NumberFormat('#,##0.00', 'fa_IR');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final fintech = context.fintechColors;
    final positive = item.isPositive;
    final tone = positive ? fintech.pnlSuccess : fintech.pnlDanger;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: positive
                ? scheme.outlineVariant
                : scheme.error.withValues(alpha: 0.32),
          ),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: positive
                ? <Color>[
                    tone.withValues(alpha: 0.10),
                    semantic.card,
                  ]
                : <Color>[
                    scheme.errorContainer.withValues(alpha: 0.45),
                    semantic.card,
                  ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 12),
              color: scheme.shadow.withValues(alpha: 0.1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sectionTitle(Theme.of(context).textTheme),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MetricBadge(
                    label: 'بازدهی',
                    value: '${_percentFormatter.format(item.roiPercent)}٪',
                    positive: positive,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ارزش بازار',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _moneyFormatter.format(item.totalCurrentValue),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 10),
              _PnlBadge(
                pnlValue: item.totalUnrealizedPnl,
                positive: item.totalUnrealizedPnl >= 0,
              ),
              if (item.dailyPnl != 0) ...[
                const SizedBox(height: 8),
                _DailyPnlStrip(value: item.dailyPnl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyPnlStrip extends StatelessWidget {
  const _DailyPnlStrip({required this.value});

  final double value;

  static final NumberFormat _moneyFormatter = NumberFormat.currency(
    locale: 'fa_IR',
    symbol: 'ریال ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final tone =
        positive ? context.fintechColors.pnlSuccess : context.fintechColors.pnlDanger;
    final prefix = positive ? '+' : '-';

    return Row(
      children: [
        Icon(
          Icons.bolt_rounded,
          color: tone,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          'تغییر امروز: $prefix${_moneyFormatter.format(value.abs())}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.positive,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final tone =
        positive ? context.fintechColors.pnlSuccess : context.fintechColors.pnlDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
        color: tone.withValues(alpha: 0.11),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PnlBadge extends StatelessWidget {
  const _PnlBadge({
    required this.pnlValue,
    required this.positive,
  });

  final double pnlValue;
  final bool positive;

  static final NumberFormat _moneyFormatter = NumberFormat.currency(
    locale: 'fa_IR',
    symbol: 'ریال ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final tone =
        positive ? context.fintechColors.pnlSuccess : context.fintechColors.pnlDanger;
    final prefix = positive ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            tone.withValues(alpha: 0.22),
            tone.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 8),
          Text(
            'سود/زیان باز: $prefix${_moneyFormatter.format(pnlValue.abs())}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
