import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class AssignPortfolioManagerUseCase {
  const AssignPortfolioManagerUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<void> call({
    required String portfolioId,
    required BrokerType manager,
  }) {
    return _repository.assignManager(
      portfolioId: portfolioId,
      manager: manager,
    );
  }
}
