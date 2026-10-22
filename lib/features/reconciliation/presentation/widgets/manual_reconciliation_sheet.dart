import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../assets/presentation/widgets/asset_formatters.dart';
import '../../domain/reconciliation_models.dart';
import '../providers/manual_reconciliation_controller.dart';

class ManualReconciliationSheet extends ConsumerWidget {
  const ManualReconciliationSheet({
    required this.args,
    super.key,
  });

  final ManualReconciliationArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(manualReconciliationControllerProvider(args));
    final controller = ref.read(
      manualReconciliationControllerProvider(args).notifier,
    );
    ref.listen<ManualReconciliationState>(
      manualReconciliationControllerProvider(args),
      (previous, next) {
        if (next.isSuccess && previous?.isSuccess != true && context.mounted) {
          Navigator.of(context).pop(true);
        }
      },
    );

    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تطبیق دستی فروش ${args.sell.symbol}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      onPressed: state.isBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SellSummary(sell: args.sell),
                const SizedBox(height: 14),
                Text(
                  'خریدهای مبدا',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'یک یا چند خرید از پرتفوی‌های دیگر را انتخاب و مقدار قابل انتساب را وارد کنید.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                if (state.isLoadingCandidates)
                  const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (state.candidates.isEmpty)
                  _EmptyCandidates(onRetry: controller.loadCandidates)
                else
                  ...state.candidates.map(
                    (candidate) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CandidateCard(
                        candidate: candidate,
                        sellDate: args.sell.executedAt,
                        selected: state.allocations.containsKey(
                          candidate.transactionId,
                        ),
                        quantity: state.allocations[candidate.transactionId],
                        errorText: state.fieldErrors[candidate.transactionId],
                        enabled: state.preview == null && !state.isBusy,
                        onSelected: (value) => controller.toggleCandidate(
                          candidate.transactionId,
                          value,
                        ),
                        onQuantityChanged: (value) => controller.updateQuantity(
                          candidate.transactionId,
                          value,
                        ),
                      ),
                    ),
                  ),
                if (state.fieldErrors['form'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.fieldErrors['form']!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  enabled: state.preview == null && !state.isBusy,
                  initialValue: state.notes,
                  maxLength: 2000,
                  maxLines: 2,
                  onChanged: controller.updateNotes,
                  decoration: const InputDecoration(
                    labelText: 'یادداشت و دلیل تطبیق (اختیاری)',
                    hintText: 'مثال: انتقال دارایی از کارگزاری دیگر',
                  ),
                ),
                _AllocationTotal(
                  total: state.totalAllocated.toString(),
                  sellQuantity: args.sell.quantity.toString(),
                ),
                if (state.preview != null) ...[
                  const SizedBox(height: 12),
                  _PreviewCard(preview: state.preview!),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (state.preview != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isBusy ? null : controller.editDraft,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('ویرایش تخصیص'),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.isBusy
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('انصراف'),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: state.isBusy
                            ? null
                            : state.preview == null
                                ? controller.requestPreview
                                : controller.confirm,
                        icon: state.isRequestingPreview || state.isConfirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                state.preview == null
                                    ? Icons.preview_rounded
                                    : Icons.verified_rounded,
                              ),
                        label: Text(
                          state.preview == null
                              ? 'دریافت پیش‌نمایش'
                              : 'تایید نهایی تطبیق',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellSummary extends StatelessWidget {
  const _SellSummary({required this.sell});

  final ReconciliationSellSelection sell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _labelValue('پرتفوی فروش', sell.portfolioLabel),
          _labelValue(
            'تاریخ فروش',
            DateFormat('yyyy/MM/dd', 'en_US').format(sell.executedAt),
          ),
          _labelValue(
              'تعداد فروش', formatAssetNumber(sell.quantity.toString())),
          _labelValue('قیمت فروش', formatAssetMoney(sell.pricePerUnit)),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.sellDate,
    required this.selected,
    required this.quantity,
    required this.enabled,
    required this.onSelected,
    required this.onQuantityChanged,
    this.errorText,
  });

  final ReconciliationBuyCandidate candidate;
  final DateTime sellDate;
  final bool selected;
  final Object? quantity;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String> onQuantityChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged:
                    enabled ? (value) => onSelected(value ?? false) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.portfolioLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${DateFormat('yyyy/MM/dd', 'en_US').format(candidate.executedAt)}'
                      ' • فاصله ${candidate.dateDistanceDays(sellDate)} روز'
                      ' • خرید ${formatAssetNumber(candidate.quantity.toString())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'مانده قابل استفاده: ${formatAssetNumber(candidate.availableQuantity.toString())}'
                      ' • قیمت: ${formatAssetMoney(candidate.pricePerUnit)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('allocation-${candidate.transactionId}'),
              enabled: enabled,
              initialValue: quantity?.toString() ?? '',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: onQuantityChanged,
              decoration: InputDecoration(
                labelText: 'مقدار تخصیص',
                errorText: errorText,
                suffixText: 'سهم',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AllocationTotal extends StatelessWidget {
  const _AllocationTotal({
    required this.total,
    required this.sellQuantity,
  });

  final String total;
  final String sellQuantity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'مجموع تخصیص: ${formatAssetNumber(total)} از ${formatAssetNumber(sellQuantity)} سهم',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final ReconciliationPreview preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.tertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'پیش‌نمایش اثر حسابداری',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          _labelValue(
            'مقدار تطبیق',
            formatAssetNumber(preview.matchedQuantity.toString()),
          ),
          _labelValue(
            'باقی‌مانده فروش',
            formatAssetNumber(preview.remainingSellQuantity.toString()),
          ),
          _labelValue(
            'سود/زیان تحقق‌یافته برآوردی',
            formatAssetMoney(preview.estimatedRealizedPnl),
          ),
          const Divider(),
          ...preview.allocations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.portfolioLabel}: ${formatAssetNumber(item.matchedQuantity.toString())} سهم'
                ' • مانده خرید ${formatAssetNumber(item.remainingBuyQuantity.toString())}'
                ' • PnL ${formatAssetMoney(item.realizedPnl)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('خرید قابل استفاده‌ای در پرتفوی‌های دیگر پیدا نشد.'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تلاش دوباره'),
          ),
        ],
      ),
    );
  }
}

Widget _labelValue(String label, String value) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$label: '),
        TextSpan(
          text: value,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
