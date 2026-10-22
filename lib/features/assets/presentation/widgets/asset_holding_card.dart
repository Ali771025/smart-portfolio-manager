import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';

class AssetHoldingCard extends StatelessWidget {
  const AssetHoldingCard({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PortfolioHoldingDto item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backendPnl = item.totalPnl;
    final pnlColor = backendPnl == null
        ? scheme.onSurfaceVariant
        : backendPnl >= Decimal.zero
            ? Colors.green
            : scheme.error;
    final pnlPrefix =
        backendPnl != null && backendPnl >= Decimal.zero ? '+' : '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.48)
              : scheme.surfaceContainer,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name?.trim().isNotEmpty == true
                        ? '${item.symbol} - ${item.name}'
                        : item.symbol,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(item.currency,
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                    label: 'تعداد',
                    value: formatAssetNumber(item.quantity.toString())),
                _MetricChip(
                    label: 'میانگین خرید',
                    value: formatAssetMoney(item.weightedAvgCost)),
                _MetricChip(
                  label: 'Last Price',
                  value: formatOptionalAssetMoney(item.displayPrice),
                  emphasized: true,
                ),
                _MetricChip(
                    label: 'ارزش',
                    value: formatOptionalAssetMoney(item.marketValue)),
                _MetricChip(
                    label: 'بهای تمام‌شده',
                    value: formatAssetMoney(item.costBasis)),
                _MetricChip(
                  label: 'سود/زیان',
                  value: backendPnl == null
                      ? 'ناموجود'
                      : '$pnlPrefix${formatAssetMoney(backendPnl)}',
                  valueColor: pnlColor,
                  emphasized: true,
                ),
                _MetricChip(
                  label: 'بازدهی',
                  value: formatOptionalAssetPercent(item.roi),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: emphasized ? FontWeight.w800 : null,
            ),
      ),
    );
  }
}
