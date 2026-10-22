import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../domain/models/dashboard_state.dart';
import 'asset_allocation_chart.dart';
import 'dashboard_glass_card.dart';

class DashboardAssetHoldingsSection extends StatefulWidget {
  const DashboardAssetHoldingsSection({
    required this.assets,
    required this.currency,
    super.key,
    this.title = '۱۰ نماد دارایی برتر',
    this.subtitle = 'مرتب‌شده بر اساس ارزش روز دارایی در همه پرتفوی‌ها',
  });

  final List<DashboardAsset> assets;
  final String currency;
  final String title;
  final String subtitle;

  @override
  State<DashboardAssetHoldingsSection> createState() =>
      _DashboardAssetHoldingsSectionState();
}

class _DashboardAssetHoldingsSectionState
    extends State<DashboardAssetHoldingsSection> {
  static const int _defaultSortColumnIndex = 4;
  static const bool _defaultSortAscending = false;

  int _sortColumnIndex = 4;
  bool _sortAscending = false;
  bool _sortStateHydrated = false;
  bool _prefsHydrationStarted = false;
  bool _sortTouched = false;

  static const String _sortColumnStorageKey = 'dashboard_holdings_sort_column';
  static const String _sortAscendingStorageKey = 'dashboard_holdings_sort_ascending';
  static const String _sortColumnPrefsKey = 'dashboard_holdings_sort_column';
  static const String _sortAscendingPrefsKey = 'dashboard_holdings_sort_ascending';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sortStateHydrated) {
      return;
    }
    final storage = PageStorage.maybeOf(context);
    final storedColumn = storage?.readState(
      context,
      identifier: _sortColumnStorageKey,
    );
    final storedAscending = storage?.readState(
      context,
      identifier: _sortAscendingStorageKey,
    );

    if (storedColumn is int) {
      _sortColumnIndex = storedColumn.clamp(0, 5);
    }
    if (storedAscending is bool) {
      _sortAscending = storedAscending;
    }
    _sortStateHydrated = true;
    _hydrateSortStateFromPrefs();
  }

  List<DashboardAsset> _sortedAssets() {
    final sorted = widget.assets.toList(growable: false).toList();
    int compare;
    sorted.sort((a, b) {
      switch (_sortColumnIndex) {
        case 0:
          compare = a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());
          break;
        case 1:
          compare = a.quantity.compareTo(b.quantity);
          break;
        case 2:
          compare = a.avgBuyPrice.compareTo(b.avgBuyPrice);
          break;
        case 3:
          compare = a.currentPrice.compareTo(b.currentPrice);
          break;
        case 4:
          compare = a.marketValue.compareTo(b.marketValue);
          break;
        case 5:
          compare = a.profitLoss.compareTo(b.profitLoss);
          break;
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortTouched = true;
    });
    _persistSortState();
  }

  void _resetSort() {
    if (_sortColumnIndex == _defaultSortColumnIndex &&
        _sortAscending == _defaultSortAscending) {
      return;
    }
    setState(() {
      _sortColumnIndex = _defaultSortColumnIndex;
      _sortAscending = _defaultSortAscending;
      _sortTouched = true;
    });
    _persistSortState();
  }

  void _hydrateSortStateFromPrefs() {
    if (_prefsHydrationStarted) {
      return;
    }
    _prefsHydrationStarted = true;
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted || _sortTouched) {
        return;
      }
      final storedColumn = prefs.getInt(_sortColumnPrefsKey);
      final storedAscending = prefs.getBool(_sortAscendingPrefsKey);

      final nextColumn = (storedColumn ?? _sortColumnIndex).clamp(0, 5);
      final nextAscending = storedAscending ?? _sortAscending;
      final hasChanged =
          nextColumn != _sortColumnIndex || nextAscending != _sortAscending;
      if (!hasChanged) {
        return;
      }

      setState(() {
        _sortColumnIndex = nextColumn;
        _sortAscending = nextAscending;
      });
      final storage = PageStorage.maybeOf(context);
      storage?.writeState(
        context,
        _sortColumnIndex,
        identifier: _sortColumnStorageKey,
      );
      storage?.writeState(
        context,
        _sortAscending,
        identifier: _sortAscendingStorageKey,
      );
    });
  }

  void _persistSortState() {
    final storage = PageStorage.maybeOf(context);
    storage?.writeState(
      context,
      _sortColumnIndex,
      identifier: _sortColumnStorageKey,
    );
    storage?.writeState(
      context,
      _sortAscending,
      identifier: _sortAscendingStorageKey,
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_sortColumnPrefsKey, _sortColumnIndex);
      prefs.setBool(_sortAscendingPrefsKey, _sortAscending);
    });
  }

  static final NumberFormat _money = NumberFormat('#,##0.00', 'fa_IR');
  static final NumberFormat _qty = NumberFormat('#,##0.####', 'fa_IR');

  String _moneyText(double value) => '${_money.format(value)} ${widget.currency}';

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const DashboardEmptyState(
        title: 'لیست دارایی‌ها خالی است',
        subtitle: 'پس از ثبت دارایی‌های واقعی، جزئیات این بخش نمایش داده می‌شود.',
      );
    }

    final sortedAssets = _sortedAssets();
    final fintech = context.fintechColors;

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
                      widget.title,
                      style: AppTypography.sectionTitle(Theme.of(context).textTheme),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _resetSort,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('بازنشانی مرتب‌سازی'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 760;
              if (isMobile) {
                return _MobileHoldingsList(
                  assets: sortedAssets,
                  fintech: fintech,
                  qty: _qty,
                  moneyText: _moneyText,
                );
              }
              return _DesktopHoldingsTable(
                assets: sortedAssets,
                fintech: fintech,
                qty: _qty,
                moneyText: _moneyText,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                onSort: _onSort,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileHoldingsList extends StatelessWidget {
  const _MobileHoldingsList({
    required this.assets,
    required this.fintech,
    required this.qty,
    required this.moneyText,
  });

  final List<DashboardAsset> assets;
  final FintechColors fintech;
  final NumberFormat qty;
  final String Function(double value) moneyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: assets.map((asset) {
        final pnlColor = asset.profitLoss >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;
        final pnlPrefix = asset.profitLoss >= 0 ? '+' : '-';
        final roiColor =
            asset.allocationPercent >= 0 ? fintech.pnlSuccess : Theme.of(context).colorScheme.onSurface;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LtrLogText(
                          asset.symbol,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          asset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: roiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${asset.allocationPercent.toStringAsFixed(1)}٪',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: roiColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MobileMetric(
                      label: 'تعداد',
                      value: qty.format(asset.quantity),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileMetric(
                      label: 'قیمت فعلی',
                      value: moneyText(asset.currentPrice),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MobileMetric(
                      label: 'ارزش بازار',
                      value: moneyText(asset.marketValue),
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MobileMetric(
                      label: 'سود/زیان',
                      value: '$pnlPrefix${moneyText(asset.profitLoss.abs())}',
                      valueColor: pnlColor,
                      emphasized: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MobileMetric(
                label: 'میانگین خرید',
                value: moneyText(asset.avgBuyPrice),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _MobileMetric extends StatelessWidget {
  const _MobileMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        LtrLogText(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _DesktopHoldingsTable extends StatelessWidget {
  const _DesktopHoldingsTable({
    required this.assets,
    required this.fintech,
    required this.qty,
    required this.moneyText,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final List<DashboardAsset> assets;
  final FintechColors fintech;
  final NumberFormat qty;
  final String Function(double value) moneyText;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.25),
            ),
            child: DataTable(
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              dataTextStyle: Theme.of(context).textTheme.bodySmall,
              horizontalMargin: 12,
              columnSpacing: 18,
              columns: [
                DataColumn(
                  label: const Text('دارایی'),
                  onSort: onSort,
                ),
                DataColumn(
                  label: const Text('تعداد'),
                  numeric: true,
                  onSort: onSort,
                ),
                DataColumn(
                  label: const Text('میانگین خرید'),
                  numeric: true,
                  onSort: onSort,
                ),
                DataColumn(
                  label: const Text('قیمت فعلی'),
                  numeric: true,
                  onSort: onSort,
                ),
                DataColumn(
                  label: const Text('ارزش بازار'),
                  numeric: true,
                  onSort: onSort,
                ),
                DataColumn(
                  label: const Text('سود/زیان'),
                  numeric: true,
                  onSort: onSort,
                ),
              ],
              rows: assets.map((asset) {
                final pnlColor = asset.profitLoss >= 0 ? fintech.pnlSuccess : fintech.pnlDanger;
                final pnlPrefix = asset.profitLoss >= 0 ? '+' : '-';
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LtrLogText(
                            asset.symbol,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    DataCell(LtrLogText(qty.format(asset.quantity))),
                    DataCell(LtrLogText(moneyText(asset.avgBuyPrice))),
                    DataCell(LtrLogText(moneyText(asset.currentPrice))),
                    DataCell(LtrLogText(moneyText(asset.marketValue))),
                    DataCell(
                      LtrLogText(
                        '$pnlPrefix${moneyText(asset.profitLoss.abs())}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: pnlColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}
