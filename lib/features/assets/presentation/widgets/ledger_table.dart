import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';

import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';
import 'ledger_transaction_card.dart';

class LedgerTable extends StatelessWidget {
  const LedgerTable({
    required this.entries,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    super.key,
  });

  final List<LedgerEntryDto> entries;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 980;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  'دفتر تراکنش‌ها',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (hasMore)
                  TextButton.icon(
                    onPressed: isLoadingMore ? null : onLoadMore,
                    icon: isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: const Text('بیشتر'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'هنوز تراکنشی برای این دارایی ثبت نشده است.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else if (desktop)
            _DesktopLedgerTable(entries: entries)
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LedgerTransactionCard(entry: entry),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopLedgerTable extends StatelessWidget {
  const _DesktopLedgerTable({required this.entries});

  final List<LedgerEntryDto> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 42,
        dataRowMinHeight: 46,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('تاریخ')),
          DataColumn(label: Text('نوع')),
          DataColumn(label: Text('دارایی')),
          DataColumn(label: Text('تعداد')),
          DataColumn(label: Text('قیمت')),
          DataColumn(label: Text('کمیسیون')),
          DataColumn(label: Text('کارمزد')),
          DataColumn(label: Text('مالیات')),
          DataColumn(label: Text('خالص مبلغ')),
          DataColumn(label: Text('جریان نقدی')),
          DataColumn(label: Text('ارزش')),
          DataColumn(label: Text('یادداشت')),
        ],
        rows: entries
            .map(
              (entry) => DataRow(
                cells: [
                  DataCell(Text(DateFormat('yyyy/MM/dd', 'en_US').format(entry.executedAt))),
                  DataCell(
                    Text(
                      formatTransactionTypeLabel(entry.transactionType),
                      style: textTheme.labelLarge,
                    ),
                  ),
                  DataCell(Text(entry.assetSymbol)),
                  DataCell(Text(formatAssetNumber(entry.quantity.toString()))),
                  DataCell(Text(formatAssetMoney(entry.pricePerUnit))),
                  DataCell(Text(formatAssetMoney(entry.commission))),
                  DataCell(Text(formatAssetMoney(entry.fees))),
                  DataCell(Text(formatAssetMoney(entry.tax))),
                  DataCell(Text(formatAssetMoney(entry.netAmount))),
                  DataCell(Text(_cashFlowText(entry.cashFlow))),
                  DataCell(Text(formatAssetMoney(entry.totalAmount))),
                  DataCell(Text(entry.notes?.trim().isNotEmpty == true ? entry.notes! : '-')),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _cashFlowText(Decimal value) {
    final sign = value >= Decimal.zero ? '+' : '';
    return '$sign${formatAssetMoney(value)}';
  }
}
