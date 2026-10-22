import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class GetAggregatePerformanceUseCase {
  const GetAggregatePerformanceUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<AggregatePerformanceEntity> call() {
    return _repository.getAggregatePerformance();
  }
}
