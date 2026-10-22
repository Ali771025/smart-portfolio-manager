import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../../portfolio_manager/domain/models/portfolio_card_dto.dart';
import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../../transactions/domain/models/import_parse_response_model.dart';
import '../../../transactions/domain/models/import_report_model.dart';
import '../../../transactions/domain/models/row_error_model.dart';
import '../../../transactions/presentation/controllers/excel_import_controller.dart';
import '../../../transactions/data/transaction_repository.dart';
import '../widgets/trade_entry_bottom_sheet.dart';

class TradeEntryScreen extends ConsumerStatefulWidget {
  const TradeEntryScreen({super.key});

  @override
  ConsumerState<TradeEntryScreen> createState() => _TradeEntryScreenState();
}

class _TradeEntryScreenState extends ConsumerState<TradeEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-sync portfolio sources when entering the trade flow.
      unawaited(ref.read(portfolioListProvider.notifier).refresh());
      unawaited(ref.read(portfolioManagerControllerProvider.notifier).refreshPortfolios());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ref.listen<ExcelImportFlowState>(
      excelImportControllerProvider.select(
        (state) => state.value ?? const ExcelImportIdle(),
      ),
      _handleImportStateChange,
    );

    final portfolios = ref.watch(portfolioOptionsProvider);
    final importState = ref.watch(
      excelImportControllerProvider.select(
        (state) => state.value ?? const ExcelImportIdle(),
      ),
    );

    return Scaffold(
      backgroundColor: context.semanticColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImportBusy(importState)
            ? null
            : () => _onImportPressed(),
        icon: _isImportBusy(importState)
            ? Semantics(
                label: 'در حال بارگذاری فایل اکسل',
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_fabLabel(importState)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('ثبت معاملات'),
            titleTextStyle: AppTypography.sectionTitle(Theme.of(context).textTheme),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            sliver: SliverList.list(
              children: [
                _HintCard(portfolioCount: portfolios.length),
                if (importState is! ExcelImportIdle) ...[
                  const SizedBox(height: 12),
                  _ImportStatusCard(
                    state: importState,
                    onCancel: _isCancellable(importState)
                        ? ref
                            .read(excelImportControllerProvider.notifier)
                            .cancelUpload
                        : null,
                    onDismiss:
                        ref.read(excelImportControllerProvider.notifier).reset,
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن سفارش جدید'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return scheme.surfaceContainerHighest;
                      }
                      if (states.contains(WidgetState.pressed)) {
                        return context.semanticColors.success.withValues(alpha: 0.88);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return context.semanticColors.success.withValues(alpha: 0.95);
                      }
                      return context.semanticColors.success;
                    }),
                    foregroundColor: WidgetStateProperty.all(scheme.onPrimary),
                    iconColor: WidgetStateProperty.all(scheme.onPrimary),
                  ),
                  onPressed: portfolios.isEmpty
                      ? null
                      : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: scheme.surfaceContainer,
                            builder: (_) => const TradeEntryBottomSheet(),
                          ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.account_tree_rounded),
                  label: const Text('ایمپورت چندپرتفویی'),
                  onPressed: () => context.push('/trades/multi-import'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text('ایمپورت اکسل کارگزاری'),
                  onPressed: () => context.push('/trades/excel-import'),
                ),
                const SizedBox(height: 14),
                Text(
                  'برای ثبت معامله، نوع سفارش (خرید/فروش)، نماد، تعداد، قیمت و پرتفوی مقصد را تعیین کنید.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onImportPressed() async {
    await ref
        .read(excelImportControllerProvider.notifier)
        .pickAndPreviewFile(currentSurface: ImportSurface.tradeLedgerScreen);
  }

  Future<ImportTargetPayload?> _selectImportTarget(
    BuildContext context,
    List<PortfolioOptionDto> portfolios,
  ) async {
    if (portfolios.isEmpty) {
      return showModalBottomSheet<ImportTargetPayload>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          final nameController = TextEditingController();
          return StatefulBuilder(
            builder: (context, setLocalState) {
              final name = nameController.text.trim();
              final canCreate = name.isNotEmpty;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'پرتفوی مقصد برای ایمپورت',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text('پرتفوی موجودی یافت نشد. یک پرتفوی جدید بسازید.'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'نام پرتفوی جدید',
                        hintText: 'مثال: پرتفوی آگاه',
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canCreate
                          ? () => Navigator.of(context).pop(
                                ImportTargetPayload.createNew(
                                  newPortfolioName: name,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('ایجاد و ایمپورت'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    if (portfolios.length == 1) {
      final onlyId = portfolios.first.id;
      ref.read(selectedPortfolioIdProvider.notifier).state = onlyId;
      return ImportTargetPayload.existing(portfolioId: onlyId);
    }

    final persistedId = ref.read(selectedPortfolioIdProvider);
    final initialSelectedId = portfolios.any((item) => item.id == persistedId)
        ? persistedId!
        : portfolios.first.id;

    return showModalBottomSheet<ImportTargetPayload>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        var targetMode = ImportTargetMode.existing;
        var selectedId = initialSelectedId;
        final newNameController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final normalizedName = newNameController.text.trim();
            final canSubmitExisting = selectedId.trim().isNotEmpty;
            final canSubmitNew = normalizedName.isNotEmpty;
            final submitEnabled = targetMode == ImportTargetMode.existing
                ? canSubmitExisting
                : canSubmitNew;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'پرتفوی مقصد برای ایمپورت',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ImportTargetMode>(
                    segments: const [
                      ButtonSegment<ImportTargetMode>(
                        value: ImportTargetMode.existing,
                        icon: Icon(Icons.list_alt_rounded),
                        label: Text('پرتفوی موجود'),
                      ),
                      ButtonSegment<ImportTargetMode>(
                        value: ImportTargetMode.createNew,
                        icon: Icon(Icons.add_circle_outline_rounded),
                        label: Text('پرتفوی جدید'),
                      ),
                    ],
                    selected: <ImportTargetMode>{targetMode},
                    onSelectionChanged: (selection) {
                      setLocalState(() {
                        targetMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (targetMode == ImportTargetMode.existing) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      items: portfolios
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setLocalState(() {
                          selectedId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'پرتفوی',
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: newNameController,
                      decoration: const InputDecoration(
                        labelText: 'نام پرتفوی جدید',
                        hintText: 'مثال: پرتفوی مفید',
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'در حالت پرتفوی جدید، هیچ portfolio_id ارسال نمی‌شود.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: submitEnabled
                        ? () {
                            if (targetMode == ImportTargetMode.existing) {
                              ref.read(selectedPortfolioIdProvider.notifier).state = selectedId;
                              Navigator.of(context).pop(
                                ImportTargetPayload.existing(
                                  portfolioId: selectedId,
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pop(
                              ImportTargetPayload.createNew(
                                newPortfolioName: normalizedName,
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.assignment_turned_in_rounded),
                    label: Text(
                      targetMode == ImportTargetMode.existing
                          ? 'ثبت نهایی ایمپورت'
                          : 'ایجاد و ثبت نهایی ایمپورت',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finalizeImportWithTarget({
    required String? detectedType,
    required ImportTargetPayload target,
  }) async {
    if (detectedType == 'PORTFOLIO_SNAPSHOT') {
      if (target.targetMode == ImportTargetMode.existing) {
        await ref
            .read(excelImportControllerProvider.notifier)
            .importLastPreviewSnapshotToPortfolio(
              portfolioId: target.portfolioId!,
            );
        return;
      }
      await ref
          .read(excelImportControllerProvider.notifier)
          .importLastPreviewSnapshotWithNewPortfolio(
            portfolioName: target.newPortfolioName!.trim(),
          );
      return;
    }

    if (target.targetMode == ImportTargetMode.existing) {
      await ref
          .read(excelImportControllerProvider.notifier)
          .importLastPreviewToPortfolio(
            portfolioId: target.portfolioId!,
          );
      return;
    }
    await ref
        .read(excelImportControllerProvider.notifier)
        .importLastPreviewWithNewPortfolio(
          portfolioName: target.newPortfolioName!.trim(),
        );
  }

  void _handleImportStateChange(
    ExcelImportFlowState? previous,
    ExcelImportFlowState next,
  ) {
    if (!mounted) {
      return;
    }

    final nextState = next;
    final previousState = previous;

    if (nextState is ExcelImportSuccess) {
      final alreadyShown = previousState is ExcelImportSuccess &&
          previousState.report == nextState.report &&
          previousState.previewOnly == nextState.previewOnly;
      if (alreadyShown) {
        return;
      }

      final portfolios = ref.read(portfolioOptionsProvider);
      unawaited(
        _showImportResultBottomSheet(
          context: context,
          report: nextState.report,
          previewOnly: nextState.previewOnly,
          onFinalizeImport: nextState.previewOnly
              ? () async {
                  final detectedType =
                      nextState.report.analysis['file_type']?.toString();
                  final importTarget = await _selectImportTarget(
                    context,
                    portfolios,
                  );
                  if (!mounted || importTarget == null) {
                    return;
                  }
                  await _finalizeImportWithTarget(
                    detectedType: detectedType,
                    target: importTarget,
                  );
                }
              : null,
        ).whenComplete(
          () {
            if (!mounted) {
              return;
            }
            ref.read(excelImportControllerProvider.notifier).reset();
          },
        ),
      );
      return;
    }

    if (nextState is ExcelImportFileTypeMismatch) {
      final duplicate = previousState is ExcelImportFileTypeMismatch &&
          previousState.report == nextState.report &&
          previousState.previewOnly == nextState.previewOnly &&
          previousState.expectedFileType == nextState.expectedFileType &&
          previousState.detectedFileType == nextState.detectedFileType;
      if (duplicate) {
        return;
      }

      unawaited(
        _showImportTypeMismatchBottomSheet(
          context: context,
          mismatchState: nextState,
          onContinueWithDetectedType: () async {
            if (nextState.detectedFileType == ImportFileType.portfolioSnapshot) {
              await ref
                  .read(excelImportControllerProvider.notifier)
                  .previewLastFileAsSnapshot();
              return;
            }
            await ref
                .read(excelImportControllerProvider.notifier)
                .previewLastFileAsTrades();
          },
          onReUpload: () async {
            await ref
                .read(excelImportControllerProvider.notifier)
                .pickAndPreviewFile(
                  currentSurface: nextState.expectedSurface,
                );
          },
        ).whenComplete(() {
          if (!mounted) {
            return;
          }
          final current = ref.read(excelImportControllerProvider).value;
          if (current is ExcelImportFileTypeMismatch) {
            ref.read(excelImportControllerProvider.notifier).reset();
          }
        }),
      );
      return;
    }

    if (nextState is ExcelImportError) {
      final duplicate = previousState is ExcelImportError &&
          previousState.message == nextState.message;
      if (duplicate) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextState.message)),
      );
    }
  }

  bool _isImportBusy(ExcelImportFlowState state) {
    return state is ExcelImportSelectingFile ||
        state is ExcelImportUploading ||
        state is ExcelImportProcessing;
  }

  bool _isCancellable(ExcelImportFlowState state) {
    return state is ExcelImportUploading || state is ExcelImportProcessing;
  }

  String _fabLabel(ExcelImportFlowState state) {
    if (state is ExcelImportSelectingFile) {
      return 'در حال انتخاب فایل';
    }
    if (state is ExcelImportUploading) {
      return 'در حال آپلود ${(state.progress * 100).round()}٪';
    }
    if (state is ExcelImportProcessing) {
      return 'در حال پردازش';
    }
    return 'ایمپورت اکسل کارگزاری';
  }

}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.portfolioCount});

  final int portfolioCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                  portfolioCount > 0
                    ? '$portfolioCount پرتفوی برای تخصیص سفارش در دسترس است.'
                    : 'هیچ پرتفویی برای تخصیص سفارش موجود نیست.',
                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportStatusCard extends StatelessWidget {
  const _ImportStatusCard({
    required this.state,
    required this.onDismiss,
    this.onCancel,
  });

  final ExcelImportFlowState state;
  final VoidCallback onDismiss;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (state is ExcelImportSelectingFile) {
      return _StatusContainer(
        icon: Icons.folder_open_rounded,
        title: 'در حال انتخاب فایل',
        subtitle: 'لطفا فایل اکسل کارگزاری را انتخاب کنید.',
        child: const LinearProgressIndicator(),
      );
    }

    if (state is ExcelImportUploading) {
      final progress = (state as ExcelImportUploading).progress;
      return _StatusContainer(
        icon: Icons.cloud_upload_rounded,
        title: 'در حال آپلود فایل',
        subtitle: '${(progress * 100).toStringAsFixed(0)}٪ ارسال شد',
        trailing: onCancel == null
            ? null
            : TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('لغو'),
              ),
        child: LinearProgressIndicator(value: progress),
      );
    }

    if (state is ExcelImportProcessing) {
      return _StatusContainer(
        icon: Icons.settings_suggest_rounded,
        title: 'در حال پردازش سرور',
        subtitle: 'فایل آپلود شده و اکنون در حال پردازش است.',
        trailing: onCancel == null
            ? null
            : TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('توقف'),
              ),
        child: const LinearProgressIndicator(),
      );
    }

    if (state is ExcelImportError) {
      final error = state as ExcelImportError;
      return _StatusContainer(
        icon: Icons.error_outline_rounded,
        title: 'ایمپورت ناموفق بود',
        subtitle: error.message,
        trailing: TextButton.icon(
          onPressed: onDismiss,
          icon: const Icon(Icons.done_rounded),
          label: const Text('باشه'),
        ),
        borderColor: scheme.error.withValues(alpha: 0.35),
      );
    }

    if (state is ExcelImportFileTypeMismatch) {
      return _StatusContainer(
        icon: Icons.swap_horiz_rounded,
        title: 'نیازمند تایید مسیر ایمپورت',
        subtitle: 'نوع فایل شناسایی شده با مسیر فعلی متفاوت است.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.child,
    this.borderColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 10),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showImportResultBottomSheet({
  required BuildContext context,
  required ImportReportModel report,
  required bool previewOnly,
  Future<void> Function()? onFinalizeImport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.35,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Text(
                'نتیجه ایمپورت',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              _ImportModeBadge(previewOnly: previewOnly),
              const SizedBox(height: 12),
              _ResultHighlightTile(
                color: context.semanticColors.success,
                icon: Icons.check_circle_rounded,
                title: previewOnly ? 'پیش‌نمایش تکمیل شد' : 'ایمپورت موفق',
                description: previewOnly
                    ? '${_analysisInt(report.analysis, 'valid_rows')} ردیف معتبر برای ثبت نهایی آماده است. هنوز داده‌ای ثبت نشده است.'
                    : '${report.insertedCount} تراکنش جدید با موفقیت ثبت شد.',
              ),
              if (!previewOnly && _importedPortfolioIdFromReport(report).isNotEmpty) ...[
                const SizedBox(height: 8),
                _ResultHighlightTile(
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'پرتفوی مقصد',
                  description: _importedPortfolioIdFromReport(report),
                ),
              ],
              if (report.duplicatesSkippedCount > 0) ...[
                const SizedBox(height: 8),
                _ResultHighlightTile(
                  color: context.semanticColors.warning,
                  icon: Icons.warning_amber_rounded,
                  title: 'هشدار',
                  description: '${report.duplicatesSkippedCount} تراکنش تکراری نادیده گرفته شد.',
                ),
              ],
              const SizedBox(height: 8),
              _ResultHighlightTile(
                color: report.failedCount > 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                icon: report.failedCount > 0
                    ? Icons.report_problem_rounded
                    : Icons.fact_check_rounded,
                title: 'ردیف‌های ناموفق',
                description: '${report.failedCount} ردیف قابل ایمپورت نبود.',
              ),
              const SizedBox(height: 14),
              if (report.errors.isEmpty)
                const ListTile(
                  leading: Icon(Icons.task_alt_rounded),
                  title: Text('خطای سطح ردیف ثبت نشد.'),
                  subtitle: Text('همه ردیف‌های معتبر توسط سیستم پذیرفته شدند.'),
                )
              else
                ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text('گزارش خطا (${report.errors.length})'),
                  subtitle: const Text('برای مشاهده ردیف‌های ناموفق لمس کنید'),
                  children: report.errors
                      .map(
                        (error) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0x22EF4444),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                '${error.rowNumber ?? '?'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: LtrLogText(_friendlyRowErrorMessage(error)),
                          subtitle: LtrLogText(error.detail),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 8),
              if (previewOnly && onFinalizeImport != null) ...[
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await onFinalizeImport();
                  },
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: const Text('تخصیص به پرتفوی و ثبت نهایی'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.done_rounded),
                label: const Text('باشه'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ResultHighlightTile extends StatelessWidget {
  const _ResultHighlightTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(description),
      ),
    );
  }
}

Future<void> _showImportTypeMismatchBottomSheet({
  required BuildContext context,
  required ExcelImportFileTypeMismatch mismatchState,
  required Future<void> Function() onContinueWithDetectedType,
  required Future<void> Function() onReUpload,
}) {
  final expectedLabel = _fileTypeLabel(mismatchState.expectedFileType);
  final detectedLabel = _fileTypeLabel(mismatchState.detectedFileType);
  final continueLabel = switch (mismatchState.detectedFileType) {
    ImportFileType.portfolioSnapshot => 'ادامه با ایمپورت مانده اولیه',
    ImportFileType.tradeLedger => 'ادامه با ایمپورت تاریخچه معاملات',
    ImportFileType.unknown => 'ادامه با مسیر فعلی',
  };

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نوع فایل شناسایی شد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'نوع فایل شناسایی‌شده با مسیر ایمپورت انتخابی تفاوت دارد.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'برای ادامه، می‌توانید ایمپورت را با نوع شناسایی‌شده انجام دهید یا فایل دیگری انتخاب کنید.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LtrLogText('نوع مورد انتظار: $expectedLabel'),
                  const SizedBox(height: 4),
                  LtrLogText('نوع شناسایی‌شده: $detectedLabel'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await onContinueWithDetectedType();
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(continueLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await onReUpload();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('انتخاب فایل دیگر'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('انصراف'),
            ),
          ],
        ),
      );
    },
  );
}

String _fileTypeLabel(ImportFileType type) {
  return switch (type) {
    ImportFileType.tradeLedger => 'تاریخچه معاملات',
    ImportFileType.portfolioSnapshot => 'مانده اولیه پرتفوی',
    ImportFileType.unknown => 'نامشخص',
  };
}

String _friendlyRowErrorMessage(RowErrorModel error) {
  final combined = '${error.title} ${error.detail}'.toLowerCase();

  if (combined.contains('ticker') || combined.contains('symbol')) {
    return '${error.readableLocation}: نماد دارایی نامعتبر است.';
  }
  if (combined.contains('quantity')) {
    return '${error.readableLocation}: مقدار تعداد نامعتبر است.';
  }
  if (combined.contains('price')) {
    return '${error.readableLocation}: فرمت قیمت نامعتبر است.';
  }
  if (combined.contains('date') || combined.contains('executed_at')) {
    return '${error.readableLocation}: تاریخ معامله نامعتبر است.';
  }

  return '${error.readableLocation}: ${error.title}';
}

int _analysisInt(Map<String, dynamic> analysis, String key) {
  final value = analysis[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _importedPortfolioIdFromReport(ImportReportModel report) {
  final job = report.job;
  if (job == null) {
    return '';
  }
  final value = job['portfolio_id']?.toString().trim() ?? '';
  return value;
}

class _ImportModeBadge extends StatelessWidget {
  const _ImportModeBadge({
    required this.previewOnly,
  });

  final bool previewOnly;

  @override
  Widget build(BuildContext context) {
    final color = previewOnly
        ? Theme.of(context).colorScheme.primary
        : context.semanticColors.success;
    final label = previewOnly ? 'حالت پیش‌نمایش (بدون ثبت)' : 'ایمپورت نهایی';
    final icon = previewOnly ? Icons.preview_rounded : Icons.verified_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
