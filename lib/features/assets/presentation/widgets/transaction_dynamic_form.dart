import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/asset_ledger_notifiers.dart';

class TransactionDynamicForm extends ConsumerStatefulWidget {
  const TransactionDynamicForm({
    required this.scope,
    this.initialTransactionType,
    super.key,
  });

  final AssetScope scope;
  final String? initialTransactionType;

  @override
  ConsumerState<TransactionDynamicForm> createState() => _TransactionDynamicFormState();
}

class _TransactionDynamicFormState extends ConsumerState<TransactionDynamicForm> {
  bool _didPopOnSuccess = false;
  bool _didApplyInitialType = false;

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feesController = TextEditingController(text: '0');
  final _dividendController = TextEditingController(text: '0');
  final _bonusRatioController = TextEditingController(text: '0');
  final _splitFromController = TextEditingController(text: '1');
  final _splitToController = TextEditingController(text: '2');
  final _rightsRatioController = TextEditingController(text: '0');
  final _subscriptionPriceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _dividendController.dispose();
    _bonusRatioController.dispose();
    _splitFromController.dispose();
    _splitToController.dispose();
    _rightsRatioController.dispose();
    _subscriptionPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormControllerProvider(widget.scope));
    final notifier = ref.read(transactionFormControllerProvider(widget.scope).notifier);
    ref.listen(
      transactionFormControllerProvider(widget.scope),
      (previous, next) {
        final prevSuccess = previous?.value?.submitSuccess ?? false;
        final nextSuccess = next.value?.submitSuccess ?? false;
        if (!prevSuccess && nextSuccess && !_didPopOnSuccess && mounted) {
          _didPopOnSuccess = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تراکنش با موفقیت ثبت شد.')),
          );
          Navigator.of(context).pop(true);
        }
      },
    );

    return state.when(
      data: (form) {
        final preferredType = widget.initialTransactionType;
        if (!_didApplyInitialType &&
            preferredType != null &&
            preferredType.isNotEmpty &&
            form.transactionType != preferredType) {
          _didApplyInitialType = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              notifier.updateType(preferredType);
            }
          });
        }
        final txType = form.transactionType;
        final isDividend = txType == 'CASH_DIVIDEND';
        final isSplit = txType == 'STOCK_SPLIT';
        final isBonus = txType == 'CAPITAL_INCREASE_BONUS';
        final isRights = txType == 'PRE_EMPTIVE_RIGHTS';

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ثبت تراکنش',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: txType,
                decoration: const InputDecoration(labelText: 'نوع تراکنش'),
                items: const [
                  DropdownMenuItem(value: 'BUY', child: Text('خرید')),
                  DropdownMenuItem(value: 'SELL', child: Text('فروش')),
                  DropdownMenuItem(value: 'CASH_DIVIDEND', child: Text('سود نقدی')),
                  DropdownMenuItem(value: 'CAPITAL_INCREASE_BONUS', child: Text('افزایش سرمایه جایزه')),
                  DropdownMenuItem(value: 'STOCK_SPLIT', child: Text('تجزیه سهم')),
                  DropdownMenuItem(value: 'PRE_EMPTIVE_RIGHTS', child: Text('حق تقدم')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    notifier.updateType(value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'تعداد'),
                onChanged: notifier.updateQuantity,
              ),
              const SizedBox(height: 10),
              if (txType == 'BUY' || txType == 'SELL')
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قیمت واحد'),
                  onChanged: notifier.updatePrice,
                ),
              if (txType == 'BUY' || txType == 'SELL') const SizedBox(height: 10),
              if (txType == 'BUY' || txType == 'SELL')
                TextField(
                  controller: _feesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'کارمزد'),
                  onChanged: notifier.updateFees,
                ),
              if (txType == 'BUY' || txType == 'SELL') const SizedBox(height: 10),
              if (isDividend)
                TextField(
                  controller: _dividendController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سود هر سهم'),
                  onChanged: notifier.updateDividendPerUnit,
                ),
              if (isDividend) const SizedBox(height: 10),
              if (isBonus)
                TextField(
                  controller: _bonusRatioController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'نسبت جایزه'),
                  onChanged: notifier.updateBonusRatio,
                ),
              if (isBonus) const SizedBox(height: 10),
              if (isSplit)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _splitFromController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'از'),
                        onChanged: notifier.updateSplitFrom,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _splitToController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'به'),
                        onChanged: notifier.updateSplitTo,
                      ),
                    ),
                  ],
                ),
              if (isSplit) const SizedBox(height: 10),
              if (isRights)
                TextField(
                  controller: _rightsRatioController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'نسبت حق تقدم'),
                  onChanged: notifier.updateRightsRatio,
                ),
              if (isRights) const SizedBox(height: 10),
              if (isRights)
                TextField(
                  controller: _subscriptionPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قیمت پذیره‌نویسی'),
                  onChanged: notifier.updateSubscriptionPrice,
                ),
              if (isRights) const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'یادداشت'),
                onChanged: notifier.updateNotes,
              ),
              const SizedBox(height: 12),
              if (form.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    form.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (form.submitSuccess)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'تراکنش با موفقیت ثبت شد.',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: form.submitting ? null : notifier.submit,
                  icon: form.submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(form.submitting ? 'در حال ثبت...' : 'ثبت تراکنش'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, _) => Text('خطا: $error'),
    );
  }
}
