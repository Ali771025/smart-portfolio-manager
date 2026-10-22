import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../../reconciliation/domain/reconciliation_models.dart';
import '../../../reconciliation/presentation/providers/manual_reconciliation_controller.dart';
import '../../../reconciliation/presentation/widgets/manual_reconciliation_sheet.dart';
import '../../data/asset_ledger_repository.dart';
import '../../domain/models/asset_ledger_models.dart';
import '../providers/asset_ledger_notifiers.dart';
import '../widgets/asset_formatters.dart';
import '../widgets/asset_empty_state.dart';
import '../widgets/asset_error_state.dart';
import '../widgets/asset_holding_card.dart';
import '../widgets/asset_loading_skeleton.dart';
import '../widgets/asset_summary_kpi_row.dart';
import '../widgets/assets_header.dart';
import '../widgets/holdings_table.dart';
import '../widgets/ledger_table.dart';
import '../widgets/selected_asset_detail_panel.dart';
import '../widgets/transaction_dynamic_form.dart';
import '../widgets/valuation_chart_card.dart';

class AssetsDashboardPage extends ConsumerStatefulWidget {
  const AssetsDashboardPage({
    super.key,
    this.initialPortfolioId,
    this.initialTicker,
  });

  final String? initialPortfolioId;
  final String? initialTicker;

  @override
  ConsumerState<AssetsDashboardPage> createState() =>
      _AssetsDashboardPageState();
}

class _AssetsDashboardPageState extends ConsumerState<AssetsDashboardPage> {
  String? _selectedPortfolioId;
  String? _selectedTicker;

  static const _mobileBreakpoint = 760.0;
  static const _desktopBreakpoint = 1200.0;

  @override
  Widget build(BuildContext context) {
    final portfoliosState = ref.watch(portfolioListProvider);
    final portfolios = (portfoliosState.value ?? const <PortfolioListItem>[])
        .where((item) => _isUuid(item.id))
        .toList(growable: false);

    if (portfoliosState.isLoading && portfolios.isEmpty) {
      return const Scaffold(body: AssetLoadingSkeleton());
    }

    if (portfoliosState.hasError && portfolios.isEmpty) {
      return Scaffold(
        body: AssetErrorState(
          message: 'خطا در بارگذاری فهرست پرتفوی‌ها',
          onRetry: () => ref.read(portfolioListProvider.notifier).refresh(),
        ),
      );
    }

    if (portfolios.isEmpty) {
      return const Scaffold(
        body: AssetEmptyState(
          title: 'پرتفویی برای نمایش دارایی‌ها ندارید.',
          subtitle: 'ابتدا یک پرتفوی ایجاد کنید تا داشبورد دارایی فعال شود.',
        ),
      );
    }

    final selectedPortfolioId = _resolvePortfolioId(portfolios);
    if (selectedPortfolioId == null) {
      return const Scaffold(
        body: AssetEmptyState(
          title: 'پرتفوی معتبری پیدا نشد',
          subtitle: 'لطفا یک پرتفوی دیگر انتخاب کنید.',
        ),
      );
    }

    final holdingsState =
        ref.watch(portfolioHoldingsProvider(selectedPortfolioId));
    final summaryState =
        ref.watch(portfolioFrontendSummaryProvider(selectedPortfolioId));

    return Scaffold(
      body: holdingsState.when(
        loading: () => const AssetLoadingSkeleton(),
        error: (error, _) => AssetErrorState(
          message: 'خطا در دریافت وضعیت دارایی‌های پرتفوی',
          onRetry: () => ref.invalidate(
            portfolioHoldingsProvider(selectedPortfolioId),
          ),
        ),
        data: (holdings) => summaryState.when(
          loading: () => const AssetLoadingSkeleton(),
          error: (error, _) => AssetErrorState(
            message: 'خطا در دریافت خلاصه دارایی‌های پرتفوی',
            onRetry: () => ref.invalidate(
              portfolioFrontendSummaryProvider(selectedPortfolioId),
            ),
          ),
          data: (summary) {
            final selectedHolding = _resolveHolding(holdings.holdings);
            final selectedTicker = selectedHolding?.symbol;
            final selectedScope = selectedHolding == null
                ? null
                : AssetScope(
                    portfolioId: selectedPortfolioId,
                    assetId: selectedHolding.assetId,
                  );
            final now = DateTime.now();

            return RefreshIndicator.adaptive(
              onRefresh: () async => _refreshAll(
                selectedPortfolioId: selectedPortfolioId,
                selectedScope: selectedScope,
                now: now,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isMobile = width < _mobileBreakpoint;
                  final isDesktop = width >= _desktopBreakpoint;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      AssetsHeader(
                        portfolios: portfolios,
                        selectedPortfolioId: selectedPortfolioId,
                        onPortfolioChanged: _onPortfolioChanged,
                        onRefresh: () => _refreshAll(
                          selectedPortfolioId: selectedPortfolioId,
                          selectedScope: selectedScope,
                          now: now,
                        ),
                        onAddAsset: () => _promptAddAsset(context),
                        onAddTransaction: () async {
                          if (selectedScope == null) {
                            _showMessage(
                                context, 'ابتدا یک دارایی انتخاب کنید.');
                            return;
                          }
                          await _openTransactionSheet(
                            context,
                            scope: selectedScope,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AssetSummaryKpiRow(summary: summary),
                      const SizedBox(height: 12),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _HoldingsSection(
                                items: holdings.holdings,
                                selectedTicker: selectedTicker,
                                isMobile: false,
                                onSelectTicker: _onTickerSelected,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 7,
                              child: _SelectedAssetSection(
                                scope: selectedScope,
                                holding: selectedHolding,
                                portfolios: portfolios,
                                now: now,
                                onOpenTransactionSheet: _openTransactionSheet,
                                onOpenManualReconciliation:
                                    _openManualReconciliationFlow,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _HoldingsSection(
                          items: holdings.holdings,
                          selectedTicker: selectedTicker,
                          isMobile: isMobile,
                          onSelectTicker: _onTickerSelected,
                        ),
                        const SizedBox(height: 12),
                        _SelectedAssetSection(
                          scope: selectedScope,
                          holding: selectedHolding,
                          portfolios: portfolios,
                          now: now,
                          onOpenTransactionSheet: _openTransactionSheet,
                          onOpenManualReconciliation:
                              _openManualReconciliationFlow,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _LedgerSection(
                        scope: selectedScope,
                        selectedTicker: selectedTicker,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  String? _resolvePortfolioId(List<PortfolioListItem> portfolios) {
    final userSelected = _selectedPortfolioId;
    if (_containsPortfolio(portfolios, userSelected)) {
      return userSelected;
    }

    final pinned = ref.read(selectedPortfolioIdProvider);
    if (_containsPortfolio(portfolios, pinned)) {
      return pinned;
    }

    final initial = widget.initialPortfolioId;
    if (_containsPortfolio(portfolios, initial)) {
      return initial;
    }

    return portfolios.first.id;
  }

  PortfolioHoldingDto? _resolveHolding(List<PortfolioHoldingDto> items) {
    if (items.isEmpty) {
      return null;
    }

    final selected = _selectedTicker;
    if (_containsTicker(items, selected)) {
      return items.firstWhere((item) => item.symbol == selected);
    }

    final initial = widget.initialTicker?.trim().toUpperCase();
    if (_containsTicker(items, initial)) {
      return items.firstWhere((item) => item.symbol == initial);
    }

    return items.first;
  }

  bool _containsPortfolio(
      List<PortfolioListItem> portfolios, String? portfolioId) {
    if (portfolioId == null || portfolioId.isEmpty) {
      return false;
    }
    return portfolios.any((item) => item.id == portfolioId);
  }

  bool _containsTicker(List<PortfolioHoldingDto> items, String? ticker) {
    if (ticker == null || ticker.isEmpty) {
      return false;
    }
    return items.any((item) => item.symbol == ticker);
  }

  void _onPortfolioChanged(String portfolioId) {
    setState(() {
      _selectedPortfolioId = portfolioId;
      _selectedTicker = null;
    });
    ref.read(selectedPortfolioIdProvider.notifier).state = portfolioId;
  }

  void _onTickerSelected(String ticker) {
    setState(() {
      _selectedTicker = ticker;
    });
  }

  Future<void> _refreshAll({
    required String selectedPortfolioId,
    required AssetScope? selectedScope,
    required DateTime now,
  }) async {
    await ref.read(portfolioListProvider.notifier).refresh();
    ref.invalidate(portfolioHoldingsProvider(selectedPortfolioId));
    ref.invalidate(portfolioFrontendSummaryProvider(selectedPortfolioId));

    if (selectedScope == null) {
      return;
    }

    await ref
        .read(assetLedgerControllerProvider(selectedScope).notifier)
        .refresh();
    ref.invalidate(
      assetValuationSeriesProvider(
        selectedScope,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
        adjustedPrices: true,
      ),
    );
  }

  Future<void> _openTransactionSheet(
    BuildContext context, {
    required AssetScope scope,
    String? transactionType,
  }) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
          child: SingleChildScrollView(
            child: TransactionDynamicForm(
              scope: scope,
              initialTransactionType: transactionType,
            ),
          ),
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    if (submitted == true) {
      _showMessage(context, 'لیست دارایی‌ها و دفتر معاملات به‌روزرسانی شد.');
      ref.invalidate(portfolioHoldingsProvider(scope.portfolioId));
      ref.invalidate(portfolioFrontendSummaryProvider(scope.portfolioId));
      ref.invalidate(assetLedgerControllerProvider(scope));
      final now = DateTime.now();
      ref.invalidate(
        assetValuationSeriesProvider(
          scope,
          startDate: now.subtract(const Duration(days: 365)),
          endDate: now,
          adjustedPrices: true,
        ),
      );
    }
  }

  Future<void> _openManualReconciliationFlow(
    BuildContext context, {
    required AssetScope scope,
    required PortfolioHoldingDto holding,
    required List<PortfolioListItem> portfolios,
  }) async {
    final persistedPortfolios = portfolios
        .where((item) => _isUuid(item.id))
        .toList(growable: false);
    if (persistedPortfolios.length < 2) {
      _showMessage(
        context,
        'برای تطبیق دستی، حداقل دو پرتفوی ثبت‌شده لازم است.',
      );
      return;
    }

    final List<LedgerEntryDto> ledger;
    try {
      ledger = await _readLedgerForReconciliation(scope);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'دریافت فروش‌های قابل تطبیق ناموفق بود.');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final sellEntries = ledger
        .where((entry) => entry.transactionType.toUpperCase() == 'SELL')
        .toList(growable: false)
      ..sort((left, right) => right.executedAt.compareTo(left.executedAt));

    if (sellEntries.isEmpty) {
      _showMessage(
        context,
        'برای این نماد فروش قابل تطبیق پیدا نشد.',
      );
      return;
    }

    final selectedSell = await showModalBottomSheet<LedgerEntryDto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SellTransactionPickerSheet(
        holding: holding,
        entries: sellEntries,
      ),
    );
    if (!context.mounted || selectedSell == null) {
      return;
    }

    final args = ManualReconciliationArgs(
      sell: ReconciliationSellSelection(
        transactionId: selectedSell.id,
        portfolioId: selectedSell.portfolioId.isNotEmpty
            ? selectedSell.portfolioId
            : scope.portfolioId,
        portfolioLabel: _portfolioLabel(persistedPortfolios, scope.portfolioId),
        assetId: selectedSell.assetId.isNotEmpty
            ? selectedSell.assetId
            : scope.assetId,
        symbol: holding.symbol,
        executedAt: selectedSell.executedAt,
        quantity: selectedSell.quantity,
        pricePerUnit: selectedSell.pricePerUnit,
      ),
      portfolios: persistedPortfolios
          .map(
            (item) => ReconciliationPortfolioRef(
              id: item.id,
              label: item.name,
            ),
          )
          .toList(growable: false),
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ManualReconciliationSheet(args: args),
    );
    if (!context.mounted || confirmed != true) {
      return;
    }

    _showMessage(context, 'تطبیق دستی فروش تایید شد.');
    _refreshAfterReconciliation(scope: scope, portfolios: persistedPortfolios);
  }

  Future<List<LedgerEntryDto>> _readLedgerForReconciliation(
    AssetScope scope,
  ) async {
    final page = await ref.read(assetLedgerRepositoryProvider).fetchAssetLedger(
          portfolioId: scope.portfolioId,
          assetId: scope.assetId,
          limit: 500,
          offset: 0,
        );
    return page.items;
  }

  void _refreshAfterReconciliation({
    required AssetScope scope,
    required List<PortfolioListItem> portfolios,
  }) {
    for (final portfolio in portfolios) {
      ref.invalidate(portfolioHoldingsProvider(portfolio.id));
      ref.invalidate(portfolioFrontendSummaryProvider(portfolio.id));
    }
    ref.invalidate(assetLedgerControllerProvider(scope));
    ref.invalidate(assetPositionControllerProvider(scope));
    ref.invalidate(dashboardControllerProvider);

    final now = DateTime.now();
    ref.invalidate(
      assetValuationSeriesProvider(
        scope,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
        adjustedPrices: true,
      ),
    );
  }

  String _portfolioLabel(
    List<PortfolioListItem> portfolios,
    String portfolioId,
  ) {
    for (final portfolio in portfolios) {
      if (portfolio.id == portfolioId) {
        return portfolio.name;
      }
    }
    return 'پرتفوی انتخاب‌شده';
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  Future<void> _promptAddAsset(BuildContext context) async {
    final controller = TextEditingController();
    final symbol = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن دارایی'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'نماد',
            hintText: 'مثال: فولاد',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    controller.dispose();

    final normalized = symbol?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(assetLedgerRepositoryProvider);
      final resolved = await repository.resolveAsset(symbol: normalized);
      if (!context.mounted) {
        return;
      }
      _showMessage(
        context,
        resolved.created
            ? 'دارایی ${resolved.symbol} با موفقیت ایجاد شد.'
            : 'دارایی ${resolved.symbol} قبلا ثبت شده بود.',
      );
      setState(() {
        _selectedTicker = resolved.symbol;
      });
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, 'افزودن دارایی ناموفق بود: $error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({
    required this.items,
    required this.selectedTicker,
    required this.isMobile,
    required this.onSelectTicker,
  });

  final List<PortfolioHoldingDto> items;
  final String? selectedTicker;
  final bool isMobile;
  final ValueChanged<String> onSelectTicker;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'لیست دارایی‌های پرتفوی',
      child: items.isEmpty
          ? const AssetEmptyState(
              title: 'دارایی فعالی در این پرتفوی ثبت نشده است.',
              subtitle:
                  'با افزودن تراکنش، دارایی‌ها در این بخش نمایش داده می‌شوند.',
            )
          : isMobile
              ? Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AssetHoldingCard(
                            item: item,
                            selected: item.symbol == selectedTicker,
                            onTap: () => onSelectTicker(item.symbol),
                          ),
                        ),
                      )
                      .toList(growable: false),
                )
              : HoldingsTable(
                  items: items,
                  selectedTicker: selectedTicker,
                  onSelectTicker: onSelectTicker,
                ),
    );
  }
}

class _SelectedAssetSection extends ConsumerWidget {
  const _SelectedAssetSection({
    required this.scope,
    required this.holding,
    required this.portfolios,
    required this.now,
    required this.onOpenTransactionSheet,
    required this.onOpenManualReconciliation,
  });

  final AssetScope? scope;
  final PortfolioHoldingDto? holding;
  final List<PortfolioListItem> portfolios;
  final DateTime now;
  final Future<void> Function(
    BuildContext context, {
    required AssetScope scope,
    String? transactionType,
  }) onOpenTransactionSheet;
  final Future<void> Function(
    BuildContext context, {
    required AssetScope scope,
    required PortfolioHoldingDto holding,
    required List<PortfolioListItem> portfolios,
  }) onOpenManualReconciliation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedScope = scope;
    final selectedHolding = holding;
    if (selectedScope == null || selectedHolding == null) {
      return const _SectionCard(
        title: 'جزئیات دارایی انتخاب‌شده',
        child: AssetEmptyState(
          title: 'برای مشاهده جزئیات یک دارایی را انتخاب کنید.',
          subtitle:
              'پس از انتخاب، نمودار ارزش‌گذاری و اطلاعات تکمیلی نمایش داده می‌شود.',
        ),
      );
    }

    final breakEvenState = ref.watch(assetBreakEvenInfoProvider(selectedScope));
    final valuationState = ref.watch(
      assetValuationSeriesProvider(
        selectedScope,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
        adjustedPrices: true,
      ),
    );

    return Column(
      children: [
        SelectedAssetDetailPanel(
          holding: selectedHolding,
          breakEvenInfo: breakEvenState.asData?.value,
          isBreakEvenLoading: breakEvenState.isLoading,
          onSaveBreakEvenPrice: (value) => _saveBreakEvenPrice(
            ref: ref,
            context: context,
            scope: selectedScope,
            value: value,
          ),
          onOpenTransactionSheet: () => onOpenTransactionSheet(
            context,
            scope: selectedScope,
          ),
          onOpenManualReconciliation: () => onOpenManualReconciliation(
            context,
            scope: selectedScope,
            holding: selectedHolding,
            portfolios: portfolios,
          ),
          onQuickAction: (type) {
            if (type == 'VIEW_LEDGER') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'دفتر معاملات در بخش پایین صفحه نمایش داده شده است.',
                  ),
                ),
              );
              return;
            }
            onOpenTransactionSheet(
              context,
              scope: selectedScope,
              transactionType: type,
            );
          },
        ),
        const SizedBox(height: 12),
        valuationState.when(
          loading: () => const _SectionCard(
            title: 'نمودار ارزش‌گذاری',
            child: SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
          error: (error, _) => _SectionCard(
            title: 'نمودار ارزش‌گذاری',
            child: AssetErrorState(
              message: 'خطا در دریافت نمودار ارزش‌گذاری',
              onRetry: () => ref.invalidate(
                assetValuationSeriesProvider(
                  selectedScope,
                  startDate: now.subtract(const Duration(days: 365)),
                  endDate: now,
                  adjustedPrices: true,
                ),
              ),
            ),
          ),
          data: (series) => ValuationChartCard(
            points: series.points,
            endpointMarketValue: selectedHolding.marketValue,
          ),
        ),
      ],
    );
  }

  Future<void> _saveBreakEvenPrice({
    required WidgetRef ref,
    required BuildContext context,
    required AssetScope scope,
    required Decimal? value,
  }) async {
    try {
      await ref.read(assetLedgerRepositoryProvider).updateBreakEvenPrice(
            portfolioId: scope.portfolioId,
            assetId: scope.assetId,
            manualBreakEvenPrice: value,
          );
      ref.invalidate(assetBreakEvenInfoProvider(scope));
      ref.invalidate(portfolioHoldingsProvider(scope.portfolioId));
      ref.invalidate(portfolioFrontendSummaryProvider(scope.portfolioId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value == null
                  ? 'قیمت سر به سر دستی پاک شد.'
                  : 'قیمت سر به سر ذخیره شد.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ذخیره قیمت سر به سر ناموفق بود.')),
        );
      }
    }
  }
}

class _LedgerSection extends ConsumerWidget {
  const _LedgerSection({
    required this.scope,
    required this.selectedTicker,
  });

  final AssetScope? scope;
  final String? selectedTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedTicker == null) {
      return const _SectionCard(
        title: 'دفتر تراکنش‌ها',
        child: AssetEmptyState(
          title: 'هنوز دارایی‌ای برای نمایش دفتر تراکنش انتخاب نشده است.',
          subtitle: 'یک دارایی را از لیست بالا انتخاب کنید.',
        ),
      );
    }

    final selectedScope = scope;
    if (selectedScope == null) {
      return const SizedBox.shrink();
    }

    final ledgerState = ref.watch(assetLedgerControllerProvider(selectedScope));
    return _SectionCard(
      title: 'دفتر تراکنش‌ها',
      child: ledgerState.when(
        loading: () => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (error, _) => AssetErrorState(
          message: 'خطا در دریافت دفتر تراکنش‌ها',
          onRetry: () => ref
              .read(assetLedgerControllerProvider(selectedScope).notifier)
              .retry(),
        ),
        data: (ledger) => LedgerTable(
          entries: ledger.items,
          isLoadingMore: ledger.isLoadingMore,
          hasMore: ledger.hasMore,
          onLoadMore: () => ref
              .read(assetLedgerControllerProvider(selectedScope).notifier)
              .loadMore(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SellTransactionPickerSheet extends StatelessWidget {
  const _SellTransactionPickerSheet({
    required this.holding,
    required this.entries,
  });

  final PortfolioHoldingDto holding;
  final List<LedgerEntryDto> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'انتخاب فروش برای تطبیق ${holding.symbol}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'فروش موردنظر را انتخاب کنید تا خریدهای قابل انتساب از پرتفوی‌های دیگر بررسی شوند.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _SellTransactionTile(entry: entry);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellTransactionTile extends StatelessWidget {
  const _SellTransactionTile({required this.entry});

  final LedgerEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.sell_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd', 'en_US').format(
                        entry.executedAt,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          'تعداد: ${formatAssetNumber(entry.quantity.toString())}',
                        ),
                        Text('قیمت: ${formatAssetMoney(entry.pricePerUnit)}'),
                        Text('مبلغ: ${formatAssetMoney(entry.totalAmount)}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
