import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../data/asset_ledger_repository.dart';
import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';
import 'asset_metric_card.dart';

class SelectedAssetDetailPanel extends StatelessWidget {
  const SelectedAssetDetailPanel({
    required this.holding,
    required this.breakEvenInfo,
    required this.isBreakEvenLoading,
    required this.onSaveBreakEvenPrice,
    required this.onOpenTransactionSheet,
    required this.onOpenManualReconciliation,
    required this.onQuickAction,
    super.key,
  });

  final PortfolioHoldingDto holding;
  final AssetBreakEvenInfo? breakEvenInfo;
  final bool isBreakEvenLoading;
  final Future<void> Function(Decimal? value) onSaveBreakEvenPrice;
  final VoidCallback onOpenTransactionSheet;
  final VoidCallback onOpenManualReconciliation;
  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priceWarnings = _priceWarnings(holding);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  holding.name?.trim().isNotEmpty == true
                      ? '${holding.symbol.toUpperCase()} - ${holding.name}'
                      : 'جزئیات ${holding.symbol.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenTransactionSheet,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('ثبت تراکنش'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(label: 'خرید', onTap: () => onQuickAction('BUY')),
              _ActionChip(label: 'فروش', onTap: () => onQuickAction('SELL')),
              _ActionChip(
                  label: 'جایزه',
                  onTap: () => onQuickAction('CAPITAL_INCREASE_BONUS')),
              _ActionChip(
                  label: 'تجزیه', onTap: () => onQuickAction('STOCK_SPLIT')),
              _ActionChip(
                  label: 'سود نقدی',
                  onTap: () => onQuickAction('CASH_DIVIDEND')),
              _ActionChip(
                  label: 'مشاهده دفتر معاملات',
                  onTap: () => onQuickAction('VIEW_LEDGER')),
              _ActionChip(
                  label: 'تطبیق دستی فروش', onTap: onOpenManualReconciliation),
            ],
          ),
          const SizedBox(height: 10),
          _BreakEvenEditorCard(
            info: breakEvenInfo,
            fallbackComputedPrice: holding.weightedAvgCost,
            isLoading: isBreakEvenLoading,
            onSave: onSaveBreakEvenPrice,
          ),
          if (priceWarnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PriceStatusNotice(messages: priceWarnings),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final cards = <AssetMetricCard>[
                AssetMetricCard(
                  label: 'نوع دارایی',
                  value: '-',
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'تعداد',
                  value: formatAssetNumber(holding.quantity.toString()),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'میانگین خرید',
                  value: formatAssetMoney(holding.weightedAvgCost),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'بهای تمام‌شده',
                  value: formatAssetMoney(holding.costBasis),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'قیمت آخر',
                  value: formatOptionalAssetMoney(
                    holding.displayPrice,
                    fallback: 'ناموجود',
                  ),
                  valueColor: holding.displayPrice == null
                      ? scheme.onSurfaceVariant
                      : null,
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'ارزش بازار',
                  value: formatOptionalAssetMoney(
                    holding.marketValue,
                    fallback: 'نامشخص',
                  ),
                  valueColor: holding.marketValue == null
                      ? scheme.onSurfaceVariant
                      : null,
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'سود/زیان تحقق‌نیافته',
                  value: formatOptionalAssetMoney(
                    holding.unrealizedPnl,
                    fallback: 'نامشخص',
                  ),
                  valueColor: _pnlColor(context, holding.unrealizedPnl),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'سود/زیان تحقق‌یافته',
                  value: formatAssetMoney(holding.realizedPnl),
                  valueColor: _pnlColor(context, holding.realizedPnl),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'سود/زیان کل',
                  value: formatOptionalAssetMoney(
                    holding.totalPnl,
                    fallback: 'نامشخص',
                  ),
                  valueColor: _pnlColor(context, holding.totalPnl),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'بازدهی',
                  value: formatOptionalAssetPercent(
                    holding.roi ?? holding.totalPnlPercent,
                    fallback: '-',
                  ),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'ارز پایه',
                  value: holding.currency,
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'آخرین به‌روزرسانی قیمت',
                  value: _updatedAt(holding.priceDate),
                  compact: true,
                ),
                AssetMetricCard(
                  label: 'منبع قیمت',
                  value: holding.priceSource ?? 'ناموجود',
                  compact: true,
                ),
              ];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 2 : 1,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: isWide ? 2.1 : 2.4,
                children: cards,
              );
            },
          ),
          if (holding.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              holding.warnings.join('، '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _priceWarnings(PortfolioHoldingDto holding) {
  final messages = <String>[];
  if (!holding.hasMarketPrice || holding.displayPrice == null) {
    messages.add(
      'قیمت بازار این نماد دریافت نشده است؛ سود/زیان تحقق‌نیافته محاسبه نشده است.',
    );
  }
  if (holding.isPriceStale == true) {
    messages.add('قیمت بازار قدیمی است.');
  }
  return messages;
}

Color _pnlColor(BuildContext context, Decimal? value) {
  final scheme = Theme.of(context).colorScheme;
  if (value == null || value == Decimal.zero) {
    return scheme.onSurfaceVariant;
  }
  return value > Decimal.zero ? Colors.green : scheme.error;
}

class _PriceStatusNotice extends StatelessWidget {
  const _PriceStatusNotice({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messages.join('\n'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakEvenEditorCard extends StatelessWidget {
  const _BreakEvenEditorCard({
    required this.info,
    required this.fallbackComputedPrice,
    required this.isLoading,
    required this.onSave,
  });

  final AssetBreakEvenInfo? info;
  final Decimal fallbackComputedPrice;
  final bool isLoading;
  final Future<void> Function(Decimal? value) onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = info?.breakEvenPrice ?? fallbackComputedPrice;
    final computed = info?.computedBreakEvenPrice ?? fallbackComputedPrice;
    final manual = info?.manualBreakEvenPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'قیمت سر به سر',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () =>
                      _openBreakEvenDialog(context, manual ?? effective),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(manual == null ? 'ثبت دستی' : 'ویرایش'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BreakEvenChip(
                label: manual == null ? 'مقدار نهایی' : 'مقدار دستی',
                value: formatAssetMoney(effective),
                emphasized: true,
              ),
              _BreakEvenChip(
                label: 'محاسباتی',
                value: formatAssetMoney(computed),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'این عدد قیمت فروشی است که با آن، سود و زیان این دارایی صفر می‌شود. اگر مقدار دستی ثبت نکنید، میانگین خرید فعلی نمایش داده می‌شود.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (manual != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onSave(null),
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('پاک کردن مقدار دستی'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openBreakEvenDialog(
      BuildContext context, Decimal initialValue) async {
    final controller = TextEditingController(text: initialValue.toString());
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<Decimal?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ثبت قیمت سر به سر'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'قیمت سر به سر',
                suffixText: 'ریال',
              ),
              validator: (raw) {
                final source = raw?.trim() ?? '';
                if (source.isEmpty) {
                  return 'قیمت را وارد کنید.';
                }
                final parsed = Decimal.tryParse(source.replaceAll(',', ''));
                if (parsed == null || parsed <= Decimal.zero) {
                  return 'قیمت باید بزرگ‌تر از صفر باشد.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                final parsed =
                    Decimal.parse(controller.text.trim().replaceAll(',', ''));
                Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text('ذخیره'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (value != null) {
      await onSave(value);
    }
  }
}

class _BreakEvenChip extends StatelessWidget {
  const _BreakEvenChip({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: 0.28)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

String _updatedAt(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}/$month/$day $hour:$minute';
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
