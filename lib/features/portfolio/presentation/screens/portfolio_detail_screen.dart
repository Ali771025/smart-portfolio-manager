import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/portfolio_chart_models.dart';
import '../providers/portfolio_chart_providers.dart';

class PortfolioDetailScreen extends ConsumerWidget {
  const PortfolioDetailScreen({super.key, required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPnl = ref.watch(portfolioPnLSummaryProvider(portfolioId));
    final asyncHoldings = ref.watch(portfolioHoldingsProvider(portfolioId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(portfolioPnLSummaryProvider(portfolioId));
          ref.invalidate(portfolioHoldingsProvider(portfolioId));
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(pinned: true, title: Text('جزئیات پرتفوی')),
            asyncPnl.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator.adaptive())),
              error: (e, _) => const SliverFillRemaining(
                  child: Center(child: Text('خطا در دریافت اطلاعات'))),
              data: (data) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList.list(children: [
                    _PortfolioToolsCard(portfolioId: portfolioId),
                    const SizedBox(height: 12),
                    _PnLSummaryCard(pnl: data),
                  ]),
                );
              },
            ),
            asyncHoldings.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator.adaptive())),
              error: (e, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (data) {
                if (data.holdings.isEmpty) {
                  return const SliverFillRemaining(
                      child: Center(child: Text('هیچ دارایی‌ای یافت نشد.')));
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverList.builder(
                      itemCount: data.holdings.length,
                      itemBuilder: (_, i) =>
                          _HoldingTile(holding: data.holdings[i])),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _PortfolioToolsCard extends StatelessWidget {
  const _PortfolioToolsCard({required this.portfolioId});

  final String portfolioId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToolButton(
              icon: Icons.show_chart_rounded,
              label: 'نمودارها',
              onPressed: () => context.push('/portfolios/$portfolioId/charts'),
            ),
            _ToolButton(
              icon: Icons.summarize_rounded,
              label: 'گزارش‌ها',
              onPressed: () => context.push('/portfolios/$portfolioId/reports'),
            ),
            _ToolButton(
              icon: Icons.analytics_rounded,
              label: 'تحلیل نماد',
              onPressed: () =>
                  context.push('/portfolios/$portfolioId/symbol-analytics'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _PnLSummaryCard extends StatelessWidget {
  const _PnLSummaryCard({required this.pnl});
  final PortfolioPnLSummary pnl;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPnlColor = pnl.totalPnl >= 0 ? Colors.green : scheme.error;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded,
                      color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('ارزش کل پرتفوی',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                          NumberFormat.currency(
                                  locale: 'fa_IR',
                                  symbol: 'ریال ',
                                  decimalDigits: 0)
                              .format(pnl.totalCurrentValue),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900)),
                    ])),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _MetricChip(
                    label: 'سود/زیان کل',
                    value: NumberFormat.currency(
                            locale: 'fa_IR', symbol: 'ریال ', decimalDigits: 0)
                        .format(pnl.totalPnl),
                    color: totalPnlColor),
                const SizedBox(width: 8),
                _MetricChip(
                    label: 'بازدهی',
                    value: '${pnl.roiPercent.toStringAsFixed(2)}٪',
                    color: pnl.roiPercent >= 0 ? Colors.green : scheme.error),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _MetricChip(
                    label: 'تحقق‌شده',
                    value: NumberFormat.currency(
                            locale: 'fa_IR', symbol: 'ریال ', decimalDigits: 0)
                        .format(pnl.totalRealizedPnl),
                    color: pnl.totalRealizedPnl >= 0
                        ? Colors.green
                        : scheme.error),
                const SizedBox(width: 8),
                _MetricChip(
                    label: 'تحقق‌نشده',
                    value: NumberFormat.currency(
                            locale: 'fa_IR', symbol: 'ریال ', decimalDigits: 0)
                        .format(pnl.totalUnrealizedPnl),
                    color: pnl.totalUnrealizedPnl >= 0
                        ? Colors.green
                        : scheme.error),
              ]),
              if (pnl.stalePriceAssets.isNotEmpty ||
                  pnl.missingPriceAssets.isNotEmpty) ...[
                const Divider(height: 20),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withAlpha(60))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pnl.stalePriceAssets.isNotEmpty)
                            Text(
                                'داده قدیمی: ${pnl.stalePriceAssets.join(', ')}',
                                style: const TextStyle(
                                    color: Colors.orange, fontSize: 12)),
                          if (pnl.missingPriceAssets.isNotEmpty)
                            Text(
                                'قیمت ناموجود: ${pnl.missingPriceAssets.join(', ')}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                        ])),
              ],
              const SizedBox(height: 8),
              _QualityLine(status: pnl.dataQualityStatus),
              if (pnl.asOfTimestamp != null) ...[
                const SizedBox(height: 8),
                Text(
                    'آخرین به‌روزرسانی: ${DateFormat('yyyy/MM/dd HH:mm').format(pnl.asOfTimestamp!)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant))
              ],
            ])));
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding});
  final PortfolioHoldingItem holding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fintech = context.fintechColors;
    final isMissingMarketPrice = holding.missingPrice ||
        holding.priceStatus == 'missing_price' ||
        holding.priceStatus == 'missing_market_price';
    final selectedPrice = isMissingMarketPrice
        ? null
        : holding.selectedValuationPrice ??
            holding.currentPrice ??
            holding.lastPrice ??
            holding.closingPrice;
    final backendPnl = holding.unrealizedPnl;
    final pnlColor = (backendPnl ?? 0) >= 0 ? fintech.pnlSuccess : scheme.error;
    final money =
        NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: pnlColor.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Text(
                  holding.tickerSymbol.characters.first,
                  style:
                      TextStyle(color: pnlColor, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(holding.tickerSymbol,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (holding.isStale ||
                        holding.priceStatus == 'stale_price') ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.orange),
                    ],
                    if (isMissingMarketPrice) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.red),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${holding.quantity.toInt()} سهم | میانگین ${money.format(holding.weightedAvgCost)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _TinyBadge(
                          'آخرین: ${_moneyOrMissing(money, holding.lastPrice)}'),
                      _TinyBadge(
                          'پایانی: ${_moneyOrMissing(money, holding.closingPrice)}'),
                      _TinyBadge(
                          'ارزش بازار: ${_moneyOrMissing(money, holding.currentValue)}'),
                      _TinyBadge(
                          'بهای تمام‌شده: ${_moneyOrMissing(money, holding.totalCostBasis)}'),
                      _TinyBadge(
                          'منبع: ${_priceSourceLabel(holding.selectedPriceSource)}'),
                      if (isMissingMarketPrice)
                        const _TinyBadge('قیمت روز در دسترس نیست'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  selectedPrice == null
                      ? 'قیمت روز در دسترس نیست'
                      : money.format(selectedPrice),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                if (backendPnl != null)
                  Text(
                    '${backendPnl >= 0 ? '+' : ''}${money.format(backendPnl)}',
                    style:
                        TextStyle(color: pnlColor, fontWeight: FontWeight.w800),
                  ),
                if (holding.unrealizedPnlPct != null)
                  Text(
                    '${holding.unrealizedPnlPct!.toStringAsFixed(1)}٪',
                    style:
                        TextStyle(color: pnlColor, fontWeight: FontWeight.w800),
                  ),
                if (holding.priceAsOf != null)
                  Text(
                    DateFormat('HH:mm', 'fa_IR')
                        .format(holding.priceAsOf!.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityLine extends StatelessWidget {
  const _QualityLine({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = status.toLowerCase().contains('stale') ||
        status.toLowerCase().contains('missing');
    final color = stale ? Colors.orange : Colors.green;
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          'کیفیت داده: $status',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: stale ? color : scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainerHighest,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

String _moneyOrMissing(NumberFormat formatter, double? value) {
  if (value == null || !value.isFinite || value <= 0) return 'ناموجود';
  return formatter.format(value);
}

String _priceSourceLabel(String value) {
  return switch (value) {
    'last_price' => 'آخرین',
    'closing_price' => 'پایانی',
    'adjusted_close' => 'تعدیل‌شده',
    'fallback' => 'جایگزین',
    'missing' => 'ناموجود',
    _ => value,
  };
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(60))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ])));
  }
}
