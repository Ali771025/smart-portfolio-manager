import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/app_failure.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../providers/portfolio_providers.dart';
import '../widgets/portfolio_card_widget.dart';

class PortfolioListScreen extends ConsumerWidget {
  const PortfolioListScreen({
    super.key,
    this.appBarTitle = 'فهرست پرتفوی‌ها',
    this.errorFallbackMessage = 'خطا در دریافت فهرست پرتفوی‌ها.',
    this.emptyTitle = 'هنوز پرتفوی‌ای برای شما ثبت نشده است.',
    this.emptySubtitle = 'پس از ایجاد پرتفوی، وضعیت ارزش و سود/زیان همینجا نمایش داده می‌شود.',
  });

  final String appBarTitle;
  final String errorFallbackMessage;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPortfolios = ref.watch(portfolioListProvider);
    final portfolios = asyncPortfolios.value ?? const <PortfolioListItem>[];
    final showSkeleton = asyncPortfolios.isLoading && portfolios.isEmpty;

    final displayItems = showSkeleton
        ? List<PortfolioListItem>.generate(
            6,
            PortfolioListItem.skeleton,
            growable: false,
          )
        : portfolios;

    return Scaffold(
      backgroundColor: context.semanticColors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(portfolioListProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: 128,
              title: Text(appBarTitle),
              titleTextStyle: AppTypography.sectionTitle(Theme.of(context).textTheme),
              actions: [
                IconButton(
                  onPressed: () => context.push('/portfolios/manage'),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'مدیریت پرتفوی‌ها',
                ),
                IconButton(
                  onPressed: () => ref.read(portfolioListProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
                background: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            (isDark
                                    ? context.semanticColors.surface
                                    : context.semanticColors.elevatedSurface)
                                .withValues(alpha: isDark ? 0.74 : 0.88),
                            (isDark
                                    ? context.semanticColors.card
                                    : context.semanticColors.surface)
                                .withValues(alpha: isDark ? 0.55 : 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (asyncPortfolios.hasError && !showSkeleton)
              SliverToBoxAdapter(
                child: _ErrorCard(
                  error: asyncPortfolios.error,
                  fallbackMessage: errorFallbackMessage,
                  onRetry: () => ref.read(portfolioListProvider.notifier).refresh(),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Skeletonizer(
                  enabled: showSkeleton,
                  child: Column(
                    children: [
                      for (final item in displayItems) ...[
                        PortfolioCardWidget(
                          item: item,
                          onTap: showSkeleton
                              ? null
                              : () => _openPortfolioDetail(
                                    context,
                                    ref,
                                    item.id,
                                  ),
                        ),
                        if (!showSkeleton) ...[
                          const SizedBox(height: 8),
                          _PortfolioActionBar(
                            portfolioId: item.id,
                            onSelect: () => ref
                                .read(selectedPortfolioIdProvider.notifier)
                                .state = item.id,
                            onDelete: () => _confirmAndDeletePortfolio(
                              context,
                              ref: ref,
                              item: item,
                            ),
                            onOpenLedger: () => _promptForTickerAndOpenLedger(
                              context,
                              ref: ref,
                              portfolioId: item.id,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!showSkeleton && portfolios.isEmpty && !asyncPortfolios.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 92),
            ),
          ],
        ),
      ),
    );
  }

  void _openPortfolioDetail(
    BuildContext context,
    WidgetRef ref,
    String portfolioId,
  ) {
    ref.read(selectedPortfolioIdProvider.notifier).state = portfolioId;
    context.push('/portfolios/$portfolioId/detail');
  }

  Future<void> _promptForTickerAndOpenLedger(
    BuildContext context, {
    required WidgetRef ref,
    required String portfolioId,
  }) async {
    ref.read(selectedPortfolioIdProvider.notifier).state = portfolioId;
    if (!context.mounted) {
      return;
    }

    String draftTicker = '';
    final ticker = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ورود نماد دارایی'),
          content: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'مثال: فولاد',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => draftTicker = value,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftTicker),
              child: const Text('نمایش'),
            ),
          ],
        );
      },
    );

    if (ticker == null) {
      return;
    }

    final normalized = ticker.trim().toUpperCase();
    if (normalized.isEmpty || !context.mounted) {
      return;
    }

    final encodedTicker = Uri.encodeComponent(normalized);
    context.push('/portfolios/$portfolioId/assets/$encodedTicker');
  }

  Future<void> _confirmAndDeletePortfolio(
    BuildContext context, {
    required WidgetRef ref,
    required PortfolioListItem item,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف پرتفو'),
          content: Text(
            'پرتفوی «${item.name}» از فهرست فعال شما حذف شود؟ معاملات و تاریخچه آن در دیتابیس نگهداری می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(portfolioManagerControllerProvider.notifier)
        .deletePortfolio(item.id);
    if (!context.mounted) {
      return;
    }

    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) => messenger.showSnackBar(
        const SnackBar(content: Text('پرتفو حذف شد.')),
      ),
    );
  }
}

class _PortfolioActionBar extends StatelessWidget {
  const _PortfolioActionBar({
    required this.portfolioId,
    required this.onSelect,
    required this.onDelete,
    required this.onOpenLedger,
  });

  final String portfolioId;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionButton(
            icon: Icons.info_outline_rounded,
            label: 'جزئیات',
            onPressed: () {
              onSelect();
              context.push('/portfolios/$portfolioId/detail');
            },
          ),
          _ActionButton(
            icon: Icons.show_chart_rounded,
            label: 'نمودارها',
            onPressed: () {
              onSelect();
              context.push('/portfolios/$portfolioId/charts');
            },
          ),
          _ActionButton(
            icon: Icons.summarize_rounded,
            label: 'گزارش‌ها',
            onPressed: () {
              onSelect();
              context.push('/portfolios/$portfolioId/reports');
            },
          ),
          _ActionButton(
            icon: Icons.analytics_rounded,
            label: 'تحلیل نماد',
            onPressed: () {
              onSelect();
              context.push('/portfolios/$portfolioId/symbol-analytics');
            },
          ),
          _ActionButton(
            icon: Icons.inventory_2_outlined,
            label: 'دفتر دارایی',
            onPressed: onOpenLedger,
          ),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'حذف',
            onPressed: onDelete,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDestructive ? scheme.error : null,
        side: isDestructive
            ? BorderSide(color: scheme.error.withValues(alpha: 0.55))
            : null,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.error,
    required this.fallbackMessage,
    required this.onRetry,
  });

  final Object? error;
  final String fallbackMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure ? error as AppFailure : null;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
          color: scheme.errorContainer.withValues(alpha: 0.42),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  failure?.message ?? fallbackMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 54,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
