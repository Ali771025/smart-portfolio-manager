import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import '../../domain/models/asset_ledger_models.dart';
import 'asset_formatters.dart';
import 'asset_metric_card.dart';

class AssetSummaryKpiRow extends StatelessWidget {
  const AssetSummaryKpiRow({
    required this.summary,
    super.key,
  });

  final PortfolioFrontendSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPartial = summary.calculationStatus.toLowerCase() == 'partial' ||
        summary.hasMissingMarketPrices;
    final missingSymbols = summary.missingPriceSymbols.join('، ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 820
                ? 2
                : 1;

        final cards = <Widget>[
          AssetMetricCard(
            label: isPartial ? 'ارزش کل بازار (ناقص)' : 'ارزش کل بازار',
            value: formatOptionalAssetMoney(
              summary.totalMarketValue,
              fallback: 'نامشخص',
            ),
            icon: Icons.account_balance_wallet_rounded,
            valueColor: summary.totalMarketValue == null
                ? scheme.onSurfaceVariant
                : null,
          ),
          AssetMetricCard(
            label: 'بهای تمام‌شده',
            value: formatAssetMoney(summary.totalCostBasis),
            icon: Icons.inventory_2_rounded,
          ),
          AssetMetricCard(
            label: 'تعداد دارایی‌ها',
            value: summary.holdingsCount.toString(),
            icon: Icons.pie_chart_rounded,
          ),
          AssetMetricCard(
            label: 'سود/زیان تحقق‌یافته',
            value: formatAssetMoney(summary.realizedPnl),
            icon: Icons.task_alt_rounded,
            valueColor: _pnlColor(context, summary.realizedPnl),
          ),
          AssetMetricCard(
            label: isPartial
                ? 'سود/زیان تحقق‌نیافته (ناقص)'
                : 'سود/زیان تحقق‌نیافته',
            value: formatOptionalAssetMoney(
              summary.unrealizedPnl,
              fallback: 'نامشخص',
            ),
            icon: Icons.timeline_rounded,
            valueColor: _pnlColor(context, summary.unrealizedPnl),
          ),
          AssetMetricCard(
            label: isPartial ? 'سود/زیان کل (ناقص)' : 'سود/زیان کل',
            value: formatOptionalAssetMoney(
              summary.totalPnl,
              fallback: 'نامشخص',
            ),
            icon: Icons.calculate_rounded,
            valueColor: _pnlColor(context, summary.totalPnl),
          ),
          AssetMetricCard(
            label: 'بازدهی',
            value: formatOptionalAssetPercent(
              summary.roi ?? summary.totalPnlPercent,
              fallback: '-',
            ),
            icon: Icons.percent_rounded,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.hasMissingMarketPrices) ...[
              _SummaryWarningNotice(
                message: missingSymbols.isEmpty
                    ? 'برای برخی نمادها قیمت بازار موجود نیست؛ بخشی از سود/زیان محاسبه نشده است.'
                    : 'برای نمادهای $missingSymbols قیمت بازار موجود نیست؛ بخشی از سود/زیان محاسبه نشده است.',
              ),
              const SizedBox(height: 10),
            ],
            if (isPartial && !summary.hasMissingMarketPrices) ...[
              const _SummaryWarningNotice(
                message:
                    'محاسبات پرتفوی ناقص است؛ ارزش بازار و سود/زیان ممکن است کامل نباشد.',
              ),
              const SizedBox(height: 10),
            ],
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: width >= 820 ? 2.6 : 2.2,
              children: cards,
            ),
          ],
        );
      },
    );
  }
}

Color _pnlColor(BuildContext context, Decimal? value) {
  final scheme = Theme.of(context).colorScheme;
  if (value == null || value == Decimal.zero) {
    return scheme.onSurfaceVariant;
  }
  return value > Decimal.zero ? Colors.green : scheme.error;
}

class _SummaryWarningNotice extends StatelessWidget {
  const _SummaryWarningNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
