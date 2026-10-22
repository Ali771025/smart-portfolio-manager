import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class GetPortfolioPerformanceUseCase {
  const GetPortfolioPerformanceUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<PortfolioPerformanceEntity> call({
    required String portfolioId,
  }) {
    return _repository.getPortfolioPerformance(portfolioId: portfolioId);
  }
}
