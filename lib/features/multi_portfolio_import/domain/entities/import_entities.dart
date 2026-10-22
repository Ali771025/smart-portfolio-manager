import 'package:decimal/decimal.dart';

enum BrokerType { agah, mofid, boursiran, unknown }

enum ImportType { ledgerTransactions, holdingsSnapshot }

enum ImportRowStatus { valid, invalid, duplicate }

class PortfolioOption {
  const PortfolioOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class ImportPreviewRowEntity {
  const ImportPreviewRowEntity({
    required this.rowNo,
    required this.status,
    required this.raw,
    required this.normalized,
    required this.messages,
  });

  final int rowNo;
  final ImportRowStatus status;
  final Map<String, dynamic> raw;
  final Map<String, dynamic> normalized;
  final List<String> messages;
}

class ImportPreviewEntity {
  const ImportPreviewEntity({
    required this.previewId,
    required this.portfolioId,
    required this.detectedBroker,
    required this.detectedImportType,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.warnings,
    required this.rows,
  });

  final String previewId;
  final String portfolioId;
  final BrokerType detectedBroker;
  final ImportType detectedImportType;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  final List<String> warnings;
  final List<ImportPreviewRowEntity> rows;
}

class ImportResultEntity {
  const ImportResultEntity({
    required this.jobId,
    required this.portfolioId,
    required this.broker,
    required this.importType,
    required this.status,
    required this.importedRows,
    required this.duplicateRows,
    required this.invalidRows,
    required this.errors,
  });

  final String? jobId;
  final String portfolioId;
  final BrokerType broker;
  final ImportType importType;
  final String status;
  final int importedRows;
  final int duplicateRows;
  final int invalidRows;
  final List<String> errors;
}

class PortfolioPerformanceEntity {
  const PortfolioPerformanceEntity({
    required this.portfolioId,
    required this.portfolioName,
    required this.manager,
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnl,
    required this.roiPercent,
  });

  final String portfolioId;
  final String portfolioName;
  final BrokerType manager;
  final Decimal totalInvested;
  final Decimal totalCurrentValue;
  final Decimal totalPnl;
  final Decimal roiPercent;
}

class AggregatePerformanceEntity {
  const AggregatePerformanceEntity({
    required this.portfolioCount,
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnl,
    required this.roiPercent,
  });

  final int portfolioCount;
  final Decimal totalInvested;
  final Decimal totalCurrentValue;
  final Decimal totalPnl;
  final Decimal roiPercent;
}

class ManagerComparisonEntity {
  const ManagerComparisonEntity({
    required this.manager,
    required this.portfolios,
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnl,
    required this.roiPercent,
  });

  final BrokerType manager;
  final int portfolios;
  final Decimal totalInvested;
  final Decimal totalCurrentValue;
  final Decimal totalPnl;
  final Decimal roiPercent;
}
