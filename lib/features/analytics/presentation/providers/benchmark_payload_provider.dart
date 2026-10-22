import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../data/analytics_repository.dart';
import '../../domain/models/analytics_models.dart';

final benchmarkMsgPackPayloadProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String portfolioId, AnalyticsTimeframe timeframe})>(
  (ref, request) async {
    final traceId = ImportAnalyticsRefreshTrace.traceIdForPortfolio(
      request.portfolioId,
    );
    ImportAnalyticsRefreshTrace.logProviderFetchStart(
      traceId: traceId,
      providerName: 'benchmarkMsgPackPayloadProvider',
      portfolioId: request.portfolioId,
      timeframe: request.timeframe.name,
      repositoryMethod: 'AnalyticsRepository.fetchBenchmarkMsgPack',
      endpointPath:
          '/benchmarking/portfolios/{portfolioId}/twr-attribution?response_format=msgpack',
    );
    final repository = ref.watch(analyticsRepositoryProvider);
    final result = await repository.fetchBenchmarkMsgPack(
      portfolioId: request.portfolioId,
      timeframe: request.timeframe,
    );

    return result.match(
      (failure) => throw failure,
      (payload) {
        ImportAnalyticsRefreshTrace.logProviderDataReady(
          traceId: traceId,
          providerName: 'benchmarkMsgPackPayloadProvider',
          portfolioId: request.portfolioId,
          timeframe: request.timeframe.name,
          pointCount: payload.length,
          dataFingerprint:
              ImportAnalyticsRefreshTrace.fingerprintFromUint8List(payload),
        );
        return payload;
      },
    );
  },
);
