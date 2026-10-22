import 'dart:async';

import 'package:flutter/foundation.dart';

class ImportAnalyticsRefreshTrace {
  ImportAnalyticsRefreshTrace._();

  static const bool _traceFlag =
      bool.fromEnvironment('IMPORT_ANALYTICS_TRACE', defaultValue: false);
  static bool get enabled => kDebugMode && _traceFlag;

  static const Duration _traceTtl = Duration(minutes: 10);
  static const Duration _verdictDebounce = Duration(seconds: 3);

  static final Map<String, _TraceState> _tracesById = <String, _TraceState>{};
  static final Map<String, String> _activeTraceByPortfolio = <String, String>{};
  static final Map<String, String> _lastResponseFingerprintByKey =
      <String, String>{};
  static final Map<String, String> _lastWidgetFingerprintByKey =
      <String, String>{};

  static String startImportSuccess({
    required String importFlowName,
    required String targetPortfolioId,
    required String selectedPortfolioIdBefore,
    String? selectedPortfolioIdAfter,
    int? importedRows,
    String? importBatchId,
  }) {
    if (!enabled) {
      return '';
    }

    _sweepExpired();
    final traceId = _newTraceId(flow: importFlowName);
    final state = _TraceState(
      traceId: traceId,
      flowName: importFlowName,
      targetPortfolioId: targetPortfolioId,
      startedAt: DateTime.now().toUtc(),
    );
    _tracesById[traceId] = state;
    _bindPortfolioToTrace(traceId: traceId, portfolioId: targetPortfolioId);
    if ((selectedPortfolioIdAfter ?? '').trim().isNotEmpty) {
      _bindPortfolioToTrace(
        traceId: traceId,
        portfolioId: selectedPortfolioIdAfter!.trim(),
      );
    }

    _log(
      event: 'IMPORT_SUCCESS',
      traceId: traceId,
      fields: <String, Object?>{
        'flow': importFlowName,
        'targetPortfolioId': targetPortfolioId,
        'selectedPortfolioIdBefore': selectedPortfolioIdBefore,
        'selectedPortfolioIdAfter': selectedPortfolioIdAfter ?? '',
        'importedRows': importedRows,
        'importBatchId': importBatchId ?? '',
      },
    );

    _scheduleVerdict(traceId);
    return traceId;
  }

  static void bindPortfolio({
    required String traceId,
    required String portfolioId,
  }) {
    if (!enabled) {
      return;
    }
    _bindPortfolioToTrace(traceId: traceId, portfolioId: portfolioId);
  }

  static String? traceIdForPortfolio(String portfolioId) {
    if (!enabled) {
      return null;
    }
    return _activeTraceByPortfolio[portfolioId.trim()];
  }

  static void logProviderInvalidation({
    String? traceId,
    required String providerName,
    required String portfolioId,
    String? timeframe,
  }) {
    if (!enabled) {
      return;
    }

    final state = _resolveTraceState(traceId: traceId, portfolioId: portfolioId);
    if (state == null) {
      return;
    }
    state.invalidationCount += 1;

    _log(
      event: 'PROVIDER_INVALIDATION',
      traceId: state.traceId,
      fields: <String, Object?>{
        'provider': providerName,
        'portfolioId': portfolioId,
        'timeframe': timeframe ?? '',
      },
    );
    _scheduleVerdict(state.traceId);
  }

  static void logProviderFetchStart({
    String? traceId,
    required String providerName,
    required String portfolioId,
    String? timeframe,
    required String repositoryMethod,
    required String endpointPath,
  }) {
    if (!enabled) {
      return;
    }

    final state = _resolveTraceState(traceId: traceId, portfolioId: portfolioId);
    if (state == null) {
      return;
    }
    state.providerRebuildCount += 1;

    _log(
      event: 'PROVIDER_REBUILD_FETCH_START',
      traceId: state.traceId,
      fields: <String, Object?>{
        'provider': providerName,
        'portfolioId': portfolioId,
        'timeframe': timeframe ?? '',
        'repositoryMethod': repositoryMethod,
        'endpointPath': endpointPath,
      },
    );
    _scheduleVerdict(state.traceId);
  }

  static void logBackendResponse({
    String? traceId,
    required String providerName,
    required String endpointPath,
    required String portfolioId,
    String? timeframe,
    required int statusCode,
    required int payloadSizeBytes,
    String? responseFingerprint,
    int? pointCount,
    int? seriesCount,
    DateTime? minDate,
    DateTime? maxDate,
    DateTime? updatedAt,
    DateTime? recomputedAt,
  }) {
    if (!enabled) {
      return;
    }

    final state = _resolveTraceState(traceId: traceId, portfolioId: portfolioId);
    if (state == null) {
      return;
    }
    state.backendResponseCount += 1;

    final normalizedTimeframe = timeframe ?? '';
    final responseKey = '$endpointPath|$portfolioId|$normalizedTimeframe';
    final fingerprint = (responseFingerprint ?? '').trim();
    final previous = _lastResponseFingerprintByKey[responseKey];
    final changed = fingerprint.isNotEmpty &&
        previous != null &&
        previous.isNotEmpty &&
        previous != fingerprint;
    if (fingerprint.isNotEmpty) {
      _lastResponseFingerprintByKey[responseKey] = fingerprint;
    }
    state.hasBackendResponseChange =
        state.hasBackendResponseChange || changed;

    _log(
      event: 'BACKEND_RESPONSE_FETCH_SUCCESS',
      traceId: state.traceId,
      fields: <String, Object?>{
        'provider': providerName,
        'endpointPath': endpointPath,
        'portfolioId': portfolioId,
        'timeframe': normalizedTimeframe,
        'statusCode': statusCode,
        'payloadSizeBytes': payloadSizeBytes,
        'pointCount': pointCount,
        'seriesCount': seriesCount,
        'minDate': _fmtDate(minDate),
        'maxDate': _fmtDate(maxDate),
        'updatedAt': _fmtDate(updatedAt),
        'recomputedAt': _fmtDate(recomputedAt),
        'responseFingerprint': fingerprint,
        'responseChanged': changed,
      },
    );
    _scheduleVerdict(state.traceId);
  }

  static void logProviderDataReady({
    String? traceId,
    required String providerName,
    required String portfolioId,
    String? timeframe,
    int? pointCount,
    DateTime? firstDate,
    DateTime? lastDate,
    String? dataFingerprint,
  }) {
    if (!enabled) {
      return;
    }

    final state = _resolveTraceState(traceId: traceId, portfolioId: portfolioId);
    if (state == null) {
      return;
    }
    state.providerDataReadyCount += 1;

    _log(
      event: 'PROVIDER_DATA_READY',
      traceId: state.traceId,
      fields: <String, Object?>{
        'provider': providerName,
        'portfolioId': portfolioId,
        'timeframe': timeframe ?? '',
        'pointCount': pointCount,
        'firstDate': _fmtDate(firstDate),
        'lastDate': _fmtDate(lastDate),
        'dataFingerprint': dataFingerprint ?? '',
      },
    );
    _scheduleVerdict(state.traceId);
  }

  static void logWidgetBuild({
    String? traceId,
    required String widgetName,
    required String portfolioId,
    String? timeframe,
    int? pointCount,
    DateTime? firstDate,
    DateTime? lastDate,
    required String dataFingerprint,
    bool? payloadFingerprintChanged,
  }) {
    if (!enabled) {
      return;
    }

    final state = _resolveTraceState(traceId: traceId, portfolioId: portfolioId);
    if (state == null) {
      return;
    }
    state.widgetBuildCount += 1;

    final widgetKey =
        '$widgetName|$portfolioId|${timeframe ?? ''}'.trim();
    final previousFingerprint = _lastWidgetFingerprintByKey[widgetKey];
    final changed = previousFingerprint != null &&
        previousFingerprint.isNotEmpty &&
        previousFingerprint != dataFingerprint;
    _lastWidgetFingerprintByKey[widgetKey] = dataFingerprint;
    state.hasChartFingerprintChange =
        state.hasChartFingerprintChange || changed;

    _log(
      event: 'WIDGET_BUILD_CHART_INGEST',
      traceId: state.traceId,
      fields: <String, Object?>{
        'widget': widgetName,
        'portfolioId': portfolioId,
        'timeframe': timeframe ?? '',
        'pointCount': pointCount,
        'firstDate': _fmtDate(firstDate),
        'lastDate': _fmtDate(lastDate),
        'dataFingerprint': dataFingerprint,
        'payloadFingerprintChanged': payloadFingerprintChanged,
        'chartFingerprintChanged': changed,
      },
    );
    _scheduleVerdict(state.traceId);
  }

  static void emitFinalVerdict({
    String? traceId,
    String? portfolioId,
    String? trigger,
  }) {
    if (!enabled) {
      return;
    }
    final state = _resolveTraceState(
      traceId: traceId,
      portfolioId: portfolioId ?? '',
    );
    if (state == null) {
      return;
    }
    _emitVerdict(state, trigger: trigger ?? 'manual');
  }

  static String fingerprintFromBytes(List<int> bytes) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffset;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String fingerprintFromUint8List(Uint8List payload) {
    return fingerprintFromBytes(payload);
  }

  static String fingerprintFromObjects(Iterable<Object?> values) {
    return Object.hashAll(values).toRadixString(16);
  }

  static ({DateTime? firstDate, DateTime? lastDate}) dateWindow(
    Iterable<DateTime> values,
  ) {
    DateTime? minValue;
    DateTime? maxValue;
    for (final value in values) {
      final normalized = value.toUtc();
      if (minValue == null || normalized.isBefore(minValue)) {
        minValue = normalized;
      }
      if (maxValue == null || normalized.isAfter(maxValue)) {
        maxValue = normalized;
      }
    }
    return (firstDate: minValue, lastDate: maxValue);
  }

  static void _bindPortfolioToTrace({
    required String traceId,
    required String portfolioId,
  }) {
    final normalizedPortfolioId = portfolioId.trim();
    if (normalizedPortfolioId.isEmpty) {
      return;
    }
    final state = _tracesById[traceId];
    if (state == null) {
      return;
    }
    _activeTraceByPortfolio[normalizedPortfolioId] = traceId;
    state.boundPortfolioIds.add(normalizedPortfolioId);
  }

  static _TraceState? _resolveTraceState({
    String? traceId,
    required String portfolioId,
  }) {
    _sweepExpired();

    final normalizedPortfolioId = portfolioId.trim();
    final directId = (traceId ?? '').trim();
    if (directId.isNotEmpty) {
      final direct = _tracesById[directId];
      if (direct != null) {
        _bindPortfolioToTrace(
          traceId: direct.traceId,
          portfolioId: normalizedPortfolioId,
        );
        return direct;
      }
    }

    if (normalizedPortfolioId.isEmpty) {
      return null;
    }
    final mappedId = _activeTraceByPortfolio[normalizedPortfolioId];
    if (mappedId == null || mappedId.isEmpty) {
      return null;
    }
    final mappedState = _tracesById[mappedId];
    if (mappedState == null) {
      _activeTraceByPortfolio.remove(normalizedPortfolioId);
      return null;
    }
    return mappedState;
  }

  static void _scheduleVerdict(String traceId) {
    final state = _tracesById[traceId];
    if (state == null) {
      return;
    }
    state._verdictTimer?.cancel();
    state._verdictTimer = Timer(_verdictDebounce, () {
      _emitVerdict(state, trigger: 'debounced');
    });
  }

  static void _emitVerdict(
    _TraceState state, {
    required String trigger,
  }) {
    final didInvalidation = state.invalidationCount > 0;
    final didProviderRebuild = state.providerRebuildCount > 0;
    final didNetworkRefetch = state.backendResponseCount > 0;
    final didBackendResponseChange = state.hasBackendResponseChange;
    final didWidgetRebuild = state.widgetBuildCount > 0;
    final didChartDataFingerprintChange = state.hasChartFingerprintChange;

    final likelyBrokenLink = _likelyBrokenLink(
      didInvalidation: didInvalidation,
      didProviderRebuild: didProviderRebuild,
      didNetworkRefetch: didNetworkRefetch,
      didBackendResponseChange: didBackendResponseChange,
      didWidgetRebuild: didWidgetRebuild,
      didChartDataFingerprintChange: didChartDataFingerprintChange,
    );

    _log(
      event: 'FINAL_VERDICT',
      traceId: state.traceId,
      fields: <String, Object?>{
        'trigger': trigger,
        'didInvalidationHappen': didInvalidation,
        'didProviderRebuild': didProviderRebuild,
        'didNetworkRefetch': didNetworkRefetch,
        'didBackendResponseChange': didBackendResponseChange,
        'didWidgetRebuild': didWidgetRebuild,
        'didChartDataFingerprintChange': didChartDataFingerprintChange,
        'likelyBrokenLink': likelyBrokenLink,
      },
    );
    state.lastEventAt = DateTime.now().toUtc();
  }

  static String _likelyBrokenLink({
    required bool didInvalidation,
    required bool didProviderRebuild,
    required bool didNetworkRefetch,
    required bool didBackendResponseChange,
    required bool didWidgetRebuild,
    required bool didChartDataFingerprintChange,
  }) {
    if (!didInvalidation) {
      return 'provider invalidation missing after import success';
    }
    if (!didProviderRebuild) {
      return 'providers invalidated but not rebuilt';
    }
    if (!didNetworkRefetch) {
      return 'provider rebuilt but repository/network refetch not observed';
    }
    if (!didBackendResponseChange) {
      return 'backend response unchanged after refetch (backend recompute/cache/data-source)';
    }
    if (!didWidgetRebuild) {
      return 'providers updated but chart widgets did not rebuild';
    }
    if (!didChartDataFingerprintChange) {
      return 'widgets rebuilt but chart data fingerprint unchanged (local chart state/range/filter)';
    }
    return 'no broken link detected in traced chain';
  }

  static void _sweepExpired() {
    if (_tracesById.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final expiredIds = <String>[];
    for (final entry in _tracesById.entries) {
      final state = entry.value;
      if (now.difference(state.lastEventAt) > _traceTtl) {
        expiredIds.add(entry.key);
      }
    }
    for (final traceId in expiredIds) {
      final state = _tracesById.remove(traceId);
      state?._verdictTimer?.cancel();
      if (state == null) {
        continue;
      }
      for (final portfolioId in state.boundPortfolioIds) {
        final mapped = _activeTraceByPortfolio[portfolioId];
        if (mapped == traceId) {
          _activeTraceByPortfolio.remove(portfolioId);
        }
      }
    }
  }

  static String _newTraceId({required String flow}) {
    final now = DateTime.now().toUtc();
    final shortFlow = flow.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final micros = now.microsecondsSinceEpoch;
    final suffix = micros.toRadixString(16).padLeft(12, '0');
    return 'imp_${shortFlow}_$suffix';
  }

  static void _log({
    required String event,
    required String traceId,
    required Map<String, Object?> fields,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final pairs = <String>[
      'event=$event',
      'ts=$now',
      'traceId=$traceId',
      for (final entry in fields.entries)
        '${entry.key}=${_stringify(entry.value)}',
    ];
    debugPrint('[ImportAnalyticsTrace] ${pairs.join(' | ')}');

    final state = _tracesById[traceId];
    if (state != null) {
      state.lastEventAt = DateTime.now().toUtc();
    }
  }

  static String _fmtDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    return value.toUtc().toIso8601String();
  }

  static String _stringify(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    return value.toString().replaceAll('\n', ' ');
  }
}

class _TraceState {
  _TraceState({
    required this.traceId,
    required this.flowName,
    required this.targetPortfolioId,
    required this.startedAt,
  }) : lastEventAt = startedAt;

  final String traceId;
  final String flowName;
  final String targetPortfolioId;
  final DateTime startedAt;
  DateTime lastEventAt;
  final Set<String> boundPortfolioIds = <String>{};

  int invalidationCount = 0;
  int providerRebuildCount = 0;
  int backendResponseCount = 0;
  int providerDataReadyCount = 0;
  int widgetBuildCount = 0;
  bool hasBackendResponseChange = false;
  bool hasChartFingerprintChange = false;

  Timer? _verdictTimer;
}
