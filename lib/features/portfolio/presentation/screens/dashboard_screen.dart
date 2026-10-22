import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../market/presentation/providers/market_controller.dart';
import '../../../market/presentation/widgets/market_status_indicator.dart';
import '../../../transactions/presentation/widgets/transaction_form_widget.dart';
import '../../domain/portfolio_summary.dart';
import '../providers/portfolio_summary_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    required this.portfolioId,
    super.key,
  });

  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryState = ref.watch(portfolioSummaryProvider(portfolioId));
    final marketStatus = ref.watch(marketStatusControllerProvider);
    if (!marketStatus.isLoading && marketStatus.status == null) {
      unawaited(
        Future<void>(
          () => ref.read(marketStatusControllerProvider.notifier).fetchStatus(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(child: MarketStatusIndicator()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioSummaryProvider(portfolioId).notifier).refreshWithSync(),
        child: summaryState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text('Failed to load: $error')),
            ],
          ),
          data: (summary) => _DashboardBody(
            summary: summary,
            onTradePressed: (position) => _openTradeSheet(
              context,
              position,
            ),
          ),
        ),
      ),
      floatingActionButton: summaryState.value == null || summaryState.value!.positions.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openTradeSheet(
                context,
                summaryState.value!.positions.first,
              ),
              label: const Text('Trade'),
              icon: const Icon(Icons.add),
            ),
    );
  }

  void _openTradeSheet(BuildContext context, PositionWithMarketData position) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TransactionFormWidget(
            portfolioId: portfolioId,
            assetId: position.assetId,
            assetLabel: '${position.tickerSymbol} - ${position.assetName}',
            availableQuantity: position.totalQuantity,
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.summary,
    required this.onTradePressed,
  });

  final PortfolioSummary summary;
  final void Function(PositionWithMarketData position) onTradePressed;

  @override
  Widget build(BuildContext context) {
    final currency = summary.baseCurrency;
    final money = NumberFormat('#,##0.00');
    final percent = NumberFormat('#,##0.00');
     final fintechColors = context.fintechColors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(
          title: 'Total Value',
          value: '${money.format(summary.totalCurrentValue)} $currency',
           color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        _MarketStatusCard(lastMarketUpdate: summary.lastMarketUpdate),
        const SizedBox(height: 12),
        _MetricRow(
          leftTitle: 'Unrealized PnL',
          leftValue: '${money.format(summary.totalUnrealizedPnl)} $currency',
           leftColor: summary.totalUnrealizedPnl >= 0 ? fintechColors.pnlSuccess : fintechColors.pnlDanger,
          rightTitle: 'ROI',
          rightValue: '${percent.format(summary.roiPct)}%',
           rightColor: summary.roiPct >= 0 ? fintechColors.pnlSuccess : fintechColors.pnlDanger,
        ),
        const SizedBox(height: 12),
        _MetricCard(
          title: 'Realized PnL',
          value: '${money.format(summary.totalRealizedPnl)} $currency',
           color: summary.totalRealizedPnl >= 0 ? fintechColors.pnlSuccess : fintechColors.pnlDanger,
        ),
        const SizedBox(height: 24),
        Text(
          'Owned Assets',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...summary.positions.map(
          (position) => Card(
            child: ListTile(
              title: Text(position.tickerSymbol),
              subtitle: Text(
                '${position.assetName} • Qty ${position.totalQuantity.toStringAsFixed(4)} • Last Price ${money.format(position.lastPrice)}',
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${money.format(position.currentMarketValue)} $currency'),
                  Text(
                    '${position.unrealizedPnl >= 0 ? '+' : ''}${money.format(position.unrealizedPnl)} $currency',
                    style: TextStyle(
                       color: position.unrealizedPnl >= 0 ? context.fintechColors.pnlSuccess : context.fintechColors.pnlDanger,
                       fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              onTap: () => onTradePressed(position),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketStatusCard extends StatelessWidget {
  const _MarketStatusCard({
    required this.lastMarketUpdate,
  });

  final DateTime? lastMarketUpdate;

  @override
  Widget build(BuildContext context) {
    final formattedUpdate = lastMarketUpdate == null
        ? 'نامشخص'
        : DateFormat('yyyy/MM/dd HH:mm', 'fa_IR').format(lastMarketUpdate!.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const MarketStatusIndicator(),
            const Spacer(),
            Text(
              'آخرین بروزرسانی: $formattedUpdate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.leftTitle,
    required this.leftValue,
    required this.leftColor,
    required this.rightTitle,
    required this.rightValue,
    required this.rightColor,
  });

  final String leftTitle;
  final String leftValue;
  final Color leftColor;
  final String rightTitle;
  final String rightValue;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: leftTitle,
            value: leftValue,
            color: leftColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: rightTitle,
            value: rightValue,
            color: rightColor,
          ),
        ),
      ],
    );
  }
}
