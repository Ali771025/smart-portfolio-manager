import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../../market/presentation/providers/market_controller.dart';
import '../../../market/presentation/widgets/market_status_indicator.dart';
import '../../domain/models/dashboard_state.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/animated_dashboard_section.dart';
import '../widgets/asset_allocation_chart.dart';
import '../widgets/dashboard_glass_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_loading_state.dart';
import '../widgets/dashboard_asset_holdings_section.dart';
import '../widgets/portfolio_kpi_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final sessionToken = session?.accessToken.trim() ?? '';
    final configuredToken = ref.watch(dashboardAuthTokenProvider).trim();
    final token = sessionToken.isNotEmpty ? sessionToken : configuredToken;
    final asyncDashboard = ref.watch(dashboardControllerProvider);
    final monitoringAsync = ref.watch(fallbackMonitoringLiveProvider);
    final marketStatus = ref.watch(marketStatusControllerProvider);
    final tokenReady = token.isNotEmpty;
    if (!marketStatus.isLoading && marketStatus.status == null) {
      unawaited(
        Future<void>(
          () => ref.read(marketStatusControllerProvider.notifier).fetchStatus(),
        ),
      );
    }

    if (!tokenReady) {
      return const _DashboardNoDataState(
        title: 'توکن دسترسی موجود نیست',
        subtitle: 'برای نمایش داشبورد، ابتدا وارد حساب کاربری شوید.',
      );
    }

    final data = asyncDashboard.value;
    final isRefreshing = asyncDashboard.isLoading && data != null;
    final hasAnyData = data != null &&
        (data.assetAllocation.isNotEmpty ||
            data.topMovers.isNotEmpty ||
            data.topPortfoliosByPnl.isNotEmpty ||
            data.topAssets.isNotEmpty ||
            data.assets.isNotEmpty ||
            data.growthChart.isNotEmpty ||
            data.portfolioCount > 0 ||
            data.metrics.totalCurrentValue > 0 ||
            data.metrics.totalProfitLoss != 0 ||
            data.metrics.overallRoiPercent != 0);

    return ColoredBox(
      color: context.semanticColors.background,
      child: RefreshIndicator(
        onRefresh: () => ref.read(dashboardControllerProvider.notifier).reload(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList.list(
                children: [
                  AnimatedDashboardSection(
                    delay: 80.ms,
                    child: DashboardHeader(
                      isRefreshing: isRefreshing,
                      onRefresh: () => ref.read(dashboardControllerProvider.notifier).reload(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedDashboardSection(
                    delay: 120.ms,
                    child: const _MarketPulseCard(),
                  ),
                  const SizedBox(height: 12),
                  if (asyncDashboard.isLoading && data == null)
                    const DashboardLoadingState()
                  else if (asyncDashboard.hasError && !hasAnyData)
                    _DashboardNoDataState(
                      title: 'خطا در بارگذاری داشبورد',
                      subtitle: asyncDashboard.error.toString(),
                    )
                  else if (!hasAnyData)
                    const _DashboardNoDataState(
                      title: 'داده‌ای برای نمایش وجود ندارد',
                      subtitle: 'پس از ورود معاملات و دارایی‌های واقعی، داشبورد تکمیل می‌شود.',
                    )
                  else ...[
                    AnimatedDashboardSection(
                      delay: 160.ms,
                      child: _ExecutiveKpiGrid(data: data),
                    ),
                    const SizedBox(height: 12),
                    AnimatedDashboardSection(
                      delay: 280.ms,
                      child: _PortfolioPnlAndAssetsSection(
                        portfolios: data.topPortfoliosByPnl,
                        topAssets: data.topAssets,
                        currency: data.currency,
                      ),
                    ),
                    if (monitoringAsync.value != null || monitoringAsync.isLoading) ...[
                      const SizedBox(height: 12),
                      AnimatedDashboardSection(
                        delay: 460.ms,
                        child: _FallbackMonitoringCard(snapshotAsync: monitoringAsync),
                      ),
                    ],
                    if (asyncDashboard.hasError && !asyncDashboard.isLoading) ...[
                      const SizedBox(height: 10),
                      _InlineError(
                        text: asyncDashboard.error.toString(),
                        onRetry: () => ref.read(dashboardControllerProvider.notifier).reload(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPulseCard extends StatelessWidget {
  const _MarketPulseCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: scheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'نبض بازار',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const MarketStatusIndicator(),
        ],
      ),
    );
  }
}

class _ExecutiveKpiGrid extends StatelessWidget {
  const _ExecutiveKpiGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final fintech = context.fintechColors;
    final metrics = data.metrics;
    final pnlColor =
        metrics.totalProfitLoss >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;
    final roiColor =
        metrics.overallRoiPercent >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 760;
        final items = <Widget>[
          _PortfolioCountTile(count: data.portfolioCount),
          PortfolioKpiTile(
            title: 'ارزش کل سرمایه',
            value: metrics.totalCurrentValue,
            valueColor: Theme.of(context).colorScheme.primary,
            trailingIcon: Icons.account_balance_wallet_rounded,
            currency: data.currency,
          ),
          PortfolioKpiTile(
            title: 'سود/زیان کل',
            value: metrics.totalProfitLoss,
            valueColor: pnlColor,
            trailingIcon: Icons.show_chart_rounded,
            currency: data.currency,
          ),
          PortfolioKpiTile(
            title: 'بازدهی کل (ROI)',
            value: metrics.overallRoiPercent,
            valueColor: roiColor,
            trailingIcon: Icons.percent_rounded,
            isPercent: true,
          ),
        ];
        if (!twoCols) {
          return Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: item,
                    ))
                .toList(growable: false),
          );
        }
        return Column(
          children: [
            Row(
              children: items
                  .take(2)
                  .toList(growable: false)
                  .asMap()
                  .entries
                  .map(
                    (entry) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: entry.key == 0 ? 0 : 10),
                        child: entry.value,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Row(
              children: items
                  .skip(2)
                  .toList(growable: false)
                  .asMap()
                  .entries
                  .map(
                    (entry) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: entry.key == 0 ? 0 : 10),
                        child: entry.value,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      },
    );
  }
}

class _PortfolioCountTile extends StatelessWidget {
  const _PortfolioCountTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat.decimalPattern('fa_IR');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تعداد پرتفوی‌ها',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.folder_copy_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LtrLogText(
            formatter.format(count),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioPnlAndAssetsSection extends StatelessWidget {
  const _PortfolioPnlAndAssetsSection({
    required this.portfolios,
    required this.topAssets,
    required this.currency,
  });

  final List<PortfolioPnlItem> portfolios;
  final List<DashboardAsset> topAssets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopWide = constraints.maxWidth >= 1100;
        if (!isDesktopWide) {
          return Column(
            children: [
              _PortfolioPnlBarChart(
                portfolios: portfolios,
                currency: currency,
              ),
              const SizedBox(height: 12),
              DashboardAssetHoldingsSection(
                assets: topAssets,
                currency: currency,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _PortfolioPnlBarChart(
                portfolios: portfolios,
                currency: currency,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 7,
              child: DashboardAssetHoldingsSection(
                assets: topAssets,
                currency: currency,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PortfolioPnlBarChart extends StatelessWidget {
  const _PortfolioPnlBarChart({
    required this.portfolios,
    required this.currency,
  });

  final List<PortfolioPnlItem> portfolios;
  final String currency;

  static final NumberFormat _money = NumberFormat.compact(locale: 'fa_IR');
  static final NumberFormat _percent = NumberFormat('#,##0.00', 'fa_IR');

  @override
  Widget build(BuildContext context) {
    if (portfolios.isEmpty) {
      return const DashboardEmptyState(
        title: 'داده‌ای برای مقایسه پرتفوی‌ها نیست',
        subtitle: 'پس از ثبت دارایی در چند پرتفوی، نمودار سود/زیان فعال می‌شود.',
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final fintech = context.fintechColors;
    final items = portfolios.take(5).toList(growable: false);
    final maxAbs = items
        .map((item) => item.profitLoss.abs())
        .fold<double>(0, (previous, value) => previous > value ? previous : value);
    final yExtent = maxAbs <= 0 ? 1.0 : maxAbs * 1.22;

    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مقایسه ۵ پرتفوی بر اساس سود/زیان',
                      style: AppTypography.sectionTitle(Theme.of(context).textTheme),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'رتبه‌بندی بر اساس سود/زیان ریالی کل هر پرتفوی',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.bar_chart_rounded,
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                minY: -yExtent,
                maxY: yExtent,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: value == 0
                        ? scheme.outline.withValues(alpha: 0.55)
                        : scheme.outlineVariant.withValues(alpha: 0.45),
                    strokeWidth: value == 0 ? 1.4 : 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 54,
                      getTitlesWidget: (value, _) => LtrLogText(
                        _money.format(value),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= items.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            items[index].portfolioName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => scheme.surface,
                    tooltipBorder: BorderSide(color: scheme.outlineVariant),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = items[group.x.toInt()];
                      final color = item.profitLoss >= 0
                          ? fintech.pnlSuccess
                          : fintech.pnlDanger;
                      return BarTooltipItem(
                        '${item.portfolioName}\n'
                        '${_money.format(item.profitLoss)} $currency\n'
                        '${_percent.format(item.profitLossPercent)}٪',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < items.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: items[index].profitLoss,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                            bottom: Radius.circular(6),
                          ),
                          color: items[index].profitLoss >= 0
                              ? fintech.pnlSuccess
                              : fintech.pnlDanger,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: yExtent,
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardNoDataState extends StatelessWidget {
  const _DashboardNoDataState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DashboardEmptyState(title: title, subtitle: subtitle)
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.05, end: 0, duration: 380.ms);
  }
}

class _FallbackMonitoringCard extends StatelessWidget {
  const _FallbackMonitoringCard({
    required this.snapshotAsync,
  });

  final AsyncValue<FallbackMonitoringSnapshot?> snapshotAsync;

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact(locale: 'fa_IR');
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainer,
        border: Border.all(
          color: scheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: snapshotAsync.when(
        data: (snapshot) {
          if (snapshot == null) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'پایش عملیاتی',
                style: AppTypography.sectionTitle(Theme.of(context).textTheme),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MonitoringChip(
                    label: 'اختلال SSE',
                    value: compact.format(snapshot.sseDegradedTotal),
                  ),
                  _MonitoringChip(
                    label: 'جایگزینی Msgpack→JSON',
                    value: compact.format(snapshot.msgpackJsonFallbackTotal),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => Text(
          'داده پایش در دسترس نیست',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _MonitoringChip extends StatelessWidget {
  const _MonitoringChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
      ),
      child: LtrLogText('$label: $value'),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.text,
    required this.onRetry,
  });

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
