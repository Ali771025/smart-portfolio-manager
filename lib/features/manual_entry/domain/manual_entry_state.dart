import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'decimal_utils.dart';
import 'manual_transaction_type.dart';

part 'manual_entry_state.freezed.dart';

@freezed
sealed class ManualEntryPayload with _$ManualEntryPayload {
  const ManualEntryPayload._();

  const factory ManualEntryPayload.buy({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required Decimal price,
    required Decimal commission,
    String? notes,
  }) = BuyPayload;

  const factory ManualEntryPayload.sell({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required Decimal price,
    required Decimal commission,
    String? notes,
  }) = SellPayload;

  const factory ManualEntryPayload.capitalIncreaseBonus({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required Decimal bonusRatio,
    String? notes,
  }) = CapitalIncreaseBonusPayload;

  const factory ManualEntryPayload.stockSplit({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required int splitFrom,
    required int splitTo,
    String? notes,
  }) = StockSplitPayload;

  const factory ManualEntryPayload.preEmptiveRights({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required Decimal rightsRatio,
    required Decimal subscriptionPrice,
    required Decimal commission,
    String? notes,
  }) = PreEmptiveRightsPayload;

  const factory ManualEntryPayload.cashDividend({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required Decimal dps,
    String? notes,
  }) = CashDividendPayload;

  const factory ManualEntryPayload.assetTransfer({
    required String portfolioId,
    required String symbol,
    required DateTime tradeDate,
    required Decimal quantity,
    required String targetSymbol,
    String? notes,
  }) = AssetTransferPayload;

  ManualTransactionType get transactionType => map(
        buy: (_) => ManualTransactionType.buy,
        sell: (_) => ManualTransactionType.sell,
        capitalIncreaseBonus: (_) => ManualTransactionType.capitalIncreaseBonus,
        stockSplit: (_) => ManualTransactionType.stockSplit,
        preEmptiveRights: (_) => ManualTransactionType.preEmptiveRights,
        cashDividend: (_) => ManualTransactionType.cashDividend,
        assetTransfer: (_) => ManualTransactionType.assetTransfer,
      );

  Decimal get totalValue => map(
        buy: (payload) =>
            (payload.quantity * payload.price) + payload.commission,
        sell: (payload) =>
            (payload.quantity * payload.price) - payload.commission,
        capitalIncreaseBonus: (_) => decimalZero,
        stockSplit: (_) => decimalZero,
        preEmptiveRights: (payload) =>
            (payload.quantity * payload.subscriptionPrice) + payload.commission,
        cashDividend: (payload) => payload.quantity * payload.dps,
        assetTransfer: (_) => decimalZero,
      );

  Map<String, dynamic> toApiJson() => map(
        buy: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.buy.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'price': decimalToApiString(payload.price),
          'commission': decimalToApiString(payload.commission),
          'notes': payload.notes,
        },
        sell: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.sell.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'price': decimalToApiString(payload.price),
          'commission': decimalToApiString(payload.commission),
          'notes': payload.notes,
        },
        capitalIncreaseBonus: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.capitalIncreaseBonus.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'bonus_ratio': decimalToApiString(payload.bonusRatio),
          'price': decimalToApiString(decimalZero),
          'commission': decimalToApiString(decimalZero),
          'notes': payload.notes,
        },
        stockSplit: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.stockSplit.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'split_from': payload.splitFrom,
          'split_to': payload.splitTo,
          'price': decimalToApiString(decimalZero),
          'commission': decimalToApiString(decimalZero),
          'notes': payload.notes,
        },
        preEmptiveRights: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.preEmptiveRights.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'rights_ratio': decimalToApiString(payload.rightsRatio),
          'subscription_price': decimalToApiString(payload.subscriptionPrice),
          'price': decimalToApiString(payload.subscriptionPrice),
          'commission': decimalToApiString(payload.commission),
          'notes': payload.notes,
        },
        cashDividend: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.cashDividend.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'dps': decimalToApiString(payload.dps),
          'notes': payload.notes,
        },
        assetTransfer: (payload) => <String, dynamic>{
          'portfolio_id': payload.portfolioId,
          'symbol': payload.symbol,
          'transaction_type': ManualTransactionType.assetTransfer.apiValue,
          'transaction_date': payload.tradeDate.toIso8601String().split('T').first,
          'quantity': decimalToApiString(payload.quantity),
          'target_symbol': payload.targetSymbol,
          'price': decimalToApiString(decimalZero),
          'commission': decimalToApiString(decimalZero),
          'notes': payload.notes,
        },
      );
}

@freezed
abstract class ManualEntryFormState with _$ManualEntryFormState {
  const ManualEntryFormState._();

  const factory ManualEntryFormState({
    required ManualEntryPayload payload,
    @Default(<String, String>{}) Map<String, String> fieldErrors,
    @Default(false) bool submitSuccess,
    String? globalErrorMessage,
  }) = _ManualEntryFormState;

  Decimal get liveTotal => payload.totalValue;
}
