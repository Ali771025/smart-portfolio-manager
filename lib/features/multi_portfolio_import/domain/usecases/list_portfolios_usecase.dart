import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class ListPortfoliosUseCase {
  const ListPortfoliosUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<List<PortfolioOption>> call() {
    return _repository.listPortfolios();
  }
}
