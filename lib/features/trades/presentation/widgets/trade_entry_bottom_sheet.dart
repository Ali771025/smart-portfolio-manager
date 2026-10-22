import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/app_failure.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../domain/models/trade_ticket.dart';
import '../controllers/trade_entry_controller.dart';

class TradeEntryBottomSheet extends ConsumerStatefulWidget {
  const TradeEntryBottomSheet({
    super.key,
    this.initialSymbol,
    this.initialPortfolioId,
  });

  final String? initialSymbol;
  final String? initialPortfolioId;

  @override
  ConsumerState<TradeEntryBottomSheet> createState() => _TradeEntryBottomSheetState();
}

class _TradeEntryBottomSheetState extends ConsumerState<TradeEntryBottomSheet> {
  final _formKey = GlobalKey<FormState>(debugLabel: 'trade_entry_bottom_sheet_form');
  late final TextEditingController _symbolController;
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _feesController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  TradeSide _side = TradeSide.buy;
  String? _selectedPortfolioId;
  late DateTime _tradeDate;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(
      text: widget.initialSymbol?.trim().toUpperCase() ?? '',
    );
    _selectedPortfolioId =
        widget.initialPortfolioId ?? ref.read(selectedPortfolioIdProvider);
    _tradeDate = DateTime.now();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tradeState = ref.watch(tradeEntryControllerProvider);
    final portfolios = ref.watch(portfolioOptionsProvider);

    final qty = _parse(_qtyController.text);
    final price = _parse(_priceController.text);
    final fees = _parse(_feesController.text);
    // BUY: total = qty * price + fees (fees increase cost)
    // SELL: total = qty * price - fees (fees reduce proceeds)
    final total = _side == TradeSide.buy
        ? qty * price + fees
        : qty * price - fees;

    final hasPortfolio = portfolios.isNotEmpty;
    if (_selectedPortfolioId != null &&
        portfolios.every((item) => item.id != _selectedPortfolioId)) {
      _selectedPortfolioId = null;
    }
    if (_selectedPortfolioId == null && hasPortfolio) {
      _selectedPortfolioId = portfolios.first.id;
      ref.read(selectedPortfolioIdProvider.notifier).state = _selectedPortfolioId;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ثبت سفارش',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<TradeSide>(
                segments: const [
                  ButtonSegment(value: TradeSide.buy, label: Text('خرید')),
                  ButtonSegment(value: TradeSide.sell, label: Text('فروش')),
                ],
                selected: {_side},
                onSelectionChanged: (selection) {
                  setState(() {
                    _side = selection.first;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedPortfolioId,
                isExpanded: true,
                items: portfolios
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(growable: false),
                onChanged: tradeState.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedPortfolioId = value;
                        });
                        ref.read(selectedPortfolioIdProvider.notifier).state = value;
                      },
                decoration: const InputDecoration(
                  labelText: 'پرتفوی مقصد',
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'پرتفوی را انتخاب کنید.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _symbolController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'نماد',
                  hintText: 'مثال: فولاد',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'نماد الزامی است.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                inputFormatters: const [DigitsOnlyThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'تعداد'),
                validator: (value) {
                  final parsed = _parse(value ?? '');
                  if (parsed <= 0) {
                    return 'تعداد باید بیشتر از صفر باشد.';
                  }
                  if (parsed != parsed.truncateToDouble()) {
                    return 'تعداد باید عدد صحیح باشد.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'قیمت'),
                validator: (value) {
                  if (_parse(value ?? '') <= 0) {
                    return 'قیمت باید بیشتر از صفر باشد.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _feesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'کارمزد'),
                validator: (value) {
                  final parsedFees = _parse(value ?? '0');
                  if (parsedFees < 0) {
                    return 'کارمزد نمی‌تواند منفی باشد.';
                  }
                  // For SELL: fees cannot exceed trade value
                  if (_side == TradeSide.sell && parsedFees > 0) {
                    final tradeValue = _parse(_qtyController.text) * _parse(_priceController.text);
                    if (tradeValue > 0 && parsedFees > tradeValue) {
                      return 'کارمزد نمی‌تواند بیشتر از مبلغ کل معامله باشد.';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: tradeState.isLoading ? null : _pickTradeDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاریخ معامله',
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    '${_tradeDate.year}/${_tradeDate.month.toString().padLeft(2, '0')}/${_tradeDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'یادداشت (اختیاری)',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  'مبلغ کل: ${NumberFormat.currency(locale: 'fa_IR', symbol: 'ریال ', decimalDigits: 2).format(total)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (tradeState.hasError) ...[
                const SizedBox(height: 8),
                _ErrorText(error: tradeState.error),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: tradeState.isLoading || !hasPortfolio ? null : _submit,
                  icon: tradeState.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_side == TradeSide.buy ? Icons.add_shopping_cart_rounded : Icons.sell_rounded),
                  label: Text(_side == TradeSide.buy ? 'ثبت سفارش خرید' : 'ثبت سفارش فروش'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTradeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tradeDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _tradeDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ticket = TradeTicket(
      side: _side,
      symbol: _symbolController.text.trim().toUpperCase(),
      portfolioId: _selectedPortfolioId!,
      quantity: _parseQuantity(_qtyController.text),  // Integer for Tehran market
      price: _parse(_priceController.text),
      fees: _parse(_feesController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      executedAt: _tradeDate,
    );

    final result = await ref.read(tradeEntryControllerProvider.notifier).submit(ticket);
    if (!mounted) {
      return;
    }
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) {
        ref.invalidate(portfolioManagerControllerProvider);
        Navigator.of(context).pop(true);
      },
    );
  }

  double _parse(String value) => double.tryParse(value.trim().replaceAll(',', '')) ?? 0;

  /// Parse quantity as integer for Tehran stock market (whole shares only).
  int _parseQuantity(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    final parsed = int.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return 0;
    }
    return parsed;
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final text = currentError is AppFailure ? currentError.message : 'خطا در ثبت سفارش';
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        color: scheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class DigitsOnlyThousandsSeparatorInputFormatter extends TextInputFormatter {
  const DigitsOnlyThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) {
      return const TextEditingValue();
    }

    final formatted = NumberFormat('#,###').format(int.parse(cleaned));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
