import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../analytics/domain/models/analytics_models.dart';
import '../../../analytics/presentation/providers/analytics_controller.dart';
import '../../../analytics/presentation/providers/benchmark_dashboard_controller.dart';
import '../../../analytics/presentation/providers/benchmark_payload_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../assets/presentation/providers/asset_ledger_notifiers.dart';
import '../../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../../portfolio/presentation/providers/portfolio_summary_provider.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../data/multi_portfolio_import_repository_impl.dart';
import '../../domain/entities/import_entities.dart';
import '../../domain/repositories/multi_portfolio_import_repository.dart';
import '../../domain/usecases/add_manual_transaction_usecase.dart';
import '../../domain/usecases/build_import_preview_usecase.dart';
import '../../domain/usecases/compare_managers_usecase.dart';
import '../../domain/usecases/confirm_import_usecase.dart';
import '../../domain/usecases/create_portfolio_usecase.dart';
import '../../domain/usecases/get_aggregate_performance_usecase.dart';
import '../../domain/usecases/get_portfolio_performance_usecase.dart';
import '../../domain/usecases/list_portfolios_usecase.dart';
import '../state/import_flow_state.dart';
import '../validation/destination_portfolio_validator.dart';

final destinationPortfolioValidatorProvider = Provider<DestinationPortfolioValidator>((ref) {
  return const DestinationPortfolioValidator();
});

final listPortfoliosUseCaseProvider = Provider<ListPortfoliosUseCase>((ref) {
  return ListPortfoliosUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final createPortfolioUseCaseProvider = Provider<CreatePortfolioUseCase>((ref) {
  return CreatePortfolioUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final buildPreviewUseCaseProvider = Provider<BuildImportPreviewUseCase>((ref) {
  return BuildImportPreviewUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final confirmImportUseCaseProvider = Provider<ConfirmImportUseCase>((ref) {
  return ConfirmImportUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final addManualTransactionUseCaseProvider = Provider<AddManualTransactionUseCase>((ref) {
  return AddManualTransactionUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final portfolioPerformanceUseCaseProvider = Provider<GetPortfolioPerformanceUseCase>((ref) {
  return GetPortfolioPerformanceUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final aggregatePerformanceUseCaseProvider = Provider<GetAggregatePerformanceUseCase>((ref) {
  return GetAggregatePerformanceUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final compareManagersUseCaseProvider = Provider<CompareManagersUseCase>((ref) {
  return CompareManagersUseCase(ref.watch(multiPortfolioImportRepositoryProvider));
});

final importFlowControllerProvider = NotifierProvider<ImportFlowController, ImportFlowState>(
  ImportFlowController.new,
);

class ImportFlowController extends Notifier<ImportFlowState> {
  MultiPortfolioImportRepository get _repository => ref.read(multiPortfolioImportRepositoryProvider);
  DestinationPortfolioValidator get _validator => ref.read(destinationPortfolioValidatorProvider);
  ListPortfoliosUseCase get _listPortfoliosUseCase => ref.read(listPortfoliosUseCaseProvider);
  CreatePortfolioUseCase get _createPortfolioUseCase => ref.read(createPortfolioUseCaseProvider);
  BuildImportPreviewUseCase get _buildImportPreviewUseCase => ref.read(buildPreviewUseCaseProvider);
  ConfirmImportUseCase get _confirmImportUseCase => ref.read(confirmImportUseCaseProvider);
  AddManualTransactionUseCase get _addManualTransactionUseCase => ref.read(addManualTransactionUseCaseProvider);
  GetPortfolioPerformanceUseCase get _getPortfolioPerformanceUseCase => ref.read(portfolioPerformanceUseCaseProvider);
  GetAggregatePerformanceUseCase get _getAggregatePerformanceUseCase => ref.read(aggregatePerformanceUseCaseProvider);
  CompareManagersUseCase get _compareManagersUseCase => ref.read(compareManagersUseCaseProvider);

  @override
  ImportFlowState build() {
    unawaited(loadPortfolios());
    return const ImportFlowState();
  }

  Future<void> loadPortfolios() async {
    state = state.copyWith(isLoading: true, clearGlobalError: true);
    try {
      final portfolios = await _listPortfoliosUseCase();
      String? resolvedId = state.selectedPortfolioId;
      String? resolvedName = state.selectedPortfolioName;

      final selectedStillExists = resolvedId != null && portfolios.any((item) => item.id == resolvedId);
      if (!selectedStillExists) {
        resolvedId = null;
        resolvedName = null;
      } else {
        resolvedName = portfolios.firstWhere((item) => item.id == resolvedId).name;
      }

      state = state.copyWith(
        portfolios: portfolios,
        selectedPortfolioId: resolvedId,
        selectedPortfolioName: resolvedName,
        isLoading: false,
        clearGlobalError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalErrorMessage: error.toString(),
      );
    }
  }

  void setSelectionMode(DestinationSelectionMode mode) {
    state = state.copyWith(
      selectionMode: mode,
      clearDestinationValidationMessage: true,
      clearPortfolioCreationError: true,
      clearGlobalError: true,
    );
  }

  void selectExistingPortfolio(String portfolioId) {
    final found = state.portfolios.where((item) => item.id == portfolioId).toList();
    if (found.isEmpty) {
      return;
    }
    state = state.copyWith(
      selectedPortfolioId: found.first.id,
      selectedPortfolioName: found.first.name,
      clearPreview: true,
      clearResult: true,
      clearDestinationValidationMessage: true,
      clearGlobalError: true,
    );
  }

  void updateNewPortfolioName(String value) {
    state = state.copyWith(
      newPortfolioName: value,
      clearPortfolioCreationError: true,
      clearDestinationValidationMessage: true,
      clearGlobalError: true,
    );
  }

  void updateNewPortfolioBrokerType(BrokerType value) {
    state = state.copyWith(
      newPortfolioBrokerType: value,
      clearPortfolioCreationError: true,
      clearGlobalError: true,
    );
  }

  void updateNewPortfolioManagerName(String value) {
    state = state.copyWith(
      newPortfolioManagerName: value,
      clearPortfolioCreationError: true,
      clearGlobalError: true,
    );
  }

  Future<void> createPortfolioIfNeeded() async {
    if (state.selectionMode != DestinationSelectionMode.createNew) {
      return;
    }
    final validation = _validator.validateForCreateNew(state);
    if (!validation.isValid) {
      state = state.copyWith(
        destinationValidationMessage: validation.message,
      );
      return;
    }

    state = state.copyWith(
      isCreatingPortfolio: true,
      clearPortfolioCreationError: true,
      clearDestinationValidationMessage: true,
      clearGlobalError: true,
    );
    try {
      final created = await _createPortfolioUseCase(
        name: state.newPortfolioName.trim(),
        manager: state.newPortfolioBrokerType,
      );
      final refreshed = await _repository.listPortfolios();
      state = state.copyWith(
        portfolios: refreshed,
        selectedPortfolioId: created.id,
        selectedPortfolioName: created.name,
        isCreatingPortfolio: false,
        selectionMode: DestinationSelectionMode.existing,
        newPortfolioName: '',
        clearDestinationValidationMessage: true,
        clearPortfolioCreationError: true,
        clearGlobalError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isCreatingPortfolio: false,
        portfolioCreationError: error.toString(),
      );
    }
  }

  Future<void> pickExcelFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['xlsx', 'xlsm', 'xls'],
      withData: kIsWeb,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    state = state.copyWith(
      selectedFileName: file.name,
      selectedFilePath: file.path,
      selectedFileBytes: file.bytes,
      clearPreview: true,
      clearResult: true,
      clearDestinationValidationMessage: true,
      clearGlobalError: true,
    );
  }

  Future<void> buildPreview() async {
    final validation = _validator.validateForPreview(state);
    if (!validation.isValid) {
      state = state.copyWith(destinationValidationMessage: validation.message);
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearGlobalError: true,
      clearResult: true,
      clearDestinationValidationMessage: true,
    );
    try {
      final preview = await _buildImportPreviewUseCase(
        portfolioId: state.selectedPortfolioId!,
        fileName: state.selectedFileName!,
        filePath: state.selectedFilePath,
        fileBytes: state.selectedFileBytes,
      );
      state = state.copyWith(
        preview: preview,
        isLoading: false,
        clearGlobalError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalErrorMessage: error.toString(),
      );
    }
  }

  Future<void> confirmImport() async {
    if (!state.canConfirmImport) {
      state = state.copyWith(
        destinationValidationMessage: 'ابتدا پیش‌نمایش موفق را دریافت کنید.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearGlobalError: true,
      clearDestinationValidationMessage: true,
    );
    try {
      final result = await _confirmImportUseCase(previewId: state.preview!.previewId);
      final selectionBefore = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
      final shouldSwitchSelection =
          state.selectionMode == DestinationSelectionMode.createNew ||
          selectionBefore.isEmpty;
      final selectionAfter =
          shouldSwitchSelection ? result.portfolioId.trim() : selectionBefore;
      final traceId = ImportAnalyticsRefreshTrace.startImportSuccess(
        importFlowName: 'ImportFlowController',
        targetPortfolioId: result.portfolioId.trim(),
        selectedPortfolioIdBefore: selectionBefore,
        selectedPortfolioIdAfter: selectionAfter,
        importedRows: result.importedRows,
        importBatchId: result.jobId,
      );
      state = state.copyWith(
        result: result,
        isLoading: false,
        clearGlobalError: true,
      );
      _invalidatePostImportState(
        result.portfolioId,
        traceId: traceId,
      );
      await refreshPerformance();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalErrorMessage: error.toString(),
      );
    }
  }

  Future<void> addManualTransaction({
    required String symbol,
    required String transactionType,
    required String quantity,
    required String price,
    String? notes,
  }) async {
    final portfolioId = state.selectedPortfolioId;
    if (portfolioId == null || portfolioId.trim().isEmpty) {
      state = state.copyWith(destinationValidationMessage: 'لطفاً یک پرتفوی مقصد انتخاب کنید.');
      return;
    }

    state = state.copyWith(isLoading: true, clearGlobalError: true);
    try {
      await _addManualTransactionUseCase(
        portfolioId: portfolioId,
        symbol: symbol,
        transactionType: transactionType,
        quantity: quantity,
        price: price,
        notes: notes,
      );
      final selectionBefore = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
      final selectionAfter =
          selectionBefore.isEmpty ? portfolioId.trim() : selectionBefore;
      final traceId = ImportAnalyticsRefreshTrace.startImportSuccess(
        importFlowName: 'ImportFlowController.manualTransaction',
        targetPortfolioId: portfolioId.trim(),
        selectedPortfolioIdBefore: selectionBefore,
        selectedPortfolioIdAfter: selectionAfter,
        importedRows: 1,
      );
      _invalidatePostImportState(
        portfolioId,
        traceId: traceId,
      );
      state = state.copyWith(isLoading: false, clearGlobalError: true);
      await refreshPerformance();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalErrorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshPerformance() async {
    final portfolioId = state.selectedPortfolioId;
    if (portfolioId == null || portfolioId.trim().isEmpty) {
      return;
    }
    try {
      final perPortfolio = await _getPortfolioPerformanceUseCase(portfolioId: portfolioId);
      final aggregate = await _getAggregatePerformanceUseCase();
      final managers = await _compareManagersUseCase();
      state = state.copyWith(
        portfolioPerformance: perPortfolio,
        aggregatePerformance: aggregate,
        managerComparison: managers,
        clearGlobalError: true,
      );
    } catch (error) {
      state = state.copyWith(globalErrorMessage: error.toString());
    }
  }

  void _invalidatePostImportState(
    String portfolioId, {
    String? traceId,
  }) {
    final normalizedPortfolioId = portfolioId.trim();
    final currentSelection = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
    final shouldSwitchSelection =
        state.selectionMode == DestinationSelectionMode.createNew ||
        currentSelection.isEmpty;
    if (kDebugMode) {
      debugPrint(
        '[ImportFlowController] post-import invalidation '
        'target=$normalizedPortfolioId active=$currentSelection '
        'shouldSwitchSelection=$shouldSwitchSelection',
      );
    }
    ref
      ..invalidate(dashboardControllerProvider)
      ..invalidate(portfolioManagerControllerProvider)
      ..invalidate(portfolioListProvider);
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'dashboardControllerProvider',
      portfolioId: currentSelection.isNotEmpty
          ? currentSelection
          : normalizedPortfolioId,
    );

    if (normalizedPortfolioId.isEmpty) {
      return;
    }

    if (shouldSwitchSelection) {
      ref.read(selectedPortfolioIdProvider.notifier).state = normalizedPortfolioId;
    }
    _invalidateAnalyticsBundle(
      portfolioId: normalizedPortfolioId,
      source: 'import-target',
      traceId: traceId,
    );

    if (!shouldSwitchSelection &&
        currentSelection.isNotEmpty &&
        currentSelection != normalizedPortfolioId) {
      _invalidateAnalyticsBundle(
        portfolioId: currentSelection,
        source: 'active-selection',
        traceId: traceId,
      );
    }
    ImportAnalyticsRefreshTrace.emitFinalVerdict(
      traceId: traceId,
      portfolioId: normalizedPortfolioId,
      trigger: 'import_flow_controller_invalidation_complete',
    );
  }

  void _invalidateAnalyticsBundle({
    required String portfolioId,
    required String source,
    String? traceId,
  }) {
    ref
      ..invalidate(portfolioSummaryProvider(portfolioId))
      ..invalidate(portfolioPositionsProvider(portfolioId))
      ..invalidate(analyticsControllerProvider(portfolioId))
      ..invalidate(benchmarkDashboardControllerProvider(portfolioId))
      ..invalidate(benchmarkVisibleSeriesProvider(portfolioId));
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'portfolioSummaryProvider',
      portfolioId: portfolioId,
    );
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'portfolioPositionsProvider',
      portfolioId: portfolioId,
    );
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'analyticsControllerProvider',
      portfolioId: portfolioId,
    );
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'benchmarkDashboardControllerProvider',
      portfolioId: portfolioId,
    );
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'benchmarkVisibleSeriesProvider',
      portfolioId: portfolioId,
    );

    for (final timeframe in AnalyticsTimeframe.values) {
      if (kDebugMode) {
        debugPrint(
          '[ImportFlowController] invalidated '
          'analyticsControllerProvider($portfolioId), '
          'benchmarkDashboardControllerProvider($portfolioId), '
          'benchmarkVisibleSeriesProvider($portfolioId), '
          'benchmarkMsgPackPayloadProvider($portfolioId,${timeframe.name}) '
          'source=$source',
        );
      }
      ref.invalidate(
        benchmarkMsgPackPayloadProvider(
          (portfolioId: portfolioId, timeframe: timeframe),
        ),
      );
      ImportAnalyticsRefreshTrace.logProviderInvalidation(
        traceId: traceId,
        providerName: 'benchmarkMsgPackPayloadProvider',
        portfolioId: portfolioId,
        timeframe: timeframe.name,
      );
    }
  }

}
