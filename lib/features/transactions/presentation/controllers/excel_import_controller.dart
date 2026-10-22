import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../analytics/domain/models/analytics_models.dart';
import '../../../analytics/presentation/providers/analytics_controller.dart';
import '../../../analytics/presentation/providers/benchmark_dashboard_controller.dart';
import '../../../analytics/presentation/providers/benchmark_payload_provider.dart';
import '../../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../../portfolio/presentation/providers/portfolio_summary_provider.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../../assets/presentation/providers/asset_ledger_notifiers.dart';
import '../../data/transaction_repository.dart';
import '../../domain/models/import_exception.dart';
import '../../domain/models/import_parse_response_model.dart';
import '../../domain/models/import_report_model.dart';

part 'excel_import_controller.g.dart';

final transactionsListProvider = portfolioManagerControllerProvider;
final portfolioStatsProvider = dashboardControllerProvider;
const int _maxExcelFileSizeBytes = 10 * 1024 * 1024;

sealed class ExcelImportFlowState {
  const ExcelImportFlowState();
}

class ExcelImportIdle extends ExcelImportFlowState {
  const ExcelImportIdle();
}

class ExcelImportSelectingFile extends ExcelImportFlowState {
  const ExcelImportSelectingFile();
}

class ExcelImportUploading extends ExcelImportFlowState {
  const ExcelImportUploading({required this.progress});

  final double progress;
}

class ExcelImportProcessing extends ExcelImportFlowState {
  const ExcelImportProcessing();
}

class ExcelImportSuccess extends ExcelImportFlowState {
  const ExcelImportSuccess({
    required this.report,
    required this.previewOnly,
  });

  final ImportReportModel report;
  final bool previewOnly;
}

enum ImportSurface {
  tradeLedgerScreen,
  portfolioSnapshotScreen,
}

class ExcelImportFileTypeMismatch extends ExcelImportFlowState {
  const ExcelImportFileTypeMismatch({
    required this.report,
    required this.expectedSurface,
    required this.previewOnly,
    required this.expectedFileType,
    required this.detectedFileType,
  });

  final ImportReportModel? report;
  final ImportSurface expectedSurface;
  final bool previewOnly;
  final ImportFileType expectedFileType;
  final ImportFileType detectedFileType;
}

class ExcelImportError extends ExcelImportFlowState {
  const ExcelImportError({required this.message});

  final String message;
}

@Riverpod(keepAlive: true)
class ExcelImportController extends _$ExcelImportController {
  CancelToken? _cancelToken;
  ImportFilePayload? _lastSelectedFile;

  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  @override
  FutureOr<ExcelImportFlowState> build() {
    ref.onDispose(() {
      _cancelToken?.cancel('Import controller disposed.');
      _cancelToken = null;
    });

    return const ExcelImportIdle();
  }

  Future<void> pickAndPreviewFile({
    required ImportSurface currentSurface,
  }) async {
    if (_isBusy) {
      return;
    }

    _setFlow(const ExcelImportSelectingFile());

    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['xlsx', 'xlsm', 'xls'],
      withData: kIsWeb,
    );

    if (selection == null || selection.files.isEmpty) {
      _setFlow(const ExcelImportIdle());
      return;
    }

    final picked = selection.files.single;
    final fileValidationError = _validatePickedFile(picked);
    if (fileValidationError != null) {
      _setFlow(
        ExcelImportError(
          message: fileValidationError,
        ),
      );
      return;
    }

    final file = ImportFilePayload(
      fileName: picked.name,
      path: kIsWeb ? null : picked.path,
      bytes: picked.bytes,
    );
    _lastSelectedFile = file;

    final detected = await _detectFileTypeOrUnknown(file);
    final expectedFileType = _expectedFileTypeBySurface(currentSurface);
    if (detected != ImportFileType.unknown && detected != expectedFileType) {
      _setFlow(
        ExcelImportFileTypeMismatch(
          report: null,
          expectedSurface: currentSurface,
          previewOnly: true,
          expectedFileType: expectedFileType,
          detectedFileType: detected,
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: true,
      importTarget: null,
      endpointKind: ImportEndpointKind.trades,
      file: file,
    );
  }

  Future<void> pickAndImport({required String portfolioId}) async {
    if (_isBusy) {
      return;
    }

    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['xlsx', 'xlsm', 'xls'],
      withData: kIsWeb,
    );

    if (selection == null || selection.files.isEmpty) {
      _setFlow(const ExcelImportIdle());
      return;
    }

    final picked = selection.files.single;
    final fileValidationError = _validatePickedFile(picked);
    if (fileValidationError != null) {
      _setFlow(
        ExcelImportError(
          message: fileValidationError,
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: false,
      importTarget: ImportTargetPayload.existing(portfolioId: portfolioId),
      endpointKind: ImportEndpointKind.trades,
      file: ImportFilePayload(
        fileName: picked.name,
        path: kIsWeb ? null : picked.path,
        bytes: picked.bytes,
      ),
    );
  }

  Future<void> importLastPreviewToPortfolio({
    required String portfolioId,
  }) async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for final import.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: false,
      importTarget: ImportTargetPayload.existing(portfolioId: portfolioId),
      endpointKind: ImportEndpointKind.trades,
      file: cachedFile,
    );
  }

  Future<void> importLastPreviewWithNewPortfolio({
    required String portfolioName,
  }) async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for final import.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: false,
      importTarget: ImportTargetPayload.createNew(
        newPortfolioName: portfolioName,
      ),
      endpointKind: ImportEndpointKind.trades,
      file: cachedFile,
    );
  }

  Future<void> importLastPreviewSnapshotToPortfolio({
    required String portfolioId,
  }) async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for final import.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: false,
      importTarget: ImportTargetPayload.existing(portfolioId: portfolioId),
      endpointKind: ImportEndpointKind.portfolioSnapshot,
      file: cachedFile,
    );
  }

  Future<void> importLastPreviewSnapshotWithNewPortfolio({
    required String portfolioName,
  }) async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for final import.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: false,
      importTarget: ImportTargetPayload.createNew(
        newPortfolioName: portfolioName,
      ),
      endpointKind: ImportEndpointKind.portfolioSnapshot,
      file: cachedFile,
    );
  }

  Future<void> previewLastFileAsTrades() async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for trade preview.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: true,
      importTarget: null,
      endpointKind: ImportEndpointKind.trades,
      file: cachedFile,
    );
  }

  Future<void> previewLastFileAsSnapshot() async {
    if (_isBusy) {
      return;
    }
    final cachedFile = _lastSelectedFile;
    if (cachedFile == null) {
      _setFlow(
        const ExcelImportError(
          message: 'No preview file is available for snapshot preview.',
        ),
      );
      return;
    }

    await _startUpload(
      previewOnly: true,
      importTarget: null,
      endpointKind: ImportEndpointKind.portfolioSnapshot,
      file: cachedFile,
    );
  }

  Future<void> retryImport({
    ImportTargetPayload? importTarget,
    required bool previewOnly,
    ImportEndpointKind endpointKind = ImportEndpointKind.trades,
    required ImportFilePayload file,
  }) async {
    if (_isBusy) {
      return;
    }
    await _startUpload(
      previewOnly: previewOnly,
      importTarget: importTarget,
      endpointKind: endpointKind,
      file: file,
    );
  }

  void cancelUpload() {
    final token = _cancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('Upload cancelled by user.');
    }
  }

  void reset() {
    _setFlow(const ExcelImportIdle());
  }

  Future<void> _startUpload({
    required bool previewOnly,
    required ImportTargetPayload? importTarget,
    required ImportEndpointKind endpointKind,
    required ImportFilePayload file,
  }) async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _lastSelectedFile = file;
    _setFlow(const ExcelImportUploading(progress: 0));

    try {
      final report = await _repository.importTradesFromExcel(
        previewOnly: previewOnly,
        importTarget: importTarget,
        endpointKind: endpointKind,
        file: file,
        cancelToken: cancelToken,
        onSendProgress: (progress) {
          if (cancelToken.isCancelled) {
            return;
          }

          final normalized = progress.clamp(0, 1).toDouble();
          if (normalized >= 1) {
            _setFlow(const ExcelImportProcessing());
            return;
          }

          _setFlow(ExcelImportUploading(progress: normalized));
        },
      );

      final detectedFileType = _extractDetectedFileType(report);
      final expectedFileType = _expectedFileType(endpointKind);
      if (previewOnly &&
          detectedFileType != ImportFileType.unknown &&
          detectedFileType != expectedFileType) {
        _setFlow(
          ExcelImportFileTypeMismatch(
            report: report,
            expectedSurface: _expectedSurface(endpointKind),
            previewOnly: true,
            expectedFileType: expectedFileType,
            detectedFileType: detectedFileType,
          ),
        );
        return;
      }

      _setFlow(
        ExcelImportSuccess(
          report: report,
          previewOnly: previewOnly,
        ),
      );
      if (!previewOnly) {
        final selectedBefore = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
        final importedPortfolioId = _resolveImportedPortfolioId(
          report: report,
          importTarget: importTarget,
        );
        final shouldSwitchPortfolioContext =
            importTarget?.targetMode == ImportTargetMode.createNew;
        final selectedAfter = shouldSwitchPortfolioContext ||
                selectedBefore.isEmpty
            ? (importedPortfolioId ?? '').trim()
            : selectedBefore;
        final traceId = importedPortfolioId == null || importedPortfolioId.trim().isEmpty
            ? ''
            : ImportAnalyticsRefreshTrace.startImportSuccess(
                importFlowName: 'ExcelImportController',
                targetPortfolioId: importedPortfolioId.trim(),
                selectedPortfolioIdBefore: selectedBefore,
                selectedPortfolioIdAfter: selectedAfter,
                importedRows: report.insertedCount,
                importBatchId: report.jobId,
              );
        _invalidatePostImportState(
          portfolioId: importedPortfolioId,
          switchPortfolioContext: shouldSwitchPortfolioContext,
          traceId: traceId,
        );
      }
    } on ImportException catch (error) {
      _setFlow(ExcelImportError(message: _buildImportErrorMessage(error)));
    } catch (_) {
      _setFlow(
        const ExcelImportError(
          message: 'Unexpected import error. Please retry in a few moments.',
        ),
      );
    } finally {
      _cancelToken = null;
    }
  }

  void _setFlow(ExcelImportFlowState value) {
    state = AsyncValue.data(value);
  }

  bool _hasValidExcelExtension(String fileName) {
    final lower = fileName.trim().toLowerCase();
    return lower.endsWith('.xlsx') ||
        lower.endsWith('.xlsm') ||
        lower.endsWith('.xls');
  }

  String? _validatePickedFile(PlatformFile file) {
    if (!_hasValidExcelExtension(file.name)) {
      return 'Unsupported file type. Please select a .xlsx, .xlsm, or .xls file.';
    }
    if (file.size <= 0) {
      return 'The selected file is empty.';
    }
    if (file.size > _maxExcelFileSizeBytes) {
      return 'The selected file exceeds the 10 MB upload limit.';
    }
    return null;
  }

  bool get _isBusy {
    final current = state.value ?? const ExcelImportIdle();
    return current is ExcelImportSelectingFile ||
        current is ExcelImportUploading ||
        current is ExcelImportProcessing;
  }

  ImportSurface _expectedSurface(ImportEndpointKind endpointKind) {
    return switch (endpointKind) {
      ImportEndpointKind.trades => ImportSurface.tradeLedgerScreen,
      ImportEndpointKind.portfolioSnapshot => ImportSurface.portfolioSnapshotScreen,
    };
  }

  ImportFileType _expectedFileTypeBySurface(ImportSurface surface) {
    return switch (surface) {
      ImportSurface.tradeLedgerScreen => ImportFileType.tradeLedger,
      ImportSurface.portfolioSnapshotScreen => ImportFileType.portfolioSnapshot,
    };
  }

  ImportFileType _expectedFileType(ImportEndpointKind endpointKind) {
    return switch (endpointKind) {
      ImportEndpointKind.trades => ImportFileType.tradeLedger,
      ImportEndpointKind.portfolioSnapshot => ImportFileType.portfolioSnapshot,
    };
  }

  ImportFileType _extractDetectedFileType(ImportReportModel report) {
    final rawValue = report.analysis['file_type']?.toString().trim();
    return ImportFileType.fromBackend(rawValue);
  }

  Future<ImportFileType> _detectFileTypeOrUnknown(
    ImportFilePayload file,
  ) async {
    try {
      final parseResponse = await _repository.detectImportFileType(file: file);
      return parseResponse.fileType;
    } on ImportException catch (error) {
      // Preflight is best-effort; keep legacy preview path available.
      if (error.isCancelled) {
        return ImportFileType.unknown;
      }
      return ImportFileType.unknown;
    } catch (_) {
      return ImportFileType.unknown;
    }
  }

  String _buildImportErrorMessage(ImportException error) {
    // Use the exception type directly (already mapped in repository)
    final effectiveType = error.type;
    
    // Map exception types to user-friendly messages
    return switch (effectiveType) {
      ImportExceptionType.formatUnsupported =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Unsupported broker format. Please upload a valid Excel file from Mofid or Agah broker.',
      ImportExceptionType.parseFailure =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Failed to parse Excel file. Please verify the file is not corrupted.',
      ImportExceptionType.integrityError =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Duplicate transactions detected. Some rows were skipped.',
      ImportExceptionType.network =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Network error while uploading the file. Please retry.',
      ImportExceptionType.unauthorized =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Your session has expired. Please sign in and try again.',
      ImportExceptionType.validation =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Validation error. Please check the file format and content.',
      ImportExceptionType.cancelled =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Upload cancelled by user.',
      ImportExceptionType.server =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Server error occurred. Please try again later.',
      ImportExceptionType.unknown =>
        error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Unknown error occurred. Please check logs or contact support.',
    };
  }

  String? _resolveImportedPortfolioId({
    required ImportReportModel report,
    required ImportTargetPayload? importTarget,
  }) {
    final requestedId = importTarget?.portfolioId?.trim();
    if (requestedId != null && requestedId.isNotEmpty) {
      return requestedId;
    }

    final reportJob = report.job;
    if (reportJob == null) {
      return null;
    }
    final jobPortfolioId = reportJob['portfolio_id']?.toString().trim();
    if (jobPortfolioId == null || jobPortfolioId.isEmpty) {
      return null;
    }
    return jobPortfolioId;
  }

  void _invalidatePostImportState({
    String? portfolioId,
    bool switchPortfolioContext = false,
    String? traceId,
  }) {
    ref
      ..invalidate(transactionsListProvider)
      ..invalidate(portfolioStatsProvider)
      ..invalidate(portfolioManagerControllerProvider)
      ..invalidate(portfolioListProvider);

    final normalizedPortfolioId = portfolioId?.trim();
    if (normalizedPortfolioId == null || normalizedPortfolioId.isEmpty) {
      return;
    }

    final currentSelection = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
    if (kDebugMode) {
      debugPrint(
        '[ExcelImportController] post-import invalidation '
        'target=$normalizedPortfolioId active=$currentSelection '
        'switchPortfolioContext=$switchPortfolioContext',
      );
    }
    if (switchPortfolioContext || currentSelection.isEmpty) {
      ref.read(selectedPortfolioIdProvider.notifier).state = normalizedPortfolioId;
    }
    ImportAnalyticsRefreshTrace.logProviderInvalidation(
      traceId: traceId,
      providerName: 'dashboardControllerProvider',
      portfolioId: currentSelection.isNotEmpty
          ? currentSelection
          : normalizedPortfolioId,
    );
    _invalidateAnalyticsBundle(
      portfolioId: normalizedPortfolioId,
      source: 'import-target',
      traceId: traceId,
    );

    if (!switchPortfolioContext &&
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
      trigger: 'excel_import_controller_invalidation_complete',
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
          '[ExcelImportController] invalidated '
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
