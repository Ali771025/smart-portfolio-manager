import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';

import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';

class LedgerTransactionCard extends StatelessWidget {
  const LedgerTransactionCard({
    required this.entry,
    super.key,
  });

  final LedgerEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatTransactionTypeLabel(entry.transactionType),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 6),
              Text(entry.assetSymbol, style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(DateFormat('yyyy/MM/dd', 'en_US').format(entry.executedAt)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'تعداد',
                value: formatAssetNumber(entry.quantity.toString()),
              ),
              _MetricChip(label: 'قیمت', value: formatAssetMoney(entry.pricePerUnit)),
              _MetricChip(label: 'کمیسیون', value: formatAssetMoney(entry.commission)),
              _MetricChip(label: 'کارمزد', value: formatAssetMoney(entry.fees)),
              _MetricChip(label: 'مالیات', value: formatAssetMoney(entry.tax)),
              _MetricChip(label: 'خالص', value: formatAssetMoney(entry.netAmount)),
              _MetricChip(label: 'جریان نقدی', value: _cashFlowText(entry.cashFlow)),
              _MetricChip(label: 'ارزش', value: formatAssetMoney(entry.totalAmount)),
              _MetricChip(
                label: 'یادداشت',
                value: entry.notes?.trim().isNotEmpty == true ? entry.notes! : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _cashFlowText(Decimal value) {
  final sign = value >= Decimal.zero ? '+' : '';
  return '$sign${formatAssetMoney(value)}';
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
