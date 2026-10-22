import 'package:flutter/material.dart';

import '../../../portfolio/presentation/providers/portfolio_providers.dart';

class AssetsHeader extends StatelessWidget {
  const AssetsHeader({
    required this.portfolios,
    required this.selectedPortfolioId,
    required this.onPortfolioChanged,
    required this.onRefresh,
    required this.onAddAsset,
    required this.onAddTransaction,
    super.key,
  });

  final List<PortfolioListItem> portfolios;
  final String? selectedPortfolioId;
  final ValueChanged<String> onPortfolioChanged;
  final VoidCallback onRefresh;
  final VoidCallback onAddAsset;
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.candlestick_chart_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دارایی‌ها',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'موقعیت‌ها، قیمت لحظه‌ای، سود/زیان و دفتر معاملات',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('به‌روزرسانی'),
              ),
              OutlinedButton.icon(
                onPressed: onAddAsset,
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('افزودن دارایی'),
              ),
              OutlinedButton.icon(
                onPressed: onAddTransaction,
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('افزودن تراکنش'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedPortfolioId,
            decoration: const InputDecoration(
              labelText: 'انتخاب پرتفوی',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            items: portfolios
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                onPortfolioChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
