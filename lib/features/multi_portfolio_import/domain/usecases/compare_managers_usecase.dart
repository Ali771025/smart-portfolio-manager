import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class CompareManagersUseCase {
  const CompareManagersUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<List<ManagerComparisonEntity>> call() {
    return _repository.compareManagers();
  }
}
