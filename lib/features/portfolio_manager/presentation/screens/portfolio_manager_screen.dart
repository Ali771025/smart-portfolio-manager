import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_failure.dart';
import '../../domain/models/portfolio_card_dto.dart';
import '../providers/portfolio_manager_controller.dart';
import '../widgets/portfolio_card_tile.dart';

class PortfolioManagerScreen extends ConsumerWidget {
  const PortfolioManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final portfolios = ref.watch(portfolioManagerControllerProvider);
    final List<PortfolioCardDto> cards =
        portfolios.value ?? const <PortfolioCardDto>[];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('پرتفوی جدید'),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Colors.transparent,
            expandedHeight: 126,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
              title: Text(
                'مدیریت پرتفوها',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
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
                                  ? const Color(0xFF0E1A2C)
                                  : scheme.surfaceContainerHighest)
                              .withValues(alpha: isDark ? 0.72 : 0.88),
                          (isDark
                                  ? const Color(0xFF111827)
                                  : scheme.surfaceContainer)
                              .withValues(alpha: isDark ? 0.55 : 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => ref
                    .read(portfolioManagerControllerProvider.notifier)
                    .refreshPortfolios(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (portfolios.hasError)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                failure: portfolios.error,
                onRetry: () => ref
                    .read(portfolioManagerControllerProvider.notifier)
                    .refreshPortfolios(),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
            sliver: cards.isEmpty
                ? const SliverToBoxAdapter(
                    child: _EmptyState(),
                  )
                : SliverList.separated(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      return PortfolioCardTile(
                        item: cards[index],
                        onDelete: () => _confirmAndDeletePortfolio(
                          context,
                          ref,
                          cards[index],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CreatePortfolioDialog(),
    );
  }

  Future<void> _confirmAndDeletePortfolio(
    BuildContext context,
    WidgetRef ref,
    PortfolioCardDto item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
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

class _CreatePortfolioDialog extends ConsumerStatefulWidget {
  const _CreatePortfolioDialog();

  @override
  ConsumerState<_CreatePortfolioDialog> createState() =>
      _CreatePortfolioDialogState();
}

class _CreatePortfolioDialogState extends ConsumerState<_CreatePortfolioDialog> {
  late final TextEditingController _nameController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ایجاد پرتفو'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        enabled: !_isSubmitting,
        minLines: 1,
        maxLines: 6,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'نام پرتفو',
          hintText: 'هر نام را در یک خط وارد کنید',
          helperText: 'برای ایجاد چند پرتفو، نام‌ها را خط‌به‌خط بنویسید.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : () => _submit(context),
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_isSubmitting ? 'در حال ثبت...' : 'ثبت'),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    final names = _splitPortfolioNames(_nameController.text);
    if (names.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSubmitting = true);

    final result = await ref
        .read(portfolioManagerControllerProvider.notifier)
        .addPortfolios(names);
    if (!mounted) {
      return;
    }

    final message = _createResultMessage(result);
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );

    if (!result.hasFailures) {
      navigator.pop();
      return;
    }

    _nameController.text = result.failures
        .map((failure) => failure.name)
        .join('\n');
    setState(() => _isSubmitting = false);
  }

  List<String> _splitPortfolioNames(String rawValue) {
    final seen = <String>{};
    final names = <String>[];
    for (final part in rawValue.split(RegExp(r'[\n\r,،]+'))) {
      final name = part.trim();
      final key = name.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (name.isEmpty || !seen.add(key)) {
        continue;
      }
      names.add(name);
    }
    return names;
  }

  String _createResultMessage(PortfolioBatchCreateResult result) {
    final createdCount = result.created.length;
    final failedCount = result.failures.length;
    if (createdCount > 0 && failedCount == 0) {
      return createdCount == 1
          ? 'پرتفوی ایجاد شد.'
          : '$createdCount پرتفو ایجاد شد.';
    }
    if (createdCount > 0 && failedCount > 0) {
      return '$createdCount پرتفو ایجاد شد، $failedCount مورد ناموفق بود.';
    }
    if (failedCount == 1) {
      return result.failures.first.failure.message;
    }
    return 'ایجاد پرتفوها ناموفق بود.';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.failure,
    required this.onRetry,
  });

  final Object? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final currentFailure = failure;
    final message = currentFailure is AppFailure
        ? currentFailure.message
        : 'خطا در دریافت پرتفوی‌ها';
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 46,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'هنوز پرتفویی ثبت نشده است.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'با دکمه پایین صفحه اولین پرتفو را ایجاد کنید.',
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
