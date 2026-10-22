import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class ConfirmImportUseCase {
  const ConfirmImportUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<ImportResultEntity> call({
    required String previewId,
  }) {
    return _repository.confirmImport(previewId: previewId);
  }
}
