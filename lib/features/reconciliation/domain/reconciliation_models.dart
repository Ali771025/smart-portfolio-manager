import 'package:decimal/decimal.dart';

class ReconciliationPortfolioRef {
  const ReconciliationPortfolioRef({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class ReconciliationSellSelection {
  const ReconciliationSellSelection({
    required this.transactionId,
    required this.portfolioId,
    required this.portfolioLabel,
    required this.assetId,
    required this.symbol,
    required this.executedAt,
    required this.quantity,
    required this.pricePerUnit,
  });

  final String transactionId;
  final String portfolioId;
  final String portfolioLabel;
  final String assetId;
  final String symbol;
  final DateTime executedAt;
  final Decimal quantity;
  final Decimal pricePerUnit;
}

class ReconciliationBuyCandidate {
  const ReconciliationBuyCandidate({
    required this.transactionId,
    required this.portfolioId,
    required this.portfolioLabel,
    required this.executedAt,
    required this.quantity,
    required this.availableQuantity,
    required this.pricePerUnit,
  });

  final String transactionId;
  final String portfolioId;
  final String portfolioLabel;
  final DateTime executedAt;
  final Decimal quantity;
  final Decimal availableQuantity;
  final Decimal pricePerUnit;

  int dateDistanceDays(DateTime sellDate) =>
      sellDate.difference(executedAt).inDays.abs();
}

class ReconciliationPreview {
  const ReconciliationPreview({
    required this.reconciliationId,
    required this.symbol,
    required this.matchedQuantity,
    required this.remainingSellQuantity,
    required this.estimatedRealizedPnl,
    required this.allocations,
    required this.holdingsImpacts,
  });

  final String reconciliationId;
  final String symbol;
  final Decimal matchedQuantity;
  final Decimal remainingSellQuantity;
  final Decimal estimatedRealizedPnl;
  final List<ReconciliationPreviewAllocation> allocations;
  final List<ReconciliationHoldingsImpact> holdingsImpacts;

  factory ReconciliationPreview.fromJson(Map<String, dynamic> json) {
    final rawAllocations = json['allocations'];
    final rawImpacts = json['estimated_holdings_impact'];
    return ReconciliationPreview(
      reconciliationId: json['reconciliation_id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      matchedQuantity: _decimal(json['matched_quantity']),
      remainingSellQuantity: _decimal(json['remaining_sell_quantity']),
      estimatedRealizedPnl: _decimal(json['estimated_realized_pnl_impact']),
      allocations: rawAllocations is List
          ? rawAllocations
              .whereType<Map>()
              .map(
                (item) => ReconciliationPreviewAllocation.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ReconciliationPreviewAllocation>[],
      holdingsImpacts: rawImpacts is List
          ? rawImpacts
              .whereType<Map>()
              .map(
                (item) => ReconciliationHoldingsImpact.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ReconciliationHoldingsImpact>[],
    );
  }
}

class ReconciliationPreviewAllocation {
  const ReconciliationPreviewAllocation({
    required this.buyTransactionId,
    required this.portfolioLabel,
    required this.matchedQuantity,
    required this.remainingBuyQuantity,
    required this.buyCost,
    required this.sellProceeds,
    required this.realizedPnl,
  });

  final String buyTransactionId;
  final String portfolioLabel;
  final Decimal matchedQuantity;
  final Decimal remainingBuyQuantity;
  final Decimal buyCost;
  final Decimal sellProceeds;
  final Decimal realizedPnl;

  factory ReconciliationPreviewAllocation.fromJson(
    Map<String, dynamic> json,
  ) {
    final buy = json['buy_transaction'];
    final buyMap =
        buy is Map ? Map<String, dynamic>.from(buy) : const <String, dynamic>{};
    return ReconciliationPreviewAllocation(
      buyTransactionId: buyMap['transaction_id']?.toString() ?? '',
      portfolioLabel: buyMap['portfolio_label']?.toString() ?? '',
      matchedQuantity: _decimal(json['matched_quantity']),
      remainingBuyQuantity: _decimal(buyMap['remaining_quantity']),
      buyCost: _decimal(json['estimated_or_actual_buy_cost']),
      sellProceeds: _decimal(json['estimated_or_actual_sell_proceeds']),
      realizedPnl: _decimal(
        json['estimated_or_actual_realized_pnl'],
      ),
    );
  }
}

class ReconciliationHoldingsImpact {
  const ReconciliationHoldingsImpact({
    required this.portfolioLabel,
    required this.role,
    required this.quantityDelta,
    required this.reconciledSellQuantity,
  });

  final String portfolioLabel;
  final String role;
  final Decimal quantityDelta;
  final Decimal reconciledSellQuantity;

  factory ReconciliationHoldingsImpact.fromJson(Map<String, dynamic> json) {
    return ReconciliationHoldingsImpact(
      portfolioLabel: json['portfolio_label']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      quantityDelta: _decimal(json['quantity_delta']),
      reconciledSellQuantity: _decimal(json['reconciled_sell_quantity']),
    );
  }
}

Decimal reconciliationDecimal(Object? value) => _decimal(value);

Decimal _decimal(Object? value) {
  if (value is Decimal) {
    return value;
  }
  final source = value?.toString().trim() ?? '';
  if (source.isEmpty) {
    return Decimal.zero;
  }
  return Decimal.tryParse(source) ?? Decimal.zero;
}
