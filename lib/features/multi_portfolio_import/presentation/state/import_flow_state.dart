import '../../domain/entities/import_entities.dart';

enum DestinationSelectionMode {
  existing,
  createNew,
}

class ImportFlowState {
  const ImportFlowState({
    this.portfolios = const <PortfolioOption>[],
    this.selectionMode = DestinationSelectionMode.existing,
    this.selectedPortfolioId,
    this.selectedPortfolioName,
    this.newPortfolioName = '',
    this.newPortfolioBrokerType = BrokerType.unknown,
    this.newPortfolioManagerName = '',
    this.isCreatingPortfolio = false,
    this.portfolioCreationError,
    this.destinationValidationMessage,
    this.selectedFileName,
    this.selectedFilePath,
    this.selectedFileBytes,
    this.preview,
    this.result,
    this.portfolioPerformance,
    this.aggregatePerformance,
    this.managerComparison = const <ManagerComparisonEntity>[],
    this.isLoading = false,
    this.globalErrorMessage,
  });

  final List<PortfolioOption> portfolios;

  final DestinationSelectionMode selectionMode;
  final String? selectedPortfolioId;
  final String? selectedPortfolioName;
  final String newPortfolioName;
  final BrokerType newPortfolioBrokerType;
  final String newPortfolioManagerName;
  final bool isCreatingPortfolio;
  final String? portfolioCreationError;
  final String? destinationValidationMessage;

  final String? selectedFileName;
  final String? selectedFilePath;
  final List<int>? selectedFileBytes;

  final ImportPreviewEntity? preview;
  final ImportResultEntity? result;
  final PortfolioPerformanceEntity? portfolioPerformance;
  final AggregatePerformanceEntity? aggregatePerformance;
  final List<ManagerComparisonEntity> managerComparison;

  final bool isLoading;
  final String? globalErrorMessage;

  bool get hasSelectedFile =>
      (selectedFileName ?? '').trim().isNotEmpty &&
      (selectedFilePath != null || (selectedFileBytes?.isNotEmpty ?? false));

  bool get hasResolvedDestination =>
      (selectedPortfolioId ?? '').trim().isNotEmpty &&
      (selectedPortfolioName ?? '').trim().isNotEmpty;

  bool get isNewPortfolioNameValid {
    final name = newPortfolioName.trim();
    return name.isNotEmpty;
  }

  bool get canCreatePortfolio =>
      selectionMode == DestinationSelectionMode.createNew &&
      isNewPortfolioNameValid &&
      !isCreatingPortfolio &&
      !isLoading;

  bool get canPreviewImport =>
      !isLoading &&
      !isCreatingPortfolio &&
      hasSelectedFile &&
      hasResolvedDestination;

  bool get canConfirmImport =>
      !isLoading &&
      !isCreatingPortfolio &&
      hasResolvedDestination &&
      preview != null;

  ImportFlowState copyWith({
    List<PortfolioOption>? portfolios,
    DestinationSelectionMode? selectionMode,
    String? selectedPortfolioId,
    String? selectedPortfolioName,
    String? newPortfolioName,
    BrokerType? newPortfolioBrokerType,
    String? newPortfolioManagerName,
    bool? isCreatingPortfolio,
    String? portfolioCreationError,
    String? destinationValidationMessage,
    String? selectedFileName,
    String? selectedFilePath,
    List<int>? selectedFileBytes,
    ImportPreviewEntity? preview,
    ImportResultEntity? result,
    PortfolioPerformanceEntity? portfolioPerformance,
    AggregatePerformanceEntity? aggregatePerformance,
    List<ManagerComparisonEntity>? managerComparison,
    bool? isLoading,
    String? globalErrorMessage,
    bool clearPreview = false,
    bool clearResult = false,
    bool clearGlobalError = false,
    bool clearPortfolioCreationError = false,
    bool clearDestinationValidationMessage = false,
  }) {
    return ImportFlowState(
      portfolios: portfolios ?? this.portfolios,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedPortfolioId: selectedPortfolioId ?? this.selectedPortfolioId,
      selectedPortfolioName: selectedPortfolioName ?? this.selectedPortfolioName,
      newPortfolioName: newPortfolioName ?? this.newPortfolioName,
      newPortfolioBrokerType: newPortfolioBrokerType ?? this.newPortfolioBrokerType,
      newPortfolioManagerName: newPortfolioManagerName ?? this.newPortfolioManagerName,
      isCreatingPortfolio: isCreatingPortfolio ?? this.isCreatingPortfolio,
      portfolioCreationError: clearPortfolioCreationError ? null : (portfolioCreationError ?? this.portfolioCreationError),
      destinationValidationMessage: clearDestinationValidationMessage
          ? null
          : (destinationValidationMessage ?? this.destinationValidationMessage),
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      selectedFileBytes: selectedFileBytes ?? this.selectedFileBytes,
      preview: clearPreview ? null : (preview ?? this.preview),
      result: clearResult ? null : (result ?? this.result),
      portfolioPerformance: portfolioPerformance ?? this.portfolioPerformance,
      aggregatePerformance: aggregatePerformance ?? this.aggregatePerformance,
      managerComparison: managerComparison ?? this.managerComparison,
      isLoading: isLoading ?? this.isLoading,
      globalErrorMessage: clearGlobalError ? null : (globalErrorMessage ?? this.globalErrorMessage),
    );
  }
}
