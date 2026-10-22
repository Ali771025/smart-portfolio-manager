import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset_ledger_models.dart';

part 'asset_notifier_state.freezed.dart';

@freezed
abstract class LedgerPaginationState with _$LedgerPaginationState {
  const factory LedgerPaginationState({
    @Default(<LedgerEntryDto>[]) List<LedgerEntryDto> items,
    @Default(0) int total,
    @Default(50) int limit,
    @Default(0) int offset,
    @Default(false) bool isLoadingMore,
  }) = _LedgerPaginationState;

  const LedgerPaginationState._();

  bool get hasMore => items.length < total;
  bool get isEmpty => items.isEmpty;
}

@freezed
abstract class TransactionFormState with _$TransactionFormState {
  const factory TransactionFormState({
    required String portfolioId,
    required String assetId,
    @Default('BUY') String transactionType,
    @Default('0') String quantityInput,
    @Default('0') String priceInput,
    @Default('0') String feesInput,
    @Default('0') String dividendPerUnitInput,
    @Default('0') String bonusRatioInput,
    @Default('1') String splitFromInput,
    @Default('2') String splitToInput,
    @Default('0') String rightsRatioInput,
    @Default('0') String subscriptionPriceInput,
    @Default('') String notes,
    @Default(false) bool submitting,
    String? errorMessage,
    @Default(false) bool submitSuccess,
  }) = _TransactionFormState;

  const TransactionFormState._();

  Decimal get quantity => Decimal.tryParse(quantityInput.trim()) ?? Decimal.zero;
  Decimal get price => Decimal.tryParse(priceInput.trim()) ?? Decimal.zero;
  Decimal get fees => Decimal.tryParse(feesInput.trim()) ?? Decimal.zero;
  Decimal get dividendPerUnit => Decimal.tryParse(dividendPerUnitInput.trim()) ?? Decimal.zero;
  Decimal get bonusRatio => Decimal.tryParse(bonusRatioInput.trim()) ?? Decimal.zero;
  int get splitFrom => int.tryParse(splitFromInput.trim()) ?? 1;
  int get splitTo => int.tryParse(splitToInput.trim()) ?? 2;
  Decimal get rightsRatio => Decimal.tryParse(rightsRatioInput.trim()) ?? Decimal.zero;
  Decimal get subscriptionPrice => Decimal.tryParse(subscriptionPriceInput.trim()) ?? Decimal.zero;
}
