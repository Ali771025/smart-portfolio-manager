import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/watchlist_repository.dart';
import '../../domain/models/watchlist_models.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  var _loading = true;
  String? _error;
  String? _selectedWatchlistId;
  List<Watchlist> _watchlists = const [];
  List<AlertRule> _alerts = const [];
  AlertSummaryResponse? _summary;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final repository = ref.read(watchlistRepositoryProvider);
    final watchlistsResult = await repository.listWatchlists();
    final alertsResult = await repository.listAlertRules();
    final summaryResult = await repository.getAlertSummary();

    if (!mounted) return;

    String? error;
    final watchlists = watchlistsResult.fold((failure) {
      error = failure.message;
      return const <Watchlist>[];
    }, (items) => items);
    final alerts = alertsResult.fold((failure) {
      error ??= failure.message;
      return const <AlertRule>[];
    }, (items) => items);
    final summary = summaryResult.fold((failure) {
      error ??= failure.message;
      return null;
    }, (value) => value);

    setState(() {
      _watchlists = watchlists;
      _alerts = alerts;
      _summary = summary;
      _selectedWatchlistId =
          _resolveSelectedWatchlistId(watchlists, _selectedWatchlistId);
      _error = error;
      _loading = false;
    });
  }

  String? _resolveSelectedWatchlistId(
    List<Watchlist> watchlists,
    String? previous,
  ) {
    if (previous != null && watchlists.any((item) => item.id == previous)) {
      return previous;
    }
    return watchlists.isEmpty ? null : watchlists.first.id;
  }

  Watchlist? get _selectedWatchlist {
    final id = _selectedWatchlistId;
    if (id == null) return null;
    for (final item in _watchlists) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('دیده‌بان'),
        actions: [
          IconButton(
            tooltip: 'به‌روزرسانی',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'لیست جدید',
            onPressed: _loading ? null : _showCreateWatchlistDialog,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ...[
              _ErrorBanner(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            _SummaryBand(summary: _summary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _watchlists)
                  ChoiceChip(
                    label: Text(item.name),
                    selected: item.id == _selectedWatchlistId,
                    onSelected: (_) {
                      setState(() => _selectedWatchlistId = item.id);
                    },
                  ),
              ],
            ),
            if (_watchlists.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'هیچ دیده‌بانی ثبت نشده است.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            if (_selectedWatchlist != null) ...[
              const SizedBox(height: 16),
              _WatchlistToolbar(
                watchlist: _selectedWatchlist!,
                onAddSymbol: _showAddSymbolDialog,
                onCreateAlert: _showCreateAlertDialog,
                onDelete: () => _deleteWatchlist(_selectedWatchlist!),
              ),
              const SizedBox(height: 12),
              _SymbolList(
                symbols: _selectedWatchlist!.symbols,
                onRemove: (symbol) => _removeSymbol(_selectedWatchlist!, symbol),
              ),
            ],
            const SizedBox(height: 20),
            Text('هشدارها', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_alerts.isEmpty)
              const _EmptyPanel(text: 'قانون هشدار فعالی ثبت نشده است.')
            else
              for (final alert in _alerts)
                _AlertTile(
                  alert: alert,
                  onDelete: () => _deleteAlert(alert),
                ),
            const SizedBox(height: 20),
            Text('رویدادهای اخیر', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if ((_summary?.recentEvents ?? const <AlertEvent>[]).isEmpty)
              const _EmptyPanel(text: 'رویداد جدیدی وجود ندارد.')
            else
              for (final event in _summary!.recentEvents)
                _EventTile(event: event),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateWatchlistDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لیست جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'نام'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'توضیح'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ایجاد'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    if (created != true || name.isEmpty) return;

    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.createWatchlist(
      name: name,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
    );
    if (!mounted) return;
    result.fold(
      (failure) => _showSnack(failure.message),
      (watchlist) {
        _selectedWatchlistId = watchlist.id;
        _load();
      },
    );
  }

  Future<void> _showAddSymbolDialog() async {
    final watchlist = _selectedWatchlist;
    if (watchlist == null) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن نماد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'نماد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
    final symbol = controller.text.trim().toUpperCase();
    if (confirmed != true || symbol.isEmpty) return;
    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.updateWatchlistSymbols(
      watchlistId: watchlist.id,
      addSymbols: [symbol],
    );
    if (!mounted) return;
    result.fold((failure) => _showSnack(failure.message), (_) => _load());
  }

  Future<void> _removeSymbol(Watchlist watchlist, WatchlistSymbol symbol) async {
    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.updateWatchlistSymbols(
      watchlistId: watchlist.id,
      removeSymbols: [symbol.symbol],
    );
    if (!mounted) return;
    result.fold((failure) => _showSnack(failure.message), (_) => _load());
  }

  Future<void> _deleteWatchlist(Watchlist watchlist) async {
    final confirmed = await _confirm('حذف ${watchlist.name}؟');
    if (confirmed != true) return;
    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.deleteWatchlist(watchlistId: watchlist.id);
    if (!mounted) return;
    result.fold((failure) => _showSnack(failure.message), (_) => _load());
  }

  Future<void> _showCreateAlertDialog() async {
    final symbolController = TextEditingController(
      text: _selectedWatchlist?.symbols.isNotEmpty == true
          ? _selectedWatchlist!.symbols.first.symbol
          : '',
    );
    final thresholdController = TextEditingController();
    var alertType = 'PRICE_ABOVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('هشدار جدید'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: symbolController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'نماد'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: alertType,
                decoration: const InputDecoration(labelText: 'نوع هشدار'),
                items: const [
                  DropdownMenuItem(
                    value: 'PRICE_ABOVE',
                    child: Text('قیمت بالاتر از'),
                  ),
                  DropdownMenuItem(
                    value: 'PRICE_BELOW',
                    child: Text('قیمت پایین‌تر از'),
                  ),
                  DropdownMenuItem(
                    value: 'VOLUME_ABOVE',
                    child: Text('حجم بالاتر از'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => alertType = value);
                  }
                },
              ),
              TextField(
                controller: thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'آستانه'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ایجاد'),
            ),
          ],
        ),
      ),
    );
    final symbol = symbolController.text.trim().toUpperCase();
    final threshold = double.tryParse(thresholdController.text.trim());
    if (confirmed != true || symbol.isEmpty || threshold == null) return;

    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.createAlertRule(
      symbol: symbol,
      alertType: alertType,
      threshold: threshold,
    );
    if (!mounted) return;
    result.fold((failure) => _showSnack(failure.message), (_) => _load());
  }

  Future<void> _deleteAlert(AlertRule alert) async {
    final confirmed = await _confirm('حذف هشدار ${alert.symbol}؟');
    if (confirmed != true) return;
    final repository = ref.read(watchlistRepositoryProvider);
    final result = await repository.deleteAlertRule(ruleId: alert.id);
    if (!mounted) return;
    result.fold((failure) => _showSnack(failure.message), (_) => _load());
  }

  Future<bool?> _confirm(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.summary});

  final AlertSummaryResponse? summary;

  @override
  Widget build(BuildContext context) {
    final data = summary?.summary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricChip(
          icon: Icons.notifications_active_rounded,
          label: 'فعال',
          value: '${data?.totalActiveAlerts ?? 0}',
        ),
        _MetricChip(
          icon: Icons.today_rounded,
          label: 'امروز',
          value: '${data?.totalTriggeredToday ?? 0}',
        ),
        _MetricChip(
          icon: Icons.mark_email_unread_rounded,
          label: 'تأییدنشده',
          value: '${data?.totalUnacknowledged ?? 0}',
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
    );
  }
}

class _WatchlistToolbar extends StatelessWidget {
  const _WatchlistToolbar({
    required this.watchlist,
    required this.onAddSymbol,
    required this.onCreateAlert,
    required this.onDelete,
  });

  final Watchlist watchlist;
  final VoidCallback onAddSymbol;
  final VoidCallback onCreateAlert;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                watchlist.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${watchlist.symbolCount} نماد'),
            ],
          ),
        ),
        IconButton(
          tooltip: 'افزودن نماد',
          onPressed: onAddSymbol,
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        IconButton(
          tooltip: 'هشدار جدید',
          onPressed: onCreateAlert,
          icon: const Icon(Icons.add_alert_rounded),
        ),
        IconButton(
          tooltip: 'حذف لیست',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}

class _SymbolList extends StatelessWidget {
  const _SymbolList({
    required this.symbols,
    required this.onRemove,
  });

  final List<WatchlistSymbol> symbols;
  final ValueChanged<WatchlistSymbol> onRemove;

  @override
  Widget build(BuildContext context) {
    if (symbols.isEmpty) {
      return const _EmptyPanel(text: 'نمادی در این لیست نیست.');
    }
    return Column(
      children: [
        for (final symbol in symbols)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(symbol.symbol.isEmpty ? '?' : symbol.symbol[0]),
              ),
              title: Text(symbol.symbol),
              subtitle: Text(symbol.nameFa ?? symbol.nameEn ?? 'بدون نام'),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_formatPrice(symbol.currentPrice)),
                  _ChangeBadge(value: symbol.priceChangePct),
                  IconButton(
                    tooltip: 'حذف نماد',
                    onPressed: () => onRemove(symbol),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onDelete,
  });

  final AlertRule alert;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.notifications_rounded),
        title: Text('${alert.symbol} - ${_alertTypeLabel(alert.alertType)}'),
        subtitle: Text('آستانه ${_formatPrice(alert.threshold)}'),
        trailing: IconButton(
          tooltip: 'حذف هشدار',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final AlertEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(
          event.isAcknowledged
              ? Icons.mark_email_read_rounded
              : Icons.mark_email_unread_rounded,
        ),
        title: Text('${event.symbol} - ${_alertTypeLabel(event.alertType)}'),
        subtitle: Text('قیمت ${_formatPrice(event.priceAtTrigger)}'),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return const Text('ناموجود');
    final color = value >= 0 ? Colors.green : Colors.red;
    return Text(
      '${value.toStringAsFixed(2)}%',
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: Text(message),
        trailing: IconButton(
          tooltip: 'تلاش دوباره',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text)),
    );
  }
}

String _formatPrice(double? value) {
  if (value == null) return 'ناموجود';
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

String _alertTypeLabel(String value) {
  return switch (value) {
    'PRICE_ABOVE' => 'قیمت بالاتر از',
    'PRICE_BELOW' => 'قیمت پایین‌تر از',
    'VOLUME_ABOVE' => 'حجم بالاتر از',
    'VOLUME_BELOW' => 'حجم پایین‌تر از',
    'PRICE_CHANGE_PCT_ABOVE' => 'رشد درصدی',
    'PRICE_CHANGE_PCT_BELOW' => 'افت درصدی',
    _ => value,
  };
}
