import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../portfolio/presentation/providers/portfolio_summary_provider.dart';
import '../../domain/transaction_request.dart';

enum TransactionSide { buy, sell }

class TransactionFormWidget extends ConsumerStatefulWidget {
  const TransactionFormWidget({
    required this.portfolioId,
    required this.assetId,
    required this.assetLabel,
    required this.availableQuantity,
    super.key,
  });

  final String portfolioId;
  final String assetId;
  final String assetLabel;
  final double availableQuantity;

  @override
  ConsumerState<TransactionFormWidget> createState() => _TransactionFormWidgetState();
}

class _TransactionFormWidgetState extends ConsumerState<TransactionFormWidget> {
  final _formKey = GlobalKey<FormState>(debugLabel: 'transaction_form_widget_form');
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feesController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  TransactionSide _side = TransactionSide.buy;
  DateTime _executedDate = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantityValue = _parseFormattedNumber(_quantityController.text);
    final exceedsAvailable = _side == TransactionSide.sell && quantityValue > widget.availableQuantity;
    final availableText = NumberFormat('#,##0.####').format(widget.availableQuantity);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New Transaction', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.assetLabel, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<TransactionSide>(
                initialValue: _side,
                items: const [
                  DropdownMenuItem(
                    value: TransactionSide.buy,
                    child: Text('BUY'),
                  ),
                  DropdownMenuItem(
                    value: TransactionSide.sell,
                    child: Text('SELL'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _side = value;
                          });
                        }
                      },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsSeparatorIntegerInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  helperText: _side == TransactionSide.sell ? 'Max available: $availableText' : null,
                ),
                validator: (value) {
                  final parsed = _parseFormattedNumber(value ?? '');
                  if (parsed <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  if (parsed != parsed.truncateToDouble()) {
                    return 'Quantity must be a whole number';
                  }
                  if (_side == TransactionSide.sell && parsed > widget.availableQuantity) {
                    return 'Cannot sell more than available quantity';
                  }
                  return null;
                },
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'Price per unit'),
                validator: (value) {
                  if (_parseFormattedNumber(value ?? '') <= 0) {
                    return 'Price must be greater than 0';
                  }
                  return null;
                },
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'Fees'),
                enabled: !_submitting,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Execution Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_executedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _submitting ? null : _pickDate,
              ),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                enabled: !_submitting,
              ),
              if (exceedsAvailable) ...[
                const SizedBox(height: 8),
                const Text(
                  'SELL quantity exceeds available quantity',
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting || exceedsAvailable ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _executedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: now,
    );
    if (!mounted) {
      return;
    }
    if (selected != null) {
      setState(() {
        _executedDate = selected;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_executedDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Execution date cannot be in the future')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final request = TransactionRequest(
      assetId: widget.assetId,
      transactionType: _side == TransactionSide.buy ? 'BUY' : 'SELL',
      quantity: _parseFormattedNumber(_quantityController.text),
      pricePerUnit: _parseFormattedNumber(_priceController.text),
      fees: _parseFormattedNumber(_feesController.text),
      executedAtIso: DateTime(
        _executedDate.year,
        _executedDate.month,
        _executedDate.day,
        12,
      ).toUtc().toIso8601String(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      await ref
          .read(portfolioSummaryProvider(widget.portfolioId).notifier)
          .submitTransactionOptimistic(request);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction submitted')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text.replaceAll(',', '');
    if (cleaned.isEmpty) {
      return const TextEditingValue();
    }

    final parts = cleaned.split('.');
    final integerPart = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final decimalPart = parts.length > 1 ? parts.sublist(1).join() : '';

    if (integerPart.isEmpty) {
      return oldValue;
    }

    final formattedInteger = NumberFormat('#,###').format(int.parse(integerPart));
    final formatted = decimalPart.isEmpty ? formattedInteger : '$formattedInteger.$decimalPart';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ThousandsSeparatorIntegerInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorIntegerInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final integerPart = newValue.text.replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
    if (integerPart.isEmpty) {
      return const TextEditingValue();
    }

    final formattedInteger = NumberFormat('#,###').format(int.parse(integerPart));

    return TextEditingValue(
      text: formattedInteger,
      selection: TextSelection.collapsed(offset: formattedInteger.length),
    );
  }
}

double _parseFormattedNumber(String value) {
  final cleaned = value.replaceAll(',', '').trim();
  if (cleaned.isEmpty) {
    return 0;
  }
  return double.tryParse(cleaned) ?? 0;
}
