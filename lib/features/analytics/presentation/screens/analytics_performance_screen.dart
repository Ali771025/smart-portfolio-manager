import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/debug/import_analytics_refresh_trace.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/theme/custom_theme_extension.dart';
import '../../../portfolio_manager/domain/models/portfolio_card_dto.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../domain/models/analytics_models.dart';
import '../providers/analytics_controller.dart';
import '../providers/benchmark_payload_provider.dart';
import '../widgets/analytics_allocation_donut_chart.dart';
import '../widgets/analytics_drawdown_area_chart.dart';
import '../widgets/analytics_kpi_header.dart';
import '../widgets/analytics_loading_skeletons.dart';
import '../widgets/analytics_performance_line_chart.dart';
import '../widgets/analytics_risk_score_card.dart';
import '../widgets/analytics_risk_stats_grid.dart';
import '../widgets/financial_numeric_text.dart';
import '../widgets/hf_benchmark_multiline_chart.dart';

class AnalyticsScreen extends AnalyticsPerformanceScreen {
  const AnalyticsScreen({
    required super.portfolioId,
    super.key,
  });
}

class AnalyticsPerformanceScreen extends ConsumerWidget {
  const AnalyticsPerformanceScreen({
    required this.portfolioId,
    super.key,
  });

  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioManagerState = ref.watch(portfolioManagerControllerProvider);
    final portfolioOptions = ref.watch(portfolioOptionsProvider);
    final selectedPortfolioId = (ref.watch(selectedPortfolioIdProvider) ?? '').trim();
    final requestedPortfolioId = portfolioId.trim();
    final knownIds = portfolioOptions.map((item) => item.id).toSet();
    final isPortfolioListLoading =
        portfolioManagerState.isLoading && portfolioOptions.isEmpty;

    String resolvedPortfolioId = '';
    if (requestedPortfolioId.isNotEmpty && knownIds.contains(requestedPortfolioId)) {
      resolvedPortfolioId = requestedPortfolioId;
    } else if (selectedPortfolioId.isNotEmpty && knownIds.contains(selectedPortfolioId)) {
      resolvedPortfolioId = selectedPortfolioId;
    } else if (portfolioOptions.length == 1) {
      resolvedPortfolioId = portfolioOptions.first.id;
    }

    if (isPortfolioListLoading) {
      return const _AnalyticsBootLoadingState();
    }

    if (requestedPortfolioId.isNotEmpty &&
        !knownIds.contains(requestedPortfolioId) &&
        resolvedPortfolioId.isEmpty) {
      return _CenteredFailureState(
        message:
            'پرتفوی درخواست‌شده یافت نشد. لطفاً از انتخاب‌گر پرتفوی یک گزینه معتبر انتخاب کنید.',
        onRetry: () => context.go('/portfolios'),
      );
    }

    if (resolvedPortfolioId.isEmpty) {
      return _CenteredFailureState(
        message:
            'هنوز پرتفویی در دسترس نیست. ابتدا یک پرتفوی ایجاد کنید تا تحلیل‌ها نمایش داده شوند.',
        onRetry: () => context.go('/portfolios'),
      );
    }

    final customTheme = _customThemeOf(context);
    final analyticsAsync = ref.watch(analyticsDataProvider(resolvedPortfolioId));
    final notifier =
        ref.read(analyticsDataProvider(resolvedPortfolioId).notifier);
    final failure = ref.watch(analyticsFailureProvider(resolvedPortfolioId));

    if (kDebugMode) {
      debugPrint(
        '[AnalyticsScreen] requestedPortfolioId=$requestedPortfolioId '
        'selectedPortfolioId=$selectedPortfolioId '
        'resolvedPortfolioId=$resolvedPortfolioId '
        'knownPortfolioCount=${knownIds.length}',
      );
    }

    Widget buildContent({
      required AnalyticsViewState viewState,
      required bool isInitialLoading,
      String? inlineErrorMessage,
    }) {
      final safePoints = viewState.performanceSeries.points;
      final safeAllocation = viewState.allocation;
      final hasPerformanceData = safePoints.isNotEmpty;
      final hasAllocationData = safeAllocation.isNotEmpty;

      final traceId =
          ImportAnalyticsRefreshTrace.traceIdForPortfolio(resolvedPortfolioId);
      final growthWindow = ImportAnalyticsRefreshTrace.dateWindow(
        safePoints.map((point) => point.date),
      );
      final growthFingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          viewState.selectedTimeframe.name,
          safePoints.length,
          safePoints.isEmpty
              ? null
              : safePoints.first.date.toUtc().millisecondsSinceEpoch,
          safePoints.isEmpty
              ? null
              : safePoints.last.date.toUtc().millisecondsSinceEpoch,
          safePoints.isEmpty ? null : safePoints.last.portfolioValue,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId: traceId,
        widgetName: 'AnalyticsPerformanceLineChart.growth',
        portfolioId: resolvedPortfolioId,
        timeframe: viewState.selectedTimeframe.name,
        pointCount: safePoints.length,
        firstDate: growthWindow.firstDate,
        lastDate: growthWindow.lastDate,
        dataFingerprint: growthFingerprint,
      );
      final allocationFingerprint = ImportAnalyticsRefreshTrace.fingerprintFromObjects(
        <Object?>[
          safeAllocation.length,
          for (final item in safeAllocation) item.ticker,
          for (final item in safeAllocation) item.percentage,
        ],
      );
      ImportAnalyticsRefreshTrace.logWidgetBuild(
        traceId: traceId,
        widgetName: 'AnalyticsAllocationDonutChart',
        portfolioId: resolvedPortfolioId,
        timeframe: viewState.selectedTimeframe.name,
        pointCount: safeAllocation.length,
        dataFingerprint: allocationFingerprint,
      );

      final benchmarkRequest = (
        portfolioId: resolvedPortfolioId,
        timeframe: viewState.selectedTimeframe,
      );
      final benchmarkPayloadAsync = ref.watch(
        benchmarkMsgPackPayloadProvider(benchmarkRequest),
      );

      final kpiCard = _GlassAnalyticsCard(
        child: isInitialLoading
            ? const AnalyticsKpiHeaderSkeleton()
            : AnalyticsKpiHeader(
                metrics: viewState.metrics,
                totalNav: safePoints.isNotEmpty ? safePoints.last.portfolioValue : 0,
                portfolioId: resolvedPortfolioId,
                timeframe: viewState.selectedTimeframe,
              ),
      );

      final riskCard = _GlassAnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ارزیابی ریسک و عملکرد',
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            if (isInitialLoading)
              Skeletonizer(
                enabled: true,
                child: AnalyticsRiskStatsGrid(
                  risk: viewState.metrics.riskAssessment,
                ),
              )
            else
              AnalyticsRiskStatsGrid(
                risk: viewState.metrics.riskAssessment,
              ),
          ],
        ),
      );

      final growthPoints = safePoints
          .map((point) => point.copyWith(benchmarkValue: null))
          .toList(growable: false);
      final growthCard = _GlassAnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'روند رشد سرمایه',
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            isInitialLoading
                ? const AnalyticsChartSkeleton(height: 240)
                : hasPerformanceData
                    ? AnalyticsPerformanceLineChart(
                        points: growthPoints,
                        portfolioId: resolvedPortfolioId,
                        timeframe: viewState.selectedTimeframe,
                      )
                    : const _AnalyticsCardEmptyState(
                        message: 'نمودار رشد سرمایه هنوز داده‌ای برای نمایش ندارد.',
                      ),
          ],
        ),
      );
      final drawdownCard = _GlassAnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'روند افت سرمایه',
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            isInitialLoading
                ? const AnalyticsChartSkeleton(height: 240)
                : hasPerformanceData
                    ? AnalyticsDrawdownAreaChart(
                        points: safePoints,
                        portfolioId: resolvedPortfolioId,
                        timeframe: viewState.selectedTimeframe,
                      )
                    : const _AnalyticsCardEmptyState(
                        message: 'نمودار افت سرمایه هنوز داده‌ای برای نمایش ندارد.',
                      ),
          ],
        ),
      );

      final performanceChart = benchmarkPayloadAsync.when(
        data: (payload) {
          if (kDebugMode) {
            debugPrint(
              '[AnalyticsScreen] benchmark payload '
              'portfolioId=$resolvedPortfolioId '
              'timeframe=${viewState.selectedTimeframe.name} '
              'bytes=${payload?.length ?? 0}',
            );
          }
          if (payload == null || payload.isEmpty) {
            ImportAnalyticsRefreshTrace.logWidgetBuild(
              traceId: traceId,
              widgetName: 'AnalyticsPerformanceLineChart.benchmarkFallback',
              portfolioId: resolvedPortfolioId,
              timeframe: viewState.selectedTimeframe.name,
              pointCount: safePoints.length,
              firstDate: growthWindow.firstDate,
              lastDate: growthWindow.lastDate,
              dataFingerprint: growthFingerprint,
              payloadFingerprintChanged: false,
            );
            return _BenchmarkChartFallback(
              points: safePoints,
              portfolioId: resolvedPortfolioId,
              timeframe: viewState.selectedTimeframe,
              errorMessage: 'داده شاخص کل برای این بازه خالی است.',
              onRetry: () => ref.invalidate(
                benchmarkMsgPackPayloadProvider(benchmarkRequest),
              ),
            );
          }

          return HighFrequencyBenchmarkChart(
            portfolioId: resolvedPortfolioId,
            messagePackPayload: payload,
            maxPointsPerSeries: 500,
            showMiniMap: true,
            timeframe: viewState.selectedTimeframe,
          );
        },
        loading: () => AnalyticsPerformanceLineChart(
          points: safePoints,
          portfolioId: resolvedPortfolioId,
          timeframe: viewState.selectedTimeframe,
        ),
        error: (error, _) => _BenchmarkChartFallback(
          points: safePoints,
          portfolioId: resolvedPortfolioId,
          timeframe: viewState.selectedTimeframe,
          errorMessage: _messageFromError(
            error,
            fallback: 'داده شاخص کل برای مقایسه دریافت نشد.',
          ),
          onRetry: () => ref.invalidate(
            benchmarkMsgPackPayloadProvider(benchmarkRequest),
          ),
        ),
      );

      final performanceCard = _GlassAnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مقایسه شاخص‌های مرجع',
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            isInitialLoading
                ? const AnalyticsChartSkeleton(height: 250)
                : hasPerformanceData
                    ? performanceChart
                    : const _AnalyticsCardEmptyState(
                        message: 'داده عملکرد برای این بازه زمانی موجود نیست.',
                      ),
          ],
        ),
      );

      final allocationCard = _GlassAnalyticsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تخصیص دارایی',
              style: customTheme.sectionTitleStyle,
            ),
            const SizedBox(height: 10),
            isInitialLoading
                ? const AnalyticsChartSkeleton(height: 240)
                : hasAllocationData
                    ? AnalyticsAllocationDonutChart(
                        slices: safeAllocation,
                        portfolioId: resolvedPortfolioId,
                        timeframe: viewState.selectedTimeframe,
                      )
                    : const _AnalyticsCardEmptyState(
                        message: 'تخصیص دارایی برای این پرتفوی در دسترس نیست.',
                      ),
          ],
        ),
      );
      final riskScoreCard = _GlassAnalyticsCard(
        child: isInitialLoading
            ? const AnalyticsChartSkeleton(height: 160)
            : AnalyticsRiskScoreCard(metrics: viewState.metrics),
      );

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              if (kDebugMode) {
                debugPrint(
                  '[AnalyticsScreen] manual refresh invalidated '
                  'benchmarkMsgPackPayloadProvider($resolvedPortfolioId,'
                  '${viewState.selectedTimeframe.name})',
                );
              }
              ref.invalidate(
                benchmarkMsgPackPayloadProvider(
                  (
                    portfolioId: resolvedPortfolioId,
                    timeframe: viewState.selectedTimeframe,
                  ),
                ),
              );
              await notifier.reload();
            },
            child: SafeArea(
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تحلیل و عملکرد',
                                    style: customTheme.headerTitleStyle,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'نمای عمیق از عملکرد و ریسک پرتفوی شما',
                                    style: customTheme.headerSubtitleStyle
                                        .copyWith(
                                      color: customTheme.chartAxis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () {
                                if (kDebugMode) {
                                  debugPrint(
                                    '[AnalyticsScreen] refresh button invalidated '
                                    'benchmarkMsgPackPayloadProvider($resolvedPortfolioId,'
                                    '${viewState.selectedTimeframe.name})',
                                  );
                                }
                                ref.invalidate(
                                  benchmarkMsgPackPayloadProvider(
                                    (
                                      portfolioId: resolvedPortfolioId,
                                      timeframe: viewState.selectedTimeframe,
                                    ),
                                  ),
                                );
                                notifier.reload();
                              },
                              icon: analyticsAsync.isLoading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: customTheme.primarySemantic,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'ابزار سنجش بنچمارک',
                                onPressed: () {
                                  context.push(
                                    '/analytics/hf-benchmark-harness'
                                    '?portfolio_id=$resolvedPortfolioId',
                                  );
                                },
                                icon: const Icon(Icons.speed_rounded),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: _PortfolioSelector(
                          options: portfolioOptions,
                          selectedPortfolioId: resolvedPortfolioId,
                          onChanged: (nextId) {
                            if (nextId == resolvedPortfolioId) {
                              return;
                            }
                            ref.read(selectedPortfolioIdProvider.notifier).state =
                                nextId;
                            final uri = Uri(
                              path: '/analytics',
                              queryParameters: <String, String>{
                                'portfolio_id': nextId,
                              },
                            );
                            context.go(uri.toString());
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 18)),
                      SliverToBoxAdapter(
                        child: _AnimatedTimeframeSelector(
                          selected: viewState.selectedTimeframe,
                          onSelected: notifier.selectTimeframe,
                        ),
                      ),
                      if (inlineErrorMessage != null) ...[
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverToBoxAdapter(
                          child: _InlineErrorBanner(
                            message: inlineErrorMessage,
                            onRetry: notifier.reload,
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final isMobile = width < 760;
                    final useTwoColumns = width >= 760;

                    if (isMobile) {
                      return SliverMainAxisGroup(
                        slivers: [
                          _sectionSliver(child: kpiCard),
                          _sectionSliver(child: growthCard),
                          _sectionSliver(child: performanceCard),
                          _sectionSliver(child: allocationCard),
                          _sectionSliver(child: drawdownCard),
                          _sectionSliver(child: riskScoreCard),
                          _sectionSliver(child: riskCard, bottom: 24),
                        ],
                      );
                    }

                    return SliverMainAxisGroup(
                      slivers: [
                        _sectionSliver(child: kpiCard),
                        _pairedSectionSliver(
                          left: growthCard,
                          right: performanceCard,
                          forceTwoColumns: useTwoColumns,
                        ),
                        _pairedSectionSliver(
                          left: allocationCard,
                          right: riskScoreCard,
                          forceTwoColumns: useTwoColumns,
                        ),
                        _sectionSliver(child: drawdownCard),
                        _sectionSliver(child: riskCard, bottom: 24),
                      ],
                    );
                  },
                ),
              ],
              ),
            ),
          ),
        ),
      );
    }

    return analyticsAsync.when(
      data: (viewState) => buildContent(
        viewState: viewState,
        isInitialLoading: false,
      ),
      loading: () => buildContent(
        viewState: _skeletonState(portfolioId: resolvedPortfolioId),
        isInitialLoading: true,
      ),
      error: (error, _) {
        final fallback = analyticsAsync.value;
        final problem = _problemDetails(
          error: error,
          failure: failure,
          portfolioId: resolvedPortfolioId,
        );
        if (fallback != null) {
          return buildContent(
            viewState: fallback,
            isInitialLoading: false,
            inlineErrorMessage: problem.detail,
          );
        }

        return _RfcProblemDetailsState(
          problem: problem,
          onRetry: notifier.reload,
          onBackToPortfolios: () => context.go('/portfolios'),
        );
      },
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
    );
  }
}

class _ProblemDetails {
  const _ProblemDetails({
    required this.type,
    required this.title,
    required this.status,
    required this.detail,
    required this.instance,
  });

  final String type;
  final String title;
  final int status;
  final String detail;
  final String instance;
}

_ProblemDetails _problemDetails({
  required Object error,
  required AppFailure? failure,
  required String portfolioId,
}) {
  final status = failure?.statusCode ?? (failure?.isUnauthorized == true ? 401 : 500);
  final title = switch (status) {
    400 => 'درخواست نامعتبر',
    401 => 'عدم احراز هویت',
    403 => 'عدم دسترسی',
    404 => 'یافت نشد',
    409 => 'تداخل اطلاعات',
    422 => 'داده قابل پردازش نیست',
    >= 500 => 'خطای داخلی سرور',
    _ => 'خطا در بارگذاری داده‌های تحلیل',
  };
  final failureMessage = failure?.message.trim() ?? '';
  final detail = failureMessage.isEmpty ? error.toString() : failureMessage;

  return _ProblemDetails(
    type: 'about:blank',
    title: title,
    status: status,
    detail: detail,
    instance: '/analytics?portfolio_id=$portfolioId',
  );
}

Widget _sectionSliver({
  required Widget child,
  double bottom = 12,
}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    sliver: SliverToBoxAdapter(child: child),
  );
}

Widget _pairedSectionSliver({
  required Widget left,
  required Widget right,
  bool forceTwoColumns = true,
  double bottom = 16,
}) {
  if (!forceTwoColumns) {
    return SliverMainAxisGroup(
      slivers: [
        _sectionSliver(child: left, bottom: 12),
        _sectionSliver(child: right, bottom: bottom),
      ],
    );
  }

  return SliverPadding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    sliver: SliverToBoxAdapter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      ),
    ),
  );
}

class _GlassAnalyticsCard extends StatelessWidget {
  const _GlassAnalyticsCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: isDark ? 8 : 0, sigmaY: isDark ? 8 : 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: customTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: customTheme.cardStroke),
              boxShadow: [
                BoxShadow(
                  color: customTheme.cardShadow,
                  blurRadius: isDark ? 14 : 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PortfolioSelector extends StatelessWidget {
  const _PortfolioSelector({
    required this.options,
    required this.selectedPortfolioId,
    required this.onChanged,
  });

  final List<PortfolioOptionDto> options;
  final String selectedPortfolioId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: customTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: customTheme.cardStroke),
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>(selectedPortfolioId),
        initialValue: selectedPortfolioId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'پرتفوی مبنا برای تحلیل و بنچمارک',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        items: options
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value == null || value.trim().isEmpty) {
            return;
          }
          onChanged(value);
        },
      ),
    );
  }
}

class _AnimatedTimeframeSelector extends StatelessWidget {
  const _AnimatedTimeframeSelector({
    required this.selected,
    required this.onSelected,
  });

  final AnalyticsTimeframe selected;
  final ValueChanged<AnalyticsTimeframe> onSelected;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);
    final items = AnalyticsTimeframe.values;
    final selectedIndex = items.indexOf(selected);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: customTheme.segmentedBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: customTheme.cardStroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: (selectedIndex * segmentWidth) + 4,
                top: 4,
                width: segmentWidth - 8,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: customTheme.segmentedPill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: items.map((item) {
                  final active = item == selected;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelected(item),
                      child: Center(
                        child: Text(
                          item.shortLabel,
                          style: customTheme.bodyStyle.copyWith(
                            color: active
                                ? customTheme.primarySemantic
                                : customTheme.chartAxis,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            fontFeatures: kFinancialNumericFontFeatures,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: customTheme.dangerSemantic.withValues(alpha: 0.12),
        border: Border.all(
          color: customTheme.dangerSemantic.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: customTheme.dangerSemantic,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: customTheme.captionStyle,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }
}

class _RfcProblemDetailsState extends StatelessWidget {
  const _RfcProblemDetailsState({
    required this.problem,
    required this.onRetry,
    required this.onBackToPortfolios,
  });

  final _ProblemDetails problem;
  final VoidCallback onRetry;
  final VoidCallback onBackToPortfolios;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);
    final fields = <({String label, String value})>[
      (label: 'نوع', value: problem.type),
      (label: 'عنوان', value: problem.title),
      (label: 'کد وضعیت', value: problem.status.toString()),
      (label: 'جزئیات', value: problem.detail),
      (label: 'مسیر', value: problem.instance),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: customTheme.cardBackground,
                    border: Border.all(
                      color: customTheme.dangerSemantic.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جزئیات خطای تحلیل',
                        style: customTheme.sectionTitleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'نمایش خطا بر اساس الگوی RFC 7807',
                        style: customTheme.captionStyle.copyWith(
                          color: customTheme.chartAxis,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            '${field.label}: ${field.value}',
                            style: customTheme.bodyStyle.copyWith(
                              fontFeatures: kFinancialNumericFontFeatures,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: onRetry,
                            child: const Text('تلاش مجدد'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: onBackToPortfolios,
                            child: const Text('بازگشت به پرتفوی‌ها'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsBootLoadingState extends StatelessWidget {
  const _AnalyticsBootLoadingState();

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        customTheme.primarySemantic,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'در حال آماده‌سازی تحلیل‌ها',
                      style: customTheme.sectionTitleStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لیست پرتفوی و داده‌های شاخص کل در حال بارگذاری است.',
                      textAlign: TextAlign.center,
                      style: customTheme.bodyStyle.copyWith(
                        color: customTheme.chartAxis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenchmarkChartFallback extends StatelessWidget {
  const _BenchmarkChartFallback({
    required this.points,
    required this.portfolioId,
    required this.timeframe,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<AnalyticsPerformancePoint> points;
  final String portfolioId;
  final AnalyticsTimeframe timeframe;
  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineErrorBanner(
          message: errorMessage,
          onRetry: onRetry,
        ),
        const SizedBox(height: 12),
        Text(
          'تا زمان دریافت شاخص کل، فقط روند پرتفوی نمایش داده می‌شود.',
          style: customTheme.captionStyle.copyWith(
            color: customTheme.chartAxis,
          ),
        ),
        const SizedBox(height: 10),
        AnalyticsPerformanceLineChart(
          points: points,
          portfolioId: portfolioId,
          timeframe: timeframe,
          benchmarkLabel: 'شاخص کل',
        ),
      ],
    );
  }
}

class _CenteredFailureState extends StatelessWidget {
  const _CenteredFailureState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: customTheme.chartAxis,
                ),
                const SizedBox(height: 14),
                Text(
                  'بارگذاری تحلیل‌ها انجام نشد',
                  style: customTheme.sectionTitleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: customTheme.bodyStyle.copyWith(
                    color: customTheme.chartAxis,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('تلاش دوباره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCardEmptyState extends StatelessWidget {
  const _AnalyticsCardEmptyState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final customTheme = _customThemeOf(context);
    return SizedBox(
      height: 220,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: customTheme.bodyStyle.copyWith(
              color: customTheme.chartAxis,
            ),
          ),
        ),
      ),
    );
  }
}

CustomThemeExtension _customThemeOf(BuildContext context) {
  return CustomThemeExtension.resolve(context);
}

String _messageFromError(
  Object error, {
  required String fallback,
}) {
  if (error is AppFailure && error.message.trim().isNotEmpty) {
    return error.message;
  }
  final text = error.toString().trim();
  if (text.isEmpty) {
    return fallback;
  }
  return text.replaceFirst('Exception: ', '');
}

AnalyticsViewState _skeletonState({
  required String portfolioId,
}) {
  final now = DateTime.now().toUtc();
  final points = List<AnalyticsPerformancePoint>.generate(30, (index) {
    return AnalyticsPerformancePoint(
      date: now.subtract(Duration(days: 30 - index)),
      portfolioValue: 120000 + (index * 2450),
      benchmarkValue: 112000 + (index * 1960),
      pnl: 6000 + (index * 440),
      roiPercent: 2.1 + (index * 0.12),
    );
  });

  return AnalyticsViewState(
    selectedTimeframe: AnalyticsTimeframe.oneMonth,
    performanceSeries: AnalyticsPerformanceSeries(
      portfolioId: portfolioId,
      timeframe: AnalyticsTimeframe.oneMonth,
      baseCurrency: 'USD',
      points: points,
    ),
    metrics: AnalyticsMetrics(
      portfolioId: portfolioId,
      timeframe: AnalyticsTimeframe.oneMonth,
      baseCurrency: 'USD',
      asOfDate: now,
      riskFreeRate: 0.02,
      pnl: 12540.24,
      roiPercent: 4.92,
      volatility: 15.22,
      sharpeRatio: 1.41,
      riskAssessment: const AdvancedRiskMetricsResponse(
        sortinoRatio: 1.88,
        maximumDrawdown: 0.147,
        beta: 1.06,
        alpha: 0.021,
        valueAtRisk: ValueAtRiskDistribution(
          historical: ValueAtRiskBand(
            confidence95: 0.024,
            confidence99: 0.039,
          ),
          parametric: ValueAtRiskBand(
            confidence95: 0.022,
            confidence99: 0.036,
          ),
        ),
      ),
    ),
    allocation: const [
      AnalyticsAllocationSlice(
        ticker: 'AAPL',
        percentage: 31.4,
        value: 31400,
      ),
      AnalyticsAllocationSlice(
        ticker: 'MSFT',
        percentage: 24.8,
        value: 24800,
      ),
      AnalyticsAllocationSlice(
        ticker: 'NVDA',
        percentage: 22.1,
        value: 22100,
      ),
      AnalyticsAllocationSlice(
        ticker: 'نقد',
        percentage: 21.7,
        value: 21700,
      ),
    ],
  );
}
