import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/debug/import_analytics_refresh_trace.dart';
import '../../analytics/domain/models/analytics_models.dart';
import '../../analytics/presentation/providers/analytics_controller.dart';
import '../../analytics/presentation/providers/benchmark_dashboard_controller.dart';
import '../../analytics/presentation/providers/benchmark_payload_provider.dart';
import '../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../assets/presentation/providers/asset_ledger_notifiers.dart';
import '../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../portfolio/presentation/providers/portfolio_summary_provider.dart';
import '../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../data/import_repository.dart';

enum ImportPhase {
  idle,
  uploading,
  polling,
  completed,
  failed,
}

class ImportExcelState {
  const ImportExcelState({
    required this.phase,
    this.job,
    this.errors = const <ImportJobErrorDto>[],
    this.message,
  });

  final ImportPhase phase;
  final ImportJobDto? job;
  final List<ImportJobErrorDto> errors;
  final String? message;

  ImportExcelState copyWith({
    ImportPhase? phase,
    ImportJobDto? job,
    List<ImportJobErrorDto>? errors,
    String? message,
    bool clearMessage = false,
  }) {
    return ImportExcelState(
      phase: phase ?? this.phase,
      job: job ?? this.job,
      errors: errors ?? this.errors,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  static const initial = ImportExcelState(phase: ImportPhase.idle);
}

class ImportExcelController extends StateNotifier<ImportExcelState> {
  ImportExcelController({
    required this.ref,
    required ImportRepository repository,
  })  : _repository = repository,
        super(ImportExcelState.initial);

  final Ref ref;
  final ImportRepository _repository;
  Timer? _pollTimer;
  bool _isFetching = false;

  Future<String?> uploadFromPicker({
    required String portfolioId,
  }) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final file = picked.files.single;
    final payload = ImportUploadFile(
      fileName: file.name,
      path: file.path,
      bytes: file.bytes,
    );
    return upload(
      portfolioId: portfolioId,
      file: payload,
    );
  }

  Future<String?> upload({
    required String portfolioId,
    required ImportUploadFile file,
  }) async {
    _cancelPolling();
    state = state.copyWith(
      phase: ImportPhase.uploading,
      message: null,
      clearMessage: true,
      errors: const <ImportJobErrorDto>[],
    );
    try {
      final job = await _repository.uploadExcel(
        portfolioId: portfolioId,
        file: file,
      );
      state = state.copyWith(
        phase: ImportPhase.polling,
        job: job,
        clearMessage: true,
      );
      startPolling(job.id);
      return job.id;
    } on ImportRepositoryException catch (error) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        message: error.message,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        message: 'Unexpected error during upload.',
      );
      return null;
    }
  }

  void startPolling(String jobId) {
    _cancelPolling();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refresh(jobId),
    );
    unawaited(_refresh(jobId));
  }

  Future<void> refreshNow() async {
    final job = state.job;
    if (job == null) {
      return;
    }
    await _refresh(job.id);
  }

  Future<void> _refresh(String jobId) async {
    if (_isFetching) {
      return;
    }
    _isFetching = true;
    try {
      final job = await _repository.getJobStatus(jobId: jobId);
      state = state.copyWith(
        phase: job.isTerminal
            ? (job.status == 'COMPLETED' ? ImportPhase.completed : ImportPhase.failed)
            : ImportPhase.polling,
        job: job,
        clearMessage: true,
      );

      if (job.isTerminal) {
        _cancelPolling();
        final errors = await _repository.getJobErrors(jobId: jobId);
        state = state.copyWith(errors: errors);
        if (job.status == 'COMPLETED') {
          final selectionBefore =
              (ref.read(selectedPortfolioIdProvider) ?? '').trim();
          final selectionAfter =
              selectionBefore.isEmpty ? job.portfolioId.trim() : selectionBefore;
          final traceId = ImportAnalyticsRefreshTrace.startImportSuccess(
            importFlowName: 'ImportExcelController',
            targetPortfolioId: job.portfolioId.trim(),
            selectedPortfolioIdBefore: selectionBefore,
            selectedPortfolioIdAfter: selectionAfter,
            importedRows: job.insertedRows,
            importBatchId: job.id,
          );
          _invalidatePostImportState(
            job.portfolioId,
            traceId: traceId,
          );
        }
      }
    } on ImportRepositoryException catch (error) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        message: error.message,
      );
      _cancelPolling();
    } finally {
      _isFetching = false;
    }
  }

  void clear() {
    _cancelPolling();
    state = ImportExcelState.initial;
  }

  @override
  void dispose() {
    _cancelPolling();
    super.dispose();
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _invalidatePostImportState(
    String portfolioId, {
    String? traceId,
  }) {
    final normalizedPortfolioId = portfolioId.trim();
    final currentSelection = (ref.read(selectedPortfolioIdProvider) ?? '').trim();
    if (kDebugMode) {
      debugPrint(
        '[ImportExcelController] post-import invalidation target=$normalizedPortfolioId active=$currentSelection',
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

    if (currentSelection.isEmpty) {
      ref.read(selectedPortfolioIdProvider.notifier).state = normalizedPortfolioId;
    }
    _invalidateAnalyticsBundle(
      portfolioId: normalizedPortfolioId,
      source: 'import-target',
      traceId: traceId,
    );

    if (currentSelection.isNotEmpty && currentSelection != normalizedPortfolioId) {
      _invalidateAnalyticsBundle(
        portfolioId: currentSelection,
        source: 'active-selection',
        traceId: traceId,
      );
    }
    ImportAnalyticsRefreshTrace.emitFinalVerdict(
      traceId: traceId,
      portfolioId: normalizedPortfolioId,
      trigger: 'import_excel_controller_invalidation_complete',
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
          '[ImportExcelController] invalidated '
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

final importExcelControllerProvider =
    StateNotifierProvider<ImportExcelController, ImportExcelState>((ref) {
  return ImportExcelController(
    ref: ref,
    repository: ref.watch(importRepositoryProvider),
  );
});
