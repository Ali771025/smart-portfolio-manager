import '../entities/import_entities.dart';
import '../repositories/multi_portfolio_import_repository.dart';

class BuildImportPreviewUseCase {
  const BuildImportPreviewUseCase(this._repository);

  final MultiPortfolioImportRepository _repository;

  Future<ImportPreviewEntity> call({
    required String portfolioId,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) {
    return _repository.buildPreview(
      portfolioId: portfolioId,
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
    );
  }
}
