import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class CreatePortfolioUseCase {
  const CreatePortfolioUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<PortfolioOption> call({
    required String name,
    required BrokerType manager,
  }) {
    return _repository.createPortfolio(name: name, manager: manager);
  }
}
