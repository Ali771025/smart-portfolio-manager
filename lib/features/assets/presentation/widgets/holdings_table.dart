import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';

class HoldingsTable extends StatelessWidget {
  const HoldingsTable({
    required this.items,
    required this.selectedTicker,
    required this.onSelectTicker,
    super.key,
  });

  final List<PortfolioHoldingDto> items;
  final String? selectedTicker;
  final ValueChanged<String> onSelectTicker;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('دارایی')),
          DataColumn(label: Text('نوع')),
          DataColumn(label: Text('تعداد')),
          DataColumn(label: Text('میانگین خرید')),
          DataColumn(label: Text('قیمت آخر')),
          DataColumn(label: Text('ارزش بازار')),
          DataColumn(label: Text('بهای تمام‌شده')),
          DataColumn(label: Text('سود/زیان تحقق‌نیافته')),
          DataColumn(label: Text('سود/زیان تحقق‌یافته')),
          DataColumn(label: Text('سود/زیان کل')),
          DataColumn(label: Text('بازدهی')),
          DataColumn(label: Text('به‌روزرسانی')),
        ],
        rows: items.map(
          (item) {
            final scheme = Theme.of(context).colorScheme;
            final totalPnl = item.totalPnl;
            return DataRow(
              selected: selectedTicker == item.symbol,
              onSelectChanged: (_) => onSelectTicker(item.symbol),
              cells: [
                DataCell(
                  Text(
                    item.name?.trim().isNotEmpty == true
                        ? '${item.symbol} - ${item.name}'
                        : item.symbol,
                  ),
                ),
                const DataCell(Text('-')),
                DataCell(Text(formatAssetNumber(item.quantity.toString()))),
                DataCell(Text(formatAssetMoney(item.weightedAvgCost))),
                DataCell(
                  Tooltip(
                    message: _priceTooltip(item),
                    child: Text(
                      _priceText(item),
                      style: TextStyle(
                        color: item.displayPrice == null
                            ? scheme.onSurfaceVariant
                            : null,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    formatOptionalAssetMoney(
                      item.marketValue,
                      fallback: 'نامشخص',
                    ),
                    style: TextStyle(
                      color: item.marketValue == null
                          ? scheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
                DataCell(Text(formatAssetMoney(item.costBasis))),
                DataCell(
                  Text(
                    _moneyPnlText(item.unrealizedPnl, missingText: 'نامشخص'),
                    style: TextStyle(
                      color: _pnlColor(context, item.unrealizedPnl),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _moneyPnlText(item.realizedPnl),
                    style: TextStyle(
                      color: _pnlColor(context, item.realizedPnl),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _moneyPnlText(totalPnl, missingText: 'نامشخص'),
                    style: TextStyle(
                      color: _pnlColor(context, totalPnl),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    formatOptionalAssetPercent(
                      item.roi ?? item.totalPnlPercent,
                      fallback: '-',
                    ),
                  ),
                ),
                DataCell(Text(_updatedAt(item.priceDate))),
              ],
            );
          },
        ).toList(growable: false),
      ),
    );
  }
}

String _priceText(PortfolioHoldingDto item) {
  final price = item.displayPrice;
  if (price == null) {
    return 'ناموجود';
  }
  return formatAssetMoney(price);
}

String _priceTooltip(PortfolioHoldingDto item) {
  final details = <String>[];
  if (item.displayPrice == null) {
    details.add('قیمت بازار برای این نماد موجود نیست');
  }
  final source = item.priceSource?.trim();
  if (source != null && source.isNotEmpty) {
    details.add('منبع قیمت: $source');
  }
  final updatedAt = _updatedAt(item.priceDate);
  if (updatedAt != '-') {
    details.add('زمان قیمت: $updatedAt');
  }
  if (item.isPriceStale == true) {
    details.add('قیمت قدیمی است');
  }
  return details.isEmpty ? 'قیمت بازار' : details.join('\n');
}

String _moneyPnlText(Decimal? value, {String missingText = '-'}) {
  if (value == null) {
    return missingText;
  }
  final prefix = value > Decimal.zero ? '+' : '';
  return '$prefix${formatAssetMoney(value)}';
}

Color _pnlColor(BuildContext context, Decimal? value) {
  final scheme = Theme.of(context).colorScheme;
  if (value == null || value == Decimal.zero) {
    return scheme.onSurfaceVariant;
  }
  return value > Decimal.zero ? Colors.green : scheme.error;
}

String _updatedAt(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}
