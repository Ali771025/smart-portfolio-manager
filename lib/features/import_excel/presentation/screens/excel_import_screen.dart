import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../portfolio_manager/presentation/providers/portfolio_manager_controller.dart';
import '../../providers/import_controller.dart';

class ExcelImportScreen extends ConsumerStatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  String? _selectedPortfolioId;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(portfolioOptionsProvider);
    final importState = ref.watch(importExcelControllerProvider);
    final busy = importState.phase == ImportPhase.uploading || importState.phase == ImportPhase.polling;

    if (_selectedPortfolioId == null && options.isNotEmpty) {
      _selectedPortfolioId = options.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Import'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_selectedPortfolioId),
              initialValue: _selectedPortfolioId,
              items: options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(option.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() => _selectedPortfolioId = value);
                    },
              decoration: const InputDecoration(
                labelText: 'Select portfolio',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy || (_selectedPortfolioId == null)
                  ? null
                  : () async {
                      final controller = ref.read(importExcelControllerProvider.notifier);
                      final jobId = await controller.uploadFromPicker(
                        portfolioId: _selectedPortfolioId!,
                      );
                      if (jobId == null) {
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      context.push('/trades/excel-import/$jobId');
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                busy ? 'Uploading...' : 'Pick Excel and Upload',
              ),
            ),
            const SizedBox(height: 20),
            if (importState.message != null)
              Text(
                importState.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Trades'),
            ),
          ],
        ),
      ),
    );
  }
}
