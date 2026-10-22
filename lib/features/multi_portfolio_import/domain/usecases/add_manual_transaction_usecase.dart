import '../repositories/multi_portfolio_import_repository.dart';

class AddManualTransactionUseCase {
  const AddManualTransactionUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<void> call({
    required String portfolioId,
    required String symbol,
    required String transactionType,
    required String quantity,
    required String price,
    String? notes,
  }) {
    return _repository.addManualTransaction(
      portfolioId: portfolioId,
      symbol: symbol,
      transactionType: transactionType,
      quantity: quantity,
      price: price,
      notes: notes,
    );
  }
}
