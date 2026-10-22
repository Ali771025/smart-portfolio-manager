import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/import_entities.dart';
import '../providers/import_flow_controller.dart';
import '../state/import_flow_state.dart';

class MultiPortfolioImportScreen extends ConsumerWidget {
  const MultiPortfolioImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importFlowControllerProvider);
    final controller = ref.read(importFlowControllerProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ایمپورت چندپرتفویی'),
          actions: [
            IconButton(
              onPressed: (state.isLoading || state.isCreatingPortfolio) ? null : controller.loadPortfolios,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DestinationSection(state: state),
              const SizedBox(height: 12),
              _FileSection(state: state),
              const SizedBox(height: 12),
              _PreviewSection(state: state),
              const SizedBox(height: 12),
              _ResultSection(state: state),
              const SizedBox(height: 12),
              _PerformanceSection(state: state),
              if ((state.destinationValidationMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.destinationValidationMessage!),
              ],
              if ((state.portfolioCreationError ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.portfolioCreationError!),
              ],
              if ((state.globalErrorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.globalErrorMessage!),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: (state.isLoading || state.isCreatingPortfolio) ? null : controller.pickExcelFile,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('انتخاب فایل اکسل'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: state.canPreviewImport ? controller.buildPreview : null,
                    icon: const Icon(Icons.preview_rounded),
                    label: const Text('پیش‌نمایش'),
                  ),
                  FilledButton.icon(
                    onPressed: state.canConfirmImport ? controller.confirmImport : null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('تأیید ایمپورت'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationSection extends ConsumerWidget {
  const _DestinationSection({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importFlowControllerProvider.notifier);
    final disabled = state.isLoading || state.isCreatingPortfolio;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('۱) انتخاب پرتفوی مقصد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<DestinationSelectionMode>(
              segments: const [
                ButtonSegment(
                  value: DestinationSelectionMode.existing,
                  icon: Icon(Icons.list_alt_rounded),
                  label: Text('انتخاب پرتفوی موجود'),
                ),
                ButtonSegment(
                  value: DestinationSelectionMode.createNew,
                  icon: Icon(Icons.add_circle_outline_rounded),
                  label: Text('ایجاد پرتفوی جدید'),
                ),
              ],
              selected: <DestinationSelectionMode>{state.selectionMode},
              onSelectionChanged: disabled
                  ? null
                  : (selection) => controller.setSelectionMode(selection.first),
            ),
            const SizedBox(height: 12),
            if (state.selectionMode == DestinationSelectionMode.existing)
              _ExistingPortfolioMode(state: state)
            else
              _CreatePortfolioMode(state: state),
            if ((state.selectedPortfolioId ?? '').isNotEmpty &&
                (state.selectedPortfolioName ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'پرتفوی مقصد: ${state.selectedPortfolioName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExistingPortfolioMode extends ConsumerWidget {
  const _ExistingPortfolioMode({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importFlowControllerProvider.notifier);
    final disabled = state.isLoading || state.isCreatingPortfolio;

    return DropdownButtonFormField<String>(
      initialValue: state.selectedPortfolioId,
      decoration: const InputDecoration(
        labelText: 'پرتفوی موجود',
        hintText: 'یک پرتفوی را انتخاب کنید',
      ),
      items: state.portfolios
          .map(
            (portfolio) => DropdownMenuItem<String>(
              value: portfolio.id,
              child: Text(portfolio.name),
            ),
          )
          .toList(growable: false),
      onChanged: disabled
          ? null
          : (value) {
              if (value != null && value.trim().isNotEmpty) {
                controller.selectExistingPortfolio(value);
              }
            },
    );
  }
}

class _CreatePortfolioMode extends ConsumerWidget {
  const _CreatePortfolioMode({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importFlowControllerProvider.notifier);
    final disabled = state.isLoading || state.isCreatingPortfolio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: state.newPortfolioName,
          enabled: !disabled,
          decoration: const InputDecoration(
            labelText: 'نام پرتفوی (الزامی)',
            hintText: 'مثال: پرتفوی آگاه - میان‌مدت',
          ),
          onChanged: controller.updateNewPortfolioName,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BrokerType>(
          initialValue: state.newPortfolioBrokerType,
          decoration: const InputDecoration(labelText: 'نوع کارگزار (اختیاری)'),
          items: const [
            DropdownMenuItem(value: BrokerType.agah, child: Text('آگاه')),
            DropdownMenuItem(value: BrokerType.mofid, child: Text('مفید')),
            DropdownMenuItem(value: BrokerType.boursiran, child: Text('بورسیران')),
            DropdownMenuItem(value: BrokerType.unknown, child: Text('سایر')),
          ],
          onChanged: disabled
              ? null
              : (value) {
                  if (value != null) {
                    controller.updateNewPortfolioBrokerType(value);
                  }
                },
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: state.newPortfolioManagerName,
          enabled: !disabled,
          decoration: const InputDecoration(
            labelText: 'نام مدیر (اختیاری)',
          ),
          onChanged: controller.updateNewPortfolioManagerName,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: state.canCreatePortfolio ? controller.createPortfolioIfNeeded : null,
          icon: state.isCreatingPortfolio
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_task_rounded),
          label: Text(state.isCreatingPortfolio ? 'در حال ایجاد...' : 'ایجاد و انتخاب پرتفوی'),
        ),
      ],
    );
  }
}

class _FileSection extends StatelessWidget {
  const _FileSection({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('۲) انتخاب فایل', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              state.selectedFileName ?? 'هیچ فایلی انتخاب نشده است.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('۳) پیش‌نمایش', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (preview == null)
              const Text('پیش‌نمایش هنوز ساخته نشده است.')
            else ...[
              Row(
                children: [
                  _Badge(
                    text: _brokerTitle(preview.detectedBroker),
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    text: preview.detectedImportType == ImportType.holdingsSnapshot
                        ? 'Snapshot بورسیران'
                        : 'Ledger تراکنش',
                    color: preview.detectedImportType == ImportType.holdingsSnapshot ? Colors.deepPurple : Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'کل: ${preview.totalRows} | معتبر: ${preview.validRows} | نامعتبر: ${preview.invalidRows} | تکراری: ${preview.duplicateRows}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('۴) نتیجه نهایی', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (result == null)
              const Text('هنوز ایمپورتی ثبت نشده است.')
            else ...[
              Text('پرتفوی مقصد: ${state.selectedPortfolioName ?? result.portfolioId}'),
              Text('شناسه پرتفوی: ${result.portfolioId}'),
              Text('وضعیت: ${result.status}'),
              Text('واردشده: ${result.importedRows}'),
              Text('تکراری: ${result.duplicateRows}'),
              Text('نامعتبر: ${result.invalidRows}'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(result.errors.join('\n')),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context) {
    final portfolio = state.portfolioPerformance;
    final aggregate = state.aggregatePerformance;
    final managers = state.managerComparison;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('۵) عملکرد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (portfolio != null) ...[
              Text('پرتفوی: ${portfolio.portfolioName}'),
              Text('سرمایه: ${portfolio.totalInvested}'),
              Text('ارزش فعلی: ${portfolio.totalCurrentValue}'),
              Text('بازده: ${portfolio.roiPercent}%'),
            ],
            if (aggregate != null) ...[
              const Divider(height: 20),
              Text('تجمیعی - تعداد پرتفوی: ${aggregate.portfolioCount}'),
              Text('سرمایه کل: ${aggregate.totalInvested}'),
              Text('ارزش کل: ${aggregate.totalCurrentValue}'),
              Text('ROI کل: ${aggregate.roiPercent}%'),
            ],
            if (managers.isNotEmpty) ...[
              const Divider(height: 20),
              Text('مقایسه مدیران', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              ...managers.map(
                (row) => Text('${_brokerTitle(row.manager)} | پرتفوی: ${row.portfolios} | ROI: ${row.roiPercent}%'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _brokerTitle(BrokerType broker) {
  switch (broker) {
    case BrokerType.agah:
      return 'آگاه';
    case BrokerType.mofid:
      return 'مفید';
    case BrokerType.boursiran:
      return 'بورسیران';
    case BrokerType.unknown:
      return 'نامشخص';
  }
}
