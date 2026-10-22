import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/decimal_utils.dart';
import '../../domain/manual_entry_state.dart';
import '../../domain/manual_transaction_type.dart';
import '../../domain/problem_details.dart';
import '../controllers/manual_entry_controller.dart';

class ManualTransactionEntryForm extends ConsumerStatefulWidget {
  const ManualTransactionEntryForm({
    required this.portfolioId,
    required this.symbol,
    super.key,
  });

  final String portfolioId;
  final String symbol;

  @override
  ConsumerState<ManualTransactionEntryForm> createState() =>
      _ManualTransactionEntryFormState();
}

class _ManualTransactionEntryFormState
    extends ConsumerState<ManualTransactionEntryForm> {
  final _formKey = GlobalKey<FormState>(debugLabel: 'manual_transaction_form');
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController(text: '0');
  final _dpsController = TextEditingController();
  final _bonusRatioController = TextEditingController();
  final _rightsRatioController = TextEditingController();
  final _splitFromController = TextEditingController(text: '1');
  final _splitToController = TextEditingController(text: '2');
  final _targetSymbolController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(manualEntryControllerProvider.notifier).initialize(
            portfolioId: widget.portfolioId,
            symbol: widget.symbol,
          );
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _dpsController.dispose();
    _bonusRatioController.dispose();
    _rightsRatioController.dispose();
    _splitFromController.dispose();
    _splitToController.dispose();
    _targetSymbolController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    final successColor = semantic?.success ?? Theme.of(context).colorScheme.primary;
    ref.listen<AsyncValue<ManualEntryFormState>>(
      manualEntryControllerProvider,
      (previous, next) {
        if (!mounted) {
          return;
        }

        if (next.hasError) {
          final error = next.error;
          final message = error is ProblemDetailsException
              ? error.detail
              : 'هنگام ثبت تراکنش خطای غیرمنتظره رخ داد.';
          _showErrorBottomSheet(context, message);
          return;
        }

        final currentValue = next.value;
        final previousValue = previous?.value;
        if (currentValue != null &&
            currentValue.submitSuccess &&
            (previousValue?.submitSuccess ?? false) == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تراکنش دستی با موفقیت ثبت شد.'),
            ),
          );
        }
      },
    );

    final state = ref.watch(manualEntryControllerProvider);
    final snapshot =
        state.value ?? ManualEntryFormState(payload: _fallbackPayload());
    final controller = ref.read(manualEntryControllerProvider.notifier);
    final payload = snapshot.payload;
    final isSubmitting = state.isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ManualTransactionType>(
            initialValue: payload.transactionType,
            decoration: const InputDecoration(
              labelText: 'نوع تراکنش',
            ),
            items: ManualTransactionType.values
                .map(
                  (entry) => DropdownMenuItem<ManualTransactionType>(
                    value: entry,
                    child: Text(entry.displayLabel),
                  ),
                )
                .toList(growable: false),
            onChanged: isSubmitting
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    controller.changeType(value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'تعداد',
              errorText: _fieldError(snapshot, 'quantity'),
            ),
            onChanged: (value) {
              controller.clearFieldError('quantity');
              controller.updateQuantity(value);
            },
            validator: (_) => _localDecimalValidator(
              _quantityController.text,
              fieldLabel: 'تعداد',
              mustBePositive: true,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildReactiveFields(
            context: context,
            payload: payload,
            snapshot: snapshot,
            controller: controller,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'یادداشت (اختیاری)',
            ),
            maxLines: 2,
            onChanged: controller.updateNotes,
          ),
          const SizedBox(height: 16),
          _LiveSummaryCard(total: snapshot.liveTotal),
          if (snapshot.globalErrorMessage != null &&
              snapshot.globalErrorMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.globalErrorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final isValid = _formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }
                      await controller.submit();
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Theme.of(context).colorScheme.surfaceContainerHighest;
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return successColor.withValues(alpha: 0.84);
                  }
                  return successColor;
                }),
                foregroundColor:
                    WidgetStateProperty.all(Theme.of(context).colorScheme.onPrimary),
                iconColor:
                    WidgetStateProperty.all(Theme.of(context).colorScheme.onPrimary),
              ),
              label: const Text('ثبت تراکنش دستی'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReactiveFields({
    required BuildContext context,
    required ManualEntryPayload payload,
    required ManualEntryFormState snapshot,
    required ManualEntryController controller,
  }) {
    return payload.map(
      buy: (_) => _buildPriceCommissionFields(
        snapshot: snapshot,
        controller: controller,
        priceLabel: 'قیمت',
      ),
      sell: (_) => _buildPriceCommissionFields(
        snapshot: snapshot,
        controller: controller,
        priceLabel: 'قیمت',
      ),
      preEmptiveRights: (_) => [
        ..._buildPriceCommissionFields(
          snapshot: snapshot,
          controller: controller,
          priceLabel: 'قیمت پذیره‌نویسی',
          priceFieldKey: 'subscription_price',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _rightsRatioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'نسبت حق‌تقدم',
            errorText: _fieldError(snapshot, 'rights_ratio'),
          ),
          onChanged: (value) {
            controller.clearFieldError('rights_ratio');
            controller.updateRightsRatio(value);
          },
          validator: (_) => _localDecimalValidator(
            _rightsRatioController.text,
            fieldLabel: 'نسبت حق‌تقدم',
            mustBePositive: true,
          ),
        ),
      ],
      cashDividend: (_) => [
        TextFormField(
          controller: _dpsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'مبلغ سود نقدی',
            helperText: 'برای سود نقدی، وارد کردن قیمت الزامی نیست.',
            errorText: _fieldError(snapshot, 'dps'),
          ),
          onChanged: (value) {
            controller.clearFieldError('dps');
            controller.updateDps(value);
          },
          validator: (_) => _localDecimalValidator(
            _dpsController.text,
            fieldLabel: 'مبلغ سود نقدی',
            mustBePositive: true,
          ),
        ),
      ],
      capitalIncreaseBonus: (_) => [
        TextFormField(
          controller: _bonusRatioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'نسبت سهام جایزه',
            helperText: 'برای این نوع تراکنش، قیمت و کارمزد صفر در نظر گرفته می‌شود.',
            errorText: _fieldError(snapshot, 'bonus_ratio'),
          ),
          onChanged: (value) {
            controller.clearFieldError('bonus_ratio');
            controller.updateBonusRatio(value);
          },
          validator: (_) => _localDecimalValidator(
            _bonusRatioController.text,
            fieldLabel: 'نسبت سهام جایزه',
            mustBePositive: true,
          ),
        ),
      ],
      stockSplit: (_) => [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _splitFromController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'تجزیه از',
                  errorText: _fieldError(snapshot, 'split_from'),
                ),
                onChanged: (value) {
                  controller.clearFieldError('split_from');
                  controller.updateSplitFrom(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _splitToController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'تجزیه به',
                  errorText: _fieldError(snapshot, 'split_to'),
                ),
                onChanged: (value) {
                  controller.clearFieldError('split_to');
                  controller.updateSplitTo(value);
                },
              ),
            ),
          ],
        ),
      ],
      assetTransfer: (_) => [
        TextFormField(
          controller: _targetSymbolController,
          decoration: InputDecoration(
            labelText: 'نماد مقصد',
            errorText: _fieldError(snapshot, 'target_symbol'),
          ),
          onChanged: (value) {
            controller.clearFieldError('target_symbol');
            controller.updateTargetSymbol(value);
          },
          validator: (_) {
            if (_targetSymbolController.text.trim().isEmpty) {
              return 'نماد مقصد الزامی است.';
            }
            return null;
          },
        ),
      ],
    );
  }

  List<Widget> _buildPriceCommissionFields({
    required ManualEntryFormState snapshot,
    required ManualEntryController controller,
    required String priceLabel,
    String priceFieldKey = 'price',
  }) {
    return [
      TextFormField(
        controller: _priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: priceLabel,
          errorText: _fieldError(snapshot, priceFieldKey),
        ),
        onChanged: (value) {
          controller.clearFieldError(priceFieldKey);
          controller.updatePrice(value);
        },
        validator: (_) => _localDecimalValidator(
          _priceController.text,
          fieldLabel: priceLabel,
          mustBePositive: true,
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _commissionController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'کارمزد',
          errorText: _fieldError(snapshot, 'commission'),
        ),
        onChanged: (value) {
          controller.clearFieldError('commission');
          controller.updateCommission(value);
        },
        validator: (_) => _localDecimalValidator(
          _commissionController.text,
          fieldLabel: 'کارمزد',
          mustBePositive: false,
        ),
      ),
    ];
  }

  String? _fieldError(ManualEntryFormState state, String field) {
    final value = state.fieldErrors[field];
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  String? _localDecimalValidator(
    String raw, {
    required String fieldLabel,
    required bool mustBePositive,
  }) {
    final value = parseDecimalOrZero(raw);
    if (mustBePositive && value <= decimalZero) {
      return '$fieldLabel باید بیشتر از صفر باشد.';
    }
    if (!mustBePositive && value < decimalZero) {
      return '$fieldLabel نمی‌تواند منفی باشد.';
    }
    return null;
  }

  void _showErrorBottomSheet(BuildContext context, String message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ثبت تراکنش ناموفق بود',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('بستن'),
              ),
            ],
          ),
        );
      },
    );
  }

  ManualEntryPayload _fallbackPayload() {
    return ManualEntryPayload.buy(
      portfolioId: widget.portfolioId,
      symbol: widget.symbol,
      tradeDate: DateTime.now(),
      quantity: decimalZero,
      price: decimalZero,
      commission: decimalZero,
    );
  }
}

class _LiveSummaryCard extends StatelessWidget {
  const _LiveSummaryCard({
    required this.total,
  });

  final Decimal total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.calculate_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'جمع لحظه‌ای',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              total.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
