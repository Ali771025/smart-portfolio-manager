import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_failure.dart';
import '../../data/market_repository.dart';
import '../../domain/models/market_models.dart';
import '../providers/market_controller.dart';
import '../widgets/market_status_indicator.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  late final TextEditingController _symbolController;
  final List<String> _indexCodes = const ['TEDPIX', 'TEP10', 'IFX'];
  List<MarketDisclosure> _disclosures = const [];
  AppFailure? _disclosuresError;
  bool _disclosuresLoading = true;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: 'فولاد');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketLiveControllerProvider.notifier).fetchOverviewAndWatch();
      ref.read(marketStatusControllerProvider.notifier).startPeriodicRefresh();
      ref.read(marketIndexControllerProvider.notifier).fetchIndices();
      _fetchDisclosures();
    });
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(marketLiveControllerProvider);
    final statusState = ref.watch(marketStatusControllerProvider);
    final historyState = ref.watch(marketHistoryControllerProvider);
    final indices = ref.watch(marketIndexControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          await ref.read(marketStatusControllerProvider.notifier).fetchStatus();
          await ref
              .read(marketLiveControllerProvider.notifier)
              .fetchOverviewAndWatch();
          await ref.read(marketIndexControllerProvider.notifier).fetchIndices();
          await _fetchDisclosures();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('بازار'),
              actions: const [
                Padding(
                  padding: EdgeInsetsDirectional.only(end: 12),
                  child: Center(child: MarketStatusIndicator()),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  _StatusCard(state: statusState),
                  const SizedBox(height: 12),
                  _OverviewCard(
                    overview: liveState.overview,
                    isLoading: liveState.isLoading,
                    error: liveState.error,
                  ),
                  const SizedBox(height: 12),
                  _IndexSection(
                    indices: indices,
                    indexCodes: _indexCodes,
                    onRefresh: (code) => ref
                        .read(marketIndexControllerProvider.notifier)
                        .fetchIndex(code),
                  ),
                  const SizedBox(height: 12),
                  _DisclosureSection(
                    items: _disclosures,
                    isLoading: _disclosuresLoading,
                    error: _disclosuresError,
                    onRetry: _fetchDisclosures,
                    onOpen: _openDisclosure,
                  ),
                  const SizedBox(height: 12),
                  _MarketWatchCard(
                    response: liveState.watch,
                    isLoading: liveState.isLoading,
                    error: liveState.error,
                    onRefresh: () => ref
                        .read(marketLiveControllerProvider.notifier)
                        .fetchOverviewAndWatch(),
                  ),
                  const SizedBox(height: 12),
                  _HistoryCard(
                    symbolController: _symbolController,
                    state: historyState,
                    onFetch: _fetchHistory,
                    onClear: () => ref
                        .read(marketHistoryControllerProvider.notifier)
                        .clear(),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchHistory() async {
    final symbol = _symbolController.text.trim();
    if (symbol.isEmpty) return;
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 90));
    await ref.read(marketHistoryControllerProvider.notifier).fetchHistory(
          symbol: symbol,
          startDate: start,
          endDate: end,
        );
  }

  Future<void> _fetchDisclosures() async {
    if (mounted) {
      setState(() {
        _disclosuresLoading = true;
        _disclosuresError = null;
      });
    }
    final result = await ref.read(marketRepositoryProvider).getDisclosures();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _disclosuresLoading = false;
        _disclosuresError = failure;
      }),
      (items) => setState(() {
        _disclosuresLoading = false;
        _disclosures = items;
        _disclosuresError = null;
      }),
    );
  }

  Future<void> _openDisclosure(MarketDisclosure item) async {
    final result = await ref.read(marketRepositoryProvider).getDisclosure(
          trackingNumber: item.trackingNumber,
        );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (detail) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _DisclosureDetailSheet(item: detail),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.overview,
    required this.isLoading,
    required this.error,
  });

  final MarketOverview? overview;
  final bool isLoading;
  final AppFailure? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = overview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_rounded),
                const SizedBox(width: 8),
                Text('نمای کلی بازار',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null && item == null)
              Text(error!.message, style: TextStyle(color: scheme.error))
            else if (item == null)
              Text(
                'داده نمای کلی بازار از بک‌اند دریافت نشده است.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OverviewMetric(
                      label: 'شاخص کل',
                      value: _nullableNumber(item.totalIndexValue),
                      change: item.totalIndexChange),
                  _OverviewMetric(
                      label: 'هم‌وزن',
                      value: _nullableNumber(item.equalWeightIndexValue),
                      change: item.equalWeightIndexChange),
                  _OverviewMetric(
                      label: 'ارزش بازار',
                      value: _nullableMoney(item.marketValue)),
                  _OverviewMetric(
                      label: 'تعداد معاملات',
                      value: _nullableInt(item.tradesCount)),
                  _OverviewMetric(
                      label: 'ارزش معاملات',
                      value: _nullableMoney(item.tradesValue)),
                  _OverviewMetric(
                      label: 'حجم معاملات',
                      value: _nullableNumber(item.tradesVolume)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: item.marketStatus == 'open'
                        ? 'بازار باز'
                        : 'بازار بسته',
                    icon: item.marketStatus == 'open'
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: item.marketStatus == 'open'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  _InfoChip(
                    label: item.isCurrentSession
                        ? 'جلسه جاری'
                        : 'آخرین جلسه معاملاتی',
                    icon: item.isCurrentSession
                        ? Icons.flash_on_rounded
                        : Icons.history_rounded,
                    color: item.isCurrentSession ? Colors.green : Colors.orange,
                  ),
                  _InfoChip(
                    label: 'کیفیت: ${item.dataQualityStatus}',
                    icon: Icons.verified_rounded,
                    color: item.isStale ? Colors.orange : Colors.green,
                  ),
                ],
              ),
              if (item.priceInfoTimestamp != null) ...[
                const SizedBox(height: 8),
                Text(
                  'زمان اطلاعات قیمت: ${_dateTime(item.priceInfoTimestamp!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    this.change,
  });

  final String label;
  final String value;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final changeValue = change;
    final changeColor = changeValue == null
        ? scheme.onSurfaceVariant
        : changeValue >= 0
            ? Colors.green
            : scheme.error;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (changeValue != null) ...[
            const SizedBox(height: 4),
            Text(
              '${changeValue >= 0 ? '+' : ''}${_number(changeValue)}',
              style: TextStyle(color: changeColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketWatchCard extends StatelessWidget {
  const _MarketWatchCard({
    required this.response,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  final MarketWatchResponse? response;
  final bool isLoading;
  final AppFailure? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final watch = response;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_list_rounded),
                const SizedBox(width: 8),
                Text('دیده‌بان بازار',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'به‌روزرسانی دیده‌بان',
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (watch != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: 'کیفیت: ${watch.dataQualityStatus}',
                    icon: Icons.storage_rounded,
                    color: watch.isStale ? Colors.orange : Colors.green,
                  ),
                  _InfoChip(
                    label: watch.isCurrentSession ? 'جلسه جاری' : 'آخرین جلسه',
                    icon: Icons.schedule_rounded,
                    color:
                        watch.isCurrentSession ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (isLoading && watch == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && watch == null)
              Text(error!.message, style: TextStyle(color: scheme.error))
            else if (watch == null || watch.items.isEmpty)
              Text(
                'داده دیده‌بان بازار موجود نیست.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...watch.items.take(12).map(_MarketWatchTile.new),
          ],
        ),
      ),
    );
  }
}

class _MarketWatchTile extends StatelessWidget {
  const _MarketWatchTile(this.quote);

  final MarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = quote.priceChangePercent ?? quote.priceChange ?? 0;
    final color = change >= 0 ? Colors.green : scheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Text(
          _firstChar(quote.symbol),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(quote.symbol)),
          if (quote.isStale)
            const Icon(Icons.access_time_rounded,
                size: 15, color: Colors.orange),
        ],
      ),
      subtitle: Text(
        'حجم: ${_nullableNumber(quote.volume)} • ${quote.source.isEmpty ? 'backend' : quote.source}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_nullableMoney(quote.lastPrice ?? quote.closingPrice)),
          Text(
            quote.priceChangePercent == null
                ? _nullableNumber(quote.priceChange)
                : '${quote.priceChangePercent! >= 0 ? '+' : ''}${quote.priceChangePercent!.toStringAsFixed(2)}٪',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DisclosureSection extends StatelessWidget {
  const _DisclosureSection({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onOpen,
  });

  final List<MarketDisclosure> items;
  final bool isLoading;
  final AppFailure? error;
  final Future<void> Function() onRetry;
  final ValueChanged<MarketDisclosure> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined),
                const SizedBox(width: 8),
                Text('اطلاعیه‌های کدال',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'به‌روزرسانی اطلاعیه‌ها',
                  onPressed: isLoading ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!.message)),
                    IconButton(
                      tooltip: 'تلاش دوباره',
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'اطلاعیه‌ای ثبت نشده است.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...items.take(8).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => onOpen(item),
                      leading: CircleAvatar(
                        child: Text(_firstChar(item.symbol)),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.symbol} • ${_disclosureDate(item.publishedAt)}',
                      ),
                      trailing: item.hasAttachment
                          ? const Icon(Icons.attach_file_rounded)
                          : const Icon(Icons.chevron_left_rounded),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureDetailSheet extends StatelessWidget {
  const _DisclosureDetailSheet({required this.item});

  final MarketDisclosure item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DisclosureDetailRow(label: 'نماد', value: item.symbol),
            _DisclosureDetailRow(
              label: 'شرکت',
              value: item.companyName ?? 'نامشخص',
            ),
            _DisclosureDetailRow(
              label: 'کد نامه',
              value: item.letterCode ?? 'نامشخص',
            ),
            _DisclosureDetailRow(
              label: 'زمان انتشار',
              value: _disclosureDate(item.publishedAt),
            ),
            _DisclosureDetailRow(
              label: 'شماره پیگیری',
              value: item.trackingNumber,
            ),
            if (item.url != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                item.url!,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisclosureDetailRow extends StatelessWidget {
  const _DisclosureDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _disclosureDate(DateTime? value) {
  if (value == null) return 'زمان نامشخص';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final MarketStatusState state;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final error = state.error;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded),
                const SizedBox(width: 8),
                Text(
                  'وضعیت بازار',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (state.isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error.message, style: TextStyle(color: scheme.error))
            else if (status == null)
              Text(
                'برای دریافت وضعیت بازار، صفحه را به‌روزرسانی کنید.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: status.isMarketOpen ? 'بازار باز' : 'بازار بسته',
                    icon: status.isMarketOpen
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: status.isMarketOpen ? Colors.green : Colors.orange,
                  ),
                  _InfoChip(
                    label: status.isTradingDay ? 'روز معاملاتی' : 'تعطیل',
                    icon: Icons.calendar_today_rounded,
                    color: status.isTradingDay ? Colors.blue : Colors.grey,
                  ),
                  _InfoChip(
                    label: 'دریافت‌کننده: ${status.providerStatusLabel}',
                    icon: Icons.dns_rounded,
                    color: status.isHealthy ? Colors.green : Colors.red,
                  ),
                  _InfoChip(
                    label: status.freshnessDescription,
                    icon: Icons.update_rounded,
                    color: status.isStale ? Colors.orange : Colors.green,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _IndexSection extends StatelessWidget {
  const _IndexSection({
    required this.indices,
    required this.indexCodes,
    required this.onRefresh,
  });

  final Map<String, IndexSnapshot> indices;
  final List<String> indexCodes;
  final ValueChanged<String> onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stacked_line_chart_rounded),
                const SizedBox(width: 8),
                Text('شاخص‌ها', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final code in indexCodes)
              _IndexTile(
                code: code,
                snapshot: indices[code],
                onRefresh: () => onRefresh(code),
              ),
          ],
        ),
      ),
    );
  }
}

class _IndexTile extends StatelessWidget {
  const _IndexTile({
    required this.code,
    required this.snapshot,
    required this.onRefresh,
  });

  final String code;
  final IndexSnapshot? snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    final changeValue = current?.changeValue ?? 0;
    final color =
        changeValue >= 0 ? Colors.green : Theme.of(context).colorScheme.error;
    final title = current == null || current.name.trim().isEmpty
        ? code
        : current.name.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: current == null
          ? const Text('داده‌ای دریافت نشده است.')
          : Text('حجم: ${_intFormat(current.volume)}'),
      trailing: current == null
          ? IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _number(current.lastValue),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${current.changePercent >= 0 ? '+' : ''}${current.changePercent.toStringAsFixed(2)}٪',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.symbolController,
    required this.state,
    required this.onFetch,
    required this.onClear,
  });

  final TextEditingController symbolController;
  final AsyncValue<SymbolHistory?> state;
  final VoidCallback onFetch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded),
                const SizedBox(width: 8),
                Text('تاریخچه نماد',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'نماد',
                suffixIcon: IconButton(
                  onPressed: onFetch,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onSubmitted: (_) => onFetch(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : onFetch,
                    icon: const Icon(Icons.timeline_rounded),
                    label: const Text('۹۰ روز اخیر'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('پاک کردن'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            state.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (history) {
                if (history == null) {
                  return Text(
                    'نماد را وارد کنید تا تاریخچه قیمت از بک‌اند دریافت شود.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                if (history.bars.isEmpty) {
                  return const Text('داده تاریخی موجود نیست.');
                }
                return Column(
                  children: [
                    _HistorySummary(history: history),
                    const SizedBox(height: 8),
                    ...history.bars.take(8).map(_PriceBarTile.new),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.history});

  final SymbolHistory history;

  @override
  Widget build(BuildContext context) {
    if (history.bars.isEmpty) {
      return const SizedBox.shrink();
    }

    final first = history.bars.first.closePrice;
    final last = history.bars.last.closePrice;
    final changePct = first > 0 ? ((last - first) / first) * 100 : 0.0;
    final color =
        changePct >= 0 ? Colors.green : Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${history.ticker} • ${history.count} کندل',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}٪',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PriceBarTile extends StatelessWidget {
  const _PriceBarTile(this.bar);

  final PriceBar bar;

  @override
  Widget build(BuildContext context) {
    final color = bar.closePrice >= bar.openPrice
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_date(bar.date)),
      subtitle: Text('حجم: ${_intFormat(bar.volume)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_money(bar.closePrice)),
          Text(
            'H ${_number(bar.highPrice)} / L ${_number(bar.lowPrice)}',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.32)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

String _money(double value) {
  return 'ریال ${_number(value)}';
}

String _number(double value) {
  if (!value.isFinite) return '0';
  final fixed = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return _groupDigits(fixed);
}

String _intFormat(int value) {
  return _groupDigits(value.toString());
}

String _nullableMoney(double? value) {
  if (value == null || !value.isFinite) return 'ناموجود';
  return _money(value);
}

String _nullableNumber(num? value) {
  if (value == null || !value.isFinite) return 'ناموجود';
  return _number(value.toDouble());
}

String _nullableInt(int? value) {
  if (value == null) return 'ناموجود';
  return _intFormat(value);
}

String _groupDigits(String input) {
  final parts = input.split('.');
  final sign = parts.first.startsWith('-') ? '-' : '';
  final digits = parts.first.replaceFirst('-', '');
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  final decimal = parts.length > 1 ? '.${parts[1]}' : '';
  return '$sign$buffer$decimal';
}

String _date(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year/$month/$day';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_date(local)} $hour:$minute';
}

String _firstChar(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1);
}
