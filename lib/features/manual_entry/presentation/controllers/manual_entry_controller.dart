import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/manual_entry_repository.dart';
import '../../domain/decimal_utils.dart';
import '../../domain/manual_entry_state.dart';
import '../../domain/manual_transaction_type.dart';
import '../../domain/problem_details.dart';

final manualEntryControllerProvider =
    AsyncNotifierProvider<ManualEntryController, ManualEntryFormState>(
  ManualEntryController.new,
);

class ManualEntryController extends AsyncNotifier<ManualEntryFormState> {
  Timer? _debounceTimer;

  ManualEntryRepository get _repository => ref.read(manualEntryRepositoryProvider);

  @override
  FutureOr<ManualEntryFormState> build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return ManualEntryFormState(payload: _initialPayload());
  }

  void initialize({
    required String portfolioId,
    required String symbol,
  }) {
    _applyMutation((payload) {
      return payload.map(
        buy: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        sell: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        capitalIncreaseBonus: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        stockSplit: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        preEmptiveRights: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        cashDividend: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
        assetTransfer: (entry) => entry.copyWith(
          portfolioId: portfolioId,
          symbol: symbol.trim().toUpperCase(),
        ),
      );
    });
  }

  void changeType(ManualTransactionType type) {
    _applyMutation(
      (current) => _convertPayloadType(current, type),
    );
  }

  void updateQuantity(String rawValue) {
    _applyMutation(
      (payload) => payload.map(
        buy: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        sell: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        capitalIncreaseBonus: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        stockSplit: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        preEmptiveRights: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        cashDividend: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
        assetTransfer: (entry) => entry.copyWith(quantity: parseDecimalOrZero(rawValue)),
      ),
      debounced: true,
    );
  }

  void updatePrice(String rawValue) {
    _applyMutation(
      (payload) => payload.map(
        buy: (entry) => entry.copyWith(price: parseDecimalOrZero(rawValue)),
        sell: (entry) => entry.copyWith(price: parseDecimalOrZero(rawValue)),
        capitalIncreaseBonus: (entry) => entry,
        stockSplit: (entry) => entry,
        preEmptiveRights: (entry) => entry.copyWith(
          subscriptionPrice: parseDecimalOrZero(rawValue),
        ),
        cashDividend: (entry) => entry,
        assetTransfer: (entry) => entry,
      ),
      debounced: true,
    );
  }

  void updateCommission(String rawValue) {
    _applyMutation(
      (payload) => payload.map(
        buy: (entry) => entry.copyWith(commission: parseDecimalOrZero(rawValue)),
        sell: (entry) => entry.copyWith(commission: parseDecimalOrZero(rawValue)),
        capitalIncreaseBonus: (entry) => entry,
        stockSplit: (entry) => entry,
        preEmptiveRights: (entry) => entry.copyWith(commission: parseDecimalOrZero(rawValue)),
        cashDividend: (entry) => entry,
        assetTransfer: (entry) => entry,
      ),
      debounced: true,
    );
  }

  void updateDps(String rawValue) {
    _applyMutation(
      (payload) => payload.maybeMap(
        cashDividend: (entry) => entry.copyWith(dps: parseDecimalOrZero(rawValue)),
        orElse: () => payload,
      ),
      debounced: true,
    );
  }

  void updateBonusRatio(String rawValue) {
    _applyMutation(
      (payload) => payload.maybeMap(
        capitalIncreaseBonus: (entry) => entry.copyWith(
          bonusRatio: parseDecimalOrZero(rawValue),
        ),
        orElse: () => payload,
      ),
      debounced: true,
    );
  }

  void updateRightsRatio(String rawValue) {
    _applyMutation(
      (payload) => payload.maybeMap(
        preEmptiveRights: (entry) => entry.copyWith(
          rightsRatio: parseDecimalOrZero(rawValue),
        ),
        orElse: () => payload,
      ),
      debounced: true,
    );
  }

  void updateSplitFrom(String rawValue) {
    _applyMutation(
      (payload) => payload.maybeMap(
        stockSplit: (entry) => entry.copyWith(
          splitFrom: int.tryParse(rawValue.trim()) ?? entry.splitFrom,
        ),
        orElse: () => payload,
      ),
      debounced: true,
    );
  }

  void updateSplitTo(String rawValue) {
    _applyMutation(
      (payload) => payload.maybeMap(
        stockSplit: (entry) => entry.copyWith(
          splitTo: int.tryParse(rawValue.trim()) ?? entry.splitTo,
        ),
        orElse: () => payload,
      ),
      debounced: true,
    );
  }

  void updateTargetSymbol(String value) {
    _applyMutation(
      (payload) => payload.maybeMap(
        assetTransfer: (entry) => entry.copyWith(targetSymbol: value.trim().toUpperCase()),
        orElse: () => payload,
      ),
    );
  }

  void updateNotes(String value) {
    _applyMutation(
      (payload) => payload.map(
        buy: (entry) => entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        sell: (entry) => entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        capitalIncreaseBonus: (entry) =>
            entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        stockSplit: (entry) => entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        preEmptiveRights: (entry) =>
            entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        cashDividend: (entry) => entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
        assetTransfer: (entry) => entry.copyWith(notes: value.trim().isEmpty ? null : value.trim()),
      ),
    );
  }

  Future<void> submit() async {
    _flushDebounce();
    final current = state.value ?? ManualEntryFormState(payload: _initialPayload());
    final fieldErrors = _validate(current.payload);

    if (fieldErrors.isNotEmpty) {
      state = AsyncData(
        current.copyWith(
          fieldErrors: fieldErrors,
          submitSuccess: false,
          globalErrorMessage: null,
        ),
      );
      return;
    }

    state = const AsyncLoading<ManualEntryFormState>();

    try {
      await _repository.submit(
        payload: current.payload,
        idempotencyKey: _buildIdempotencyKey(current.payload),
      );
      state = AsyncData(
        current.copyWith(
          fieldErrors: const <String, String>{},
          submitSuccess: true,
          globalErrorMessage: null,
        ),
      );
    } on ProblemDetailsException catch (problem) {
      final hasFieldErrors = problem.hasFieldErrors;
      if (hasFieldErrors) {
        state = AsyncData(
          current.copyWith(
            fieldErrors: problem.toFieldErrorMap(),
            submitSuccess: false,
            globalErrorMessage: problem.detail,
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          submitSuccess: false,
          globalErrorMessage: problem.detail,
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          submitSuccess: false,
          globalErrorMessage: 'Unexpected error occurred. Please retry.',
        ),
      );
    }
  }

  void clearFieldError(String field) {
    final snapshot = state.value;
    if (snapshot == null || !snapshot.fieldErrors.containsKey(field)) {
      return;
    }
    final updated = Map<String, String>.from(snapshot.fieldErrors)..remove(field);
    state = AsyncData(snapshot.copyWith(fieldErrors: updated));
  }

  void _applyMutation(
    ManualEntryPayload Function(ManualEntryPayload current) transform, {
    bool debounced = false,
  }) {
    if (debounced) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 180), () {
        _applyMutation(transform, debounced: false);
      });
      return;
    }

    final snapshot = state.value ?? ManualEntryFormState(payload: _initialPayload());
    final nextPayload = transform(snapshot.payload);
    state = AsyncData(
      snapshot.copyWith(
        payload: nextPayload,
        submitSuccess: false,
      ),
    );
  }

  void _flushDebounce() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
  }

  Map<String, String> _validate(ManualEntryPayload payload) {
    final errors = <String, String>{};

    if (payload.map(
          buy: (entry) => entry.quantity <= decimalZero,
          sell: (entry) => entry.quantity <= decimalZero,
          capitalIncreaseBonus: (entry) => entry.quantity <= decimalZero,
          stockSplit: (entry) => entry.quantity <= decimalZero,
          preEmptiveRights: (entry) => entry.quantity <= decimalZero,
          cashDividend: (entry) => entry.quantity <= decimalZero,
          assetTransfer: (entry) => entry.quantity <= decimalZero,
        )) {
      errors['quantity'] = 'Quantity must be greater than zero.';
    }

    payload.map(
      buy: (entry) {
        if (entry.price <= decimalZero) {
          errors['price'] = 'Price must be greater than zero.';
        }
      },
      sell: (entry) {
        if (entry.price <= decimalZero) {
          errors['price'] = 'Price must be greater than zero.';
        }
      },
      capitalIncreaseBonus: (entry) {
        if (entry.bonusRatio <= decimalZero) {
          errors['bonus_ratio'] = 'Bonus ratio must be greater than zero.';
        }
      },
      stockSplit: (entry) {
        if (entry.splitFrom <= 0) {
          errors['split_from'] = 'Split-from must be a positive integer.';
        }
        if (entry.splitTo <= entry.splitFrom) {
          errors['split_to'] = 'Split-to must be greater than split-from.';
        }
      },
      preEmptiveRights: (entry) {
        if (entry.rightsRatio <= decimalZero) {
          errors['rights_ratio'] = 'Rights ratio must be greater than zero.';
        }
        if (entry.subscriptionPrice <= decimalZero) {
          errors['subscription_price'] =
              'Subscription price must be greater than zero.';
        }
      },
      cashDividend: (entry) {
        if (entry.dps <= decimalZero) {
          errors['dps'] = 'DPS amount must be greater than zero.';
        }
      },
      assetTransfer: (entry) {
        if (entry.targetSymbol.trim().isEmpty) {
          errors['target_symbol'] = 'Target symbol is required.';
        }
      },
    );

    return errors;
  }

  String _buildIdempotencyKey(ManualEntryPayload payload) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '${payload.transactionType.apiValue}-${payload.hashCode}-$timestamp';
  }

  ManualEntryPayload _convertPayloadType(
    ManualEntryPayload current,
    ManualTransactionType type,
  ) {
    final portfolioId = current.map(
      buy: (entry) => entry.portfolioId,
      sell: (entry) => entry.portfolioId,
      capitalIncreaseBonus: (entry) => entry.portfolioId,
      stockSplit: (entry) => entry.portfolioId,
      preEmptiveRights: (entry) => entry.portfolioId,
      cashDividend: (entry) => entry.portfolioId,
      assetTransfer: (entry) => entry.portfolioId,
    );
    final symbol = current.map(
      buy: (entry) => entry.symbol,
      sell: (entry) => entry.symbol,
      capitalIncreaseBonus: (entry) => entry.symbol,
      stockSplit: (entry) => entry.symbol,
      preEmptiveRights: (entry) => entry.symbol,
      cashDividend: (entry) => entry.symbol,
      assetTransfer: (entry) => entry.symbol,
    );
    final tradeDate = current.map(
      buy: (entry) => entry.tradeDate,
      sell: (entry) => entry.tradeDate,
      capitalIncreaseBonus: (entry) => entry.tradeDate,
      stockSplit: (entry) => entry.tradeDate,
      preEmptiveRights: (entry) => entry.tradeDate,
      cashDividend: (entry) => entry.tradeDate,
      assetTransfer: (entry) => entry.tradeDate,
    );
    final notes = current.map(
      buy: (entry) => entry.notes,
      sell: (entry) => entry.notes,
      capitalIncreaseBonus: (entry) => entry.notes,
      stockSplit: (entry) => entry.notes,
      preEmptiveRights: (entry) => entry.notes,
      cashDividend: (entry) => entry.notes,
      assetTransfer: (entry) => entry.notes,
    );
    final quantity = current.map(
      buy: (entry) => entry.quantity,
      sell: (entry) => entry.quantity,
      capitalIncreaseBonus: (entry) => entry.quantity,
      stockSplit: (entry) => entry.quantity,
      preEmptiveRights: (entry) => entry.quantity,
      cashDividend: (entry) => entry.quantity,
      assetTransfer: (entry) => entry.quantity,
    );

    switch (type) {
      case ManualTransactionType.buy:
        return ManualEntryPayload.buy(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          price: decimalZero,
          commission: decimalZero,
          notes: notes,
        );
      case ManualTransactionType.sell:
        return ManualEntryPayload.sell(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          price: decimalZero,
          commission: decimalZero,
          notes: notes,
        );
      case ManualTransactionType.capitalIncreaseBonus:
        return ManualEntryPayload.capitalIncreaseBonus(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          bonusRatio: decimalZero,
          notes: notes,
        );
      case ManualTransactionType.stockSplit:
        return ManualEntryPayload.stockSplit(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          splitFrom: 1,
          splitTo: 2,
          notes: notes,
        );
      case ManualTransactionType.preEmptiveRights:
        return ManualEntryPayload.preEmptiveRights(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          rightsRatio: decimalZero,
          subscriptionPrice: decimalZero,
          commission: decimalZero,
          notes: notes,
        );
      case ManualTransactionType.cashDividend:
        return ManualEntryPayload.cashDividend(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          dps: decimalZero,
          notes: notes,
        );
      case ManualTransactionType.assetTransfer:
        return ManualEntryPayload.assetTransfer(
          portfolioId: portfolioId,
          symbol: symbol,
          tradeDate: tradeDate,
          quantity: quantity,
          targetSymbol: '',
          notes: notes,
        );
    }
  }

  ManualEntryPayload _initialPayload() {
    return ManualEntryPayload.buy(
      portfolioId: '',
      symbol: '',
      tradeDate: DateTime.now(),
      quantity: decimalZero,
      price: decimalZero,
      commission: decimalZero,
    );
  }
}
