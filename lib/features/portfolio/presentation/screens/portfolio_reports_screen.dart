import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/portfolio_chart_models.dart';
import '../providers/portfolio_chart_providers.dart';

class PortfolioReportsScreen extends ConsumerWidget {
  const PortfolioReportsScreen({super.key, required this.portfolioId});
  final String portfolioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => const [
            SliverAppBar(pinned: true, title: Text('گزارش‌ها'), bottom: TabBar(tabs: [Tab(text: 'گزارش ماهانه'), Tab(text: 'گزارش سالانه')])),
          ],
          body: TabBarView(children: [_MonthlyReportTab(portfolioId: portfolioId), _YearlyReportTab(portfolioId: portfolioId)]),
        ),
      ),
    );
  }
}

class _MonthlyReportTab extends ConsumerWidget {
  const _MonthlyReportTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final asyncData = ref.watch(monthlyPortfolioReportProvider((
      portfolioId: portfolioId,
      year: now.year,
      month: now.month,
    )));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        final monthly = data.monthlyReturns;
        final nonNull = monthly.where((m) => m.returnPct != null).toList();
        final avgReturn = nonNull.isNotEmpty
            ? nonNull.map((m) => m.returnPct!).reduce((a, b) => a + b) /
                nonNull.length
            : 0.0;
        return ListView(padding: const EdgeInsets.all(16), children: [
          _ReportSummaryCard(
            title: 'گزارش ماهانه ${data.year}/${data.month.toString().padLeft(2, '0')}',
            performance: data.performance,
            dataCompleteness: data.dataCompleteness,
            isStale: data.isStale,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatTile(
                    title: 'میانگین ماه‌ها',
                    value: '${avgReturn.toStringAsFixed(2)}٪',
                  ),
                  _StatTile(title: 'تعداد نقاط', value: '${monthly.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (monthly.isEmpty) const Center(child: Text('داده‌ای موجود نیست.')),
          ...monthly.map((m) {
            final ret = m.returnPct;
            final color = ret != null ? (ret >= 0 ? Colors.green : Theme.of(context).colorScheme.error) : Theme.of(context).colorScheme.onSurfaceVariant;
            return Card(child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withAlpha(20),
                child: Text(
                  _monthBadge(m.label),
                  style: TextStyle(color: color),
                ),
              ),
              title: Text(m.label),
              trailing: ret != null ? Text('${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}٪', style: TextStyle(color: color, fontWeight: FontWeight.bold)) : const Text('—'),
            ));
          }),
        ]);
      },
    );
  }
}

class _YearlyReportTab extends ConsumerWidget {
  const _YearlyReportTab({required this.portfolioId});
  final String portfolioId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final asyncData = ref.watch(yearlyPortfolioReportProvider((
      portfolioId: portfolioId,
      year: year,
    )));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('خطا: $e')),
      data: (data) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          _ReportSummaryCard(
            title: 'گزارش سالانه ${data.year}',
            performance: data.performance,
            dataCompleteness: data.dataCompleteness,
            isStale: data.isStale,
          ),
          const SizedBox(height: 16),
          if (data.monthlyBreakdown.isEmpty)
            const Center(child: Text('داده‌ای موجود نیست.')),
          ...data.monthlyBreakdown.map((m) {
            final ret = m.returnPct;
            final color = ret != null
                ? (ret >= 0 ? Colors.green : Theme.of(context).colorScheme.error)
                : Theme.of(context).colorScheme.onSurfaceVariant;
            return Card(
              child: ListTile(
                title: Text(m.label),
                subtitle: m.endingValue != null
                    ? Text(_money(m.endingValue!))
                    : null,
                trailing: ret != null
                    ? Text(
                        '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}٪',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text('—'),
              ),
            );
          }),
        ]);
      },
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.title,
    required this.performance,
    required this.dataCompleteness,
    required this.isStale,
  });

  final String title;
  final ReportPeriodPerformance performance;
  final String dataCompleteness;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final returnPct = performance.totalReturnPct;
    final returnColor = (returnPct ?? 0) >= 0 ? Colors.green : scheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isStale)
                  const Icon(Icons.access_time_rounded, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatTile(
                  title: 'ارزش شروع',
                  value: performance.startingValue != null
                      ? _money(performance.startingValue!)
                      : '—',
                ),
                _StatTile(
                  title: 'ارزش پایان',
                  value: performance.endingValue != null
                      ? _money(performance.endingValue!)
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatTile(
                  title: 'سود/زیان کل',
                  value: performance.totalPnl != null
                      ? _money(performance.totalPnl!)
                      : '—',
                ),
                _StatTile(
                  title: 'بازدهی',
                  value: returnPct != null
                      ? '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}٪'
                      : '—',
                  color: returnColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'کیفیت داده: $dataCompleteness',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value, this.color});
  final String title;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [Text(title, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))]));
  }
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'fa_IR',
    symbol: 'ریال ',
    decimalDigits: 0,
  ).format(value);
}

String _monthBadge(String label) {
  if (label.length >= 2) {
    return label.substring(label.length - 2);
  }
  return label.isEmpty ? '—' : label;
}
