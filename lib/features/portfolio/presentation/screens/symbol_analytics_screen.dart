import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/portfolio_chart_models.dart';
import '../providers/portfolio_chart_providers.dart';

class SymbolAnalyticsScreen extends ConsumerStatefulWidget {
  const SymbolAnalyticsScreen({super.key, required this.portfolioId});
  final String portfolioId;

  @override
  ConsumerState<SymbolAnalyticsScreen> createState() => _SymbolAnalyticsScreenState();
}

class _SymbolAnalyticsScreenState extends ConsumerState<SymbolAnalyticsScreen> {
  String? _selectedSymbol;

  @override
  Widget build(BuildContext context) {
    final asyncHoldings = ref.watch(portfolioHoldingsProvider(widget.portfolioId));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: asyncHoldings.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('خطا: $e')),
        data: (data) {
          if (data.holdings.isEmpty) return const Center(child: Text('هیچ دارایی‌ای یافت نشد.'));
          final symbols = data.holdings.map((h) => h.tickerSymbol).toList();
          if (_selectedSymbol == null || !symbols.contains(_selectedSymbol)) _selectedSymbol = symbols.first;
          return CustomScrollView(
            slivers: [
              const SliverAppBar(pinned: true, title: Text('تحلیل نماد')),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(children: [
                  DropdownButtonFormField<String>(initialValue: _selectedSymbol, isExpanded: true, items: symbols.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedSymbol = v), decoration: const InputDecoration(labelText: 'انتخاب نماد', border: OutlineInputBorder())),
                ]),
              ),
              if (_selectedSymbol != null) _SymbolAnalyticsBody(portfolioId: widget.portfolioId, symbol: _selectedSymbol!),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }
}

class _SymbolAnalyticsBody extends ConsumerWidget {
  const _SymbolAnalyticsBody({required this.portfolioId, required this.symbol});
  final String portfolioId;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(symbolAnalyticsProvider((portfolioId: portfolioId, symbol: symbol, period: '1Y', includeMonthly: true, includeBenchmark: false, benchmarkId: null)));
    return asyncData.when(
      loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator.adaptive())),
      error: (e, _) => SliverFillRemaining(child: Center(child: Text('خطا: $e'))),
      data: (data) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: [
            _PositionCard(position: data.position),
            if (data.returnSeries != null) ...[const SizedBox(height: 16), _ReturnSeriesCard(series: data.returnSeries!)],
            if (data.monthlyReturns != null && data.monthlyReturns!.monthlyReturns.isNotEmpty) ...[const SizedBox(height: 16), _MonthlyReturnsCard(data: data.monthlyReturns!)],
            if (data.benchmarkComparison != null) ...[const SizedBox(height: 16), _BenchmarkCard(comparison: data.benchmarkComparison!)],
            if (data.isStale || data.sanityFlags.isNotEmpty) ...[const SizedBox(height: 16), _FlagsBanner(isStale: data.isStale, flags: data.sanityFlags)],
          ]),
        );
      },
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position});
  final SymbolPositionInfo position;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pnlColor = (position.unrealizedPnl ?? 0) >= 0 ? Colors.green : scheme.error;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(position.tickerSymbol, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (position.priceStatus != 'ok') Icon(position.priceStatus == 'stale_price' ? Icons.access_time_rounded : Icons.warning_amber_rounded, color: position.priceStatus == 'stale_price' ? Colors.orange : Colors.red, size: 20),
      ]),
      if (position.assetName.isNotEmpty) ...[const SizedBox(height: 2), Text(position.assetName, style: Theme.of(context).textTheme.bodySmall)],
      const SizedBox(height: 12),
      Row(children: [
        _MiniMetric(label: 'تعداد', value: '${position.quantity.toInt()} سهم'),
        const SizedBox(width: 12),
        _MiniMetric(
          label: 'قیمت',
          value: position.currentPrice != null
              ? NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0)
                  .format(position.currentPrice)
              : 'ناموجود',
        ),
        const SizedBox(width: 12),
        _MiniMetric(label: 'میانگین', value: NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0).format(position.weightedAvgCost)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _MiniMetric(
          label: 'ارزش',
          value: position.currentValue != null
              ? NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0)
                  .format(position.currentValue)
              : 'ناموجود',
        ),
        const SizedBox(width: 12),
        _MiniMetric(label: 'سود/زیان', value: '${position.unrealizedPnl != null ? (position.unrealizedPnl! >= 0 ? '+' : '') : ''}${NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0).format(position.unrealizedPnl ?? 0)}', color: pnlColor),
        if (position.realizedPnl != 0) ...[const SizedBox(width: 12), _MiniMetric(label: 'تحقق‌یافته', value: NumberFormat.currency(locale: 'fa_IR', symbol: '', decimalDigits: 0).format(position.realizedPnl), color: position.realizedPnl >= 0 ? Colors.green : scheme.error)],
      ]),
    ])));
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
    ]));
  }
}

class _ReturnSeriesCard extends StatelessWidget {
  const _ReturnSeriesCard({required this.series});
  final SymbolReturnSeries series;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('سری بازدهی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (series.totalReturnPct != null) Text('بازدهی کل: ${series.totalReturnPct!.toStringAsFixed(2)}٪'),
      if (series.annualizedReturnPct != null) Text('بازدهی سالانه: ${series.annualizedReturnPct!.toStringAsFixed(2)}٪'),
      Text('تعداد نقاط: ${series.points.length}', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withAlpha(80), Colors.blue.withAlpha(80)]))),
    ])));
  }
}

class _MonthlyReturnsCard extends StatelessWidget {
  const _MonthlyReturnsCard({required this.data});
  final SymbolMonthlyReturns data;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('بازدهی ماهانه ${data.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...data.monthlyReturns.map((m) {
        final ret = m.returnPct;
        final color = ret != null ? (ret >= 0 ? Colors.green : Theme.of(context).colorScheme.error) : Theme.of(context).colorScheme.onSurfaceVariant;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
          SizedBox(width: 100, child: Text(m.monthLabel, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: ret != null ? LinearProgressIndicator(value: (ret.abs() / 20).clamp(0, 1).toDouble(), backgroundColor: color.withAlpha(30), valueColor: AlwaysStoppedAnimation(color)) : const LinearProgressIndicator(value: 0)),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(ret != null ? '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}٪' : '—', textAlign: TextAlign.end, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12))),
        ]));
      }),
    ])));
  }
}

class _BenchmarkCard extends StatelessWidget {
  const _BenchmarkCard({required this.comparison});
  final SymbolBenchmarkComparison comparison;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('مقایسه با ${comparison.benchmarkName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (comparison.excessReturnPct != null) Text('بازدهی اضافی: ${comparison.excessReturnPct!.toStringAsFixed(2)}٪'),
      if (comparison.beta != null) Text('بتا: ${comparison.beta!.toStringAsFixed(2)}'),
      if (comparison.correlation != null) Text('همبستگی: ${comparison.correlation!.toStringAsFixed(2)}'),
    ])));
  }
}

class _FlagsBanner extends StatelessWidget {
  const _FlagsBanner({required this.isStale, required this.flags});
  final bool isStale;
  final List<String> flags;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withAlpha(60))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isStale) const Text('داده قدیمی', style: TextStyle(color: Colors.orange)),
      ...flags.map((f) => Text(f, style: const TextStyle(fontSize: 12))),
    ]));
  }
}
