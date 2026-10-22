import '../entities/import_entities.dart';

abstract class MultiPortfolioImportRepository {
  Future<List<PortfolioOption>> listPortfolios();

  Future<PortfolioOption> createPortfolio({
    required String name,
    required BrokerType manager,
  });

  Future<ImportPreviewEntity> buildPreview({
    required String portfolioId,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  });

  Future<ImportResultEntity> confirmImport({
    required String previewId,
  });

  Future<void> addManualTransaction({
    required String portfolioId,
    required String symbol,
    required String transactionType,
    required String quantity,
    required String price,
    String? notes,
  });

  Future<void> assignManager({
    required String portfolioId,
    required BrokerType manager,
  });

  Future<PortfolioPerformanceEntity> getPortfolioPerformance({
    required String portfolioId,
  });

  Future<AggregatePerformanceEntity> getAggregatePerformance();

  Future<List<ManagerComparisonEntity>> compareManagers();
}
