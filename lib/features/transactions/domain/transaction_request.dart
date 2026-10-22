class TransactionRequest {
  const TransactionRequest({
    required this.assetId,
    required this.transactionType,
    required this.quantity,
    required this.pricePerUnit,
    required this.fees,
    required this.executedAtIso,
    this.notes,
  });

  final String assetId;
  final String transactionType;
  final double quantity;
  final double pricePerUnit;
  final double fees;
  final String executedAtIso;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'asset_id': assetId,
      'transaction_type': transactionType,
      'quantity': quantity.toStringAsFixed(4),
      'price_per_unit': pricePerUnit.toStringAsFixed(4),
      'fees': fees.toStringAsFixed(4),
      'executed_at': executedAtIso,
      'notes': notes,
    };
  }
}
