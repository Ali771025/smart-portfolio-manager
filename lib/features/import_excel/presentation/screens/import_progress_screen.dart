import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bidi_mixed_text.dart';
import '../../../../core/widgets/ltr_log_text.dart';
import '../../providers/import_controller.dart';

class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({
    required this.jobId,
    super.key,
  });

  final String jobId;

  @override
  ConsumerState<ImportProgressScreen> createState() =>
      _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  static const Map<String, String> _persianErrorMessages = <String, String>{
    'UNKNOWN_TRANSACTION_TYPE': 'نوع تراکنش قابل تشخیص نیست',
    'SELL_EXCEEDS_AVAILABLE_QUANTITY':
        'تعداد فروش بیشتر از موجودی قابل فروش است',
    'DIVIDEND_NOT_PERSISTED': 'ثبت سود نقدی انجام نشد',
    'SYMBOL_NOT_RESOLVED': 'نماد شناسایی نشد',
    'DUPLICATE_ROW': 'این ردیف قبلاً وارد شده است',
  };

  static const Map<String, String> _statusLabelFa = <String, String>{
    'inserted': 'ثبت شد',
    'skipped': 'رد شد',
    'warning': 'هشدار',
    'error': 'خطا',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(importExcelControllerProvider.notifier)
          .startPolling(widget.jobId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importExcelControllerProvider);
    final job = state.job;
    final diagnostics = _asMap(job?.diagnostics);
    final summary = _asMap(diagnostics['summary']);
    final detectedByType = _asMap(diagnostics['detected_by_type']);
    final rowResults = _asList(diagnostics['row_results']);

    final totalRows = _asInt(summary['total_rows']) ?? job?.totalRows ?? 0;
    final insertedTransactions =
        _asInt(summary['inserted_transactions']) ?? job?.insertedRows ?? 0;
    final insertedCashEvents = _asInt(summary['inserted_cash_events']) ?? 0;
    final duplicatesSkipped =
        _asInt(summary['duplicate_rows']) ?? job?.duplicatesSkipped ?? 0;
    final skippedRows = _asInt(summary['skipped_rows']) ?? duplicatesSkipped;
    final warnings = _asInt(summary['warning_rows']) ?? 0;
    final errors = _asInt(summary['error_rows']) ?? job?.failedRows ?? 0;
    final insertedRows = _asInt(summary['inserted_rows']) ??
        (insertedTransactions + insertedCashEvents);

    final parsed = job?.parsedRows ?? 0;
    final progress =
        totalRows <= 0 ? 0.0 : (parsed / totalRows).clamp(0.0, 1.0);
    final postRecompute = _asMap(diagnostics['post_import_recompute']);
    final recomputeAt = postRecompute['recomputed_at']?.toString();

    final rowDiagnostics = rowResults
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);

    final fallbackRowsFromErrors = state.errors
        .map(
          (error) => <String, dynamic>{
            'row_number': error.rowNumber,
            'status': 'error',
            'type': error.type ?? 'UNKNOWN',
            'symbol': error.symbol,
            'asset_id': error.assetId,
            'quantity': error.quantity,
            'price': error.price,
            'amount': error.amount,
            'raw_description': error.rawText,
            'normalized_description':
                error.normalizedDescription ?? error.rawText,
            'message': error.errorReason,
            'suggestion': error.suggestion,
          },
        )
        .toList(growable: false);

    final issueRows =
        (rowDiagnostics.isNotEmpty ? rowDiagnostics : fallbackRowsFromErrors)
            .where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status == 'error' || status == 'warning' || status == 'skipped';
    }).toList(growable: false);
    final successfulRows = rowDiagnostics
        .where((item) =>
            (item['status'] ?? '').toString().toLowerCase() == 'inserted')
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('وضعیت ورود فایل'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(importExcelControllerProvider.notifier).refreshNow(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(
            value: state.phase == ImportPhase.completed ||
                    state.phase == ImportPhase.failed
                ? 1
                : progress,
          ),
          const SizedBox(height: 12),
          Text('وضعیت: ${_translateStatus(job?.status ?? state.phase.name)}'),
          if (job?.updatedAt != null)
            Text('آخرین بروزرسانی: ${job!.updatedAt!.toLocal()}'),
          if ((job?.portfolioId ?? '').trim().isNotEmpty)
            Text('پرتفوی مقصد: ${job!.portfolioId}'),
          if (recomputeAt != null && recomputeAt.trim().isNotEmpty)
            Text('زمان بازمحاسبه: $recomputeAt'),
          const SizedBox(height: 12),
          _SummaryGrid(
            totalRows: totalRows,
            insertedTransactions: insertedTransactions,
            insertedCashEvents: insertedCashEvents,
            skippedRows: skippedRows,
            duplicatesSkipped: duplicatesSkipped,
            errors: errors,
            warnings: warnings,
          ),
          const SizedBox(height: 16),
          if (detectedByType.isNotEmpty) ...[
            Text(
              'تفکیک انواع تراکنش شناسایی‌شده',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detectedByType.entries
                  .map(
                    (entry) => Chip(
                      label: Text(
                          '${entry.key}: ${_faInt(_asInt(entry.value) ?? 0)}'),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
          ],
          if (state.message != null) ...[
            Text(
              _toUserFacingMessage(state.message!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (successfulRows.isNotEmpty) ...[
            Text('ردیف‌های واردشده',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...successfulRows
                .map((row) => _buildRowDiagnosticCard(context, row)),
            const SizedBox(height: 16),
          ],
          Text(
            'خطاها و هشدارهای ردیف‌ها',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (issueRows.isEmpty)
            const Text('هنوز خطا یا هشدار ردیفی گزارش نشده است.')
          else
            ...issueRows.map((row) => _buildRowDiagnosticCard(context, row)),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: const Text('جزئیات فنی'),
                subtitle: Text('ردیف‌های ثبت‌شده: ${_faInt(insertedRows)}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  LtrLogText(
                    const JsonEncoder.withIndent('  ').convert(diagnostics),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowDiagnosticCard(
      BuildContext context, Map<String, dynamic> row) {
    final rowNumber = _asInt(row['row_number']);
    final status = (row['status'] ?? '').toString().toLowerCase();
    final detectedType = row['type']?.toString();
    final rawDescription = (row['raw_description'] ?? '').toString();
    final suggestion = (row['suggestion'] ?? '').toString();
    final messageFa = _toPersianMessage(row);
    final symbol = (row['symbol'] ?? '').toString();
    final quantity = (row['quantity'] ?? '').toString();
    final unitPrice = (row['unit_price'] ?? row['price'] ?? '').toString();
    final netAmount = (row['net_amount'] ?? row['amount'] ?? '').toString();
    final inferredFee = (row['inferred_fee'] ?? '').toString();

    final statusFa = _statusLabelFa[status] ?? status;
    final title = rowNumber == null
        ? 'ردیف نامشخص: $messageFa'
        : 'ردیف ${_faInt(rowNumber)}: $messageFa';

    return Card(
      child: ExpansionTile(
        title: Text(title, textDirection: TextDirection.rtl),
        subtitle: Text('وضعیت: $statusFa'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (detectedType != null && detectedType.isNotEmpty)
            _kvRow('نوع', _translateTransactionType(detectedType)),
          if (symbol.isNotEmpty) _kvRow('نماد', symbol),
          if (quantity.isNotEmpty) _kvRow('تعداد', _toFaDigits(quantity)),
          if (unitPrice.isNotEmpty) _kvRow('قیمت', _toFaDigits(unitPrice)),
          if (netAmount.isNotEmpty) _kvRow('مبلغ خالص', _toFaDigits(netAmount)),
          if (inferredFee.isNotEmpty)
            _kvRow('کارمزد تخمینی', _toFaDigits(inferredFee)),
          if (rawDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('شرح خام کارگزار:'),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(rawDescription, textDirection: TextDirection.rtl),
            ),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            _kvRow('پیشنهاد', _toPersianSuggestion(suggestion)),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('جزئیات فنی:'),
            ),
            const SizedBox(height: 4),
            LtrLogText(
              const JsonEncoder.withIndent('  ').convert(row),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(value);
    if (hasLatin) {
      return BidiMixedText(
        rtlPrefix: '$label:',
        ltrContent: value,
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Text('$label: $value', textDirection: TextDirection.rtl),
    );
  }

  String _toPersianMessage(Map<String, dynamic> row) {
    final code = _detectErrorCode(row);
    if (code.isNotEmpty && _persianErrorMessages.containsKey(code)) {
      return _persianErrorMessages[code]!;
    }
    final messageCode = (row['message_code'] ?? '').toString();
    if (messageCode == 'TRADE_INSERTED') {
      return 'معامله با موفقیت شناسایی و ثبت شد.';
    }
    if (messageCode == 'CASH_EVENT_INSERTED') {
      return 'گردش وجه با موفقیت شناسایی شد.';
    }
    final fallback = (row['message'] ?? '').toString().trim();
    if (fallback.isEmpty) {
      return 'خطای نامشخص';
    }
    return fallback;
  }

  static String _translateTransactionType(String type) {
    switch (type.toUpperCase()) {
      case 'BUY':
        return 'خرید';
      case 'SELL':
        return 'فروش';
      case 'DEPOSIT':
        return 'واریز وجه';
      case 'WITHDRAWAL':
        return 'برداشت وجه';
      case 'DIVIDEND':
        return 'سود نقدی';
      case 'FEE':
        return 'کارمزد';
      case 'TAX':
        return 'مالیات';
      default:
        return type;
    }
  }

  String _detectErrorCode(Map<String, dynamic> row) {
    final type = (row['type'] ?? '').toString().toUpperCase();
    final message = (row['message'] ?? '').toString().toLowerCase();

    if (type == 'UNKNOWN' ||
        message.contains('could not detect transaction type')) {
      return 'UNKNOWN_TRANSACTION_TYPE';
    }
    if (message.contains('exceeds available quantity') ||
        message.contains('sell quantity')) {
      return 'SELL_EXCEEDS_AVAILABLE_QUANTITY';
    }
    if (message.contains('symbol not found') ||
        message.contains('resolve asset')) {
      return 'SYMBOL_NOT_RESOLVED';
    }
    if (message.contains('duplicate')) {
      return 'DUPLICATE_ROW';
    }
    if (message.contains('dividend') && message.contains('not inserted')) {
      return 'DIVIDEND_NOT_PERSISTED';
    }
    return '';
  }

  String _toPersianSuggestion(String suggestion) {
    final lower = suggestion.toLowerCase();
    if (lower.contains('manually map')) {
      return 'الگوی این ردیف را به نگاشت نماد یا قوانین پارسر اضافه کنید.';
    }
    if (lower.contains('opening positions')) {
      return 'ابتدا معاملات قدیمی‌تر یا موقعیت‌های اولیه این نماد را وارد کنید.';
    }
    if (lower.contains('auto-create')) {
      return 'نماد را به دارایی موجود نگاشت کنید یا ساخت خودکار نماد را فعال کنید.';
    }
    return suggestion;
  }

  String _toUserFacingMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'وضعیت ورود فایل هنوز مشخص نیست.';
    }
    final lower = trimmed.toLowerCase();
    final looksTechnical = trimmed.contains('{') ||
        trimmed.contains('}') ||
        lower.contains('traceback') ||
        lower.contains('stack trace') ||
        lower.contains('exception:') ||
        lower.contains('sqlalchemy') ||
        lower.contains('fastapi');
    if (looksTechnical) {
      return 'پردازش فایل با خطا روبه‌رو شد. لطفاً خطاهای ردیف‌ها را بررسی کنید یا فایل را دوباره وارد کنید.';
    }
    return trimmed;
  }

  static String _translateStatus(String status) {
    final normalized = status.toUpperCase();
    switch (normalized) {
      case 'PENDING':
        return 'در انتظار';
      case 'PROCESSING':
      case 'POLLING':
        return 'در حال پردازش';
      case 'COMPLETED':
        return 'تکمیل شد';
      case 'FAILED':
        return 'ناموفق';
      case 'UPLOADING':
        return 'در حال بارگذاری';
      default:
        return status;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  static List<Object?> _asList(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _faInt(int value) => _toFaDigits(value.toString());

  static String _toFaDigits(String input) {
    const western = <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = <String>['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var output = input;
    for (var i = 0; i < western.length; i++) {
      output = output.replaceAll(western[i], persian[i]);
    }
    return output;
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalRows,
    required this.insertedTransactions,
    required this.insertedCashEvents,
    required this.skippedRows,
    required this.duplicatesSkipped,
    required this.errors,
    required this.warnings,
  });

  final int totalRows;
  final int insertedTransactions;
  final int insertedCashEvents;
  final int skippedRows;
  final int duplicatesSkipped;
  final int errors;
  final int warnings;

  @override
  Widget build(BuildContext context) {
    final cards = <_SummaryItem>[
      _SummaryItem('کل ردیف‌ها', totalRows, Icons.table_rows_rounded),
      _SummaryItem('معاملات واردشده', insertedTransactions,
          Icons.library_add_check_rounded),
      _SummaryItem('رویدادهای نقدی ثبت‌شده', insertedCashEvents,
          Icons.account_balance_wallet_rounded),
      _SummaryItem(
          'ردیف‌های نادیده‌گرفته‌شده', skippedRows, Icons.skip_next_rounded),
      _SummaryItem('خطاها', errors, Icons.error_outline_rounded),
      _SummaryItem('هشدارها', warnings, Icons.warning_amber_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.label,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _ImportProgressScreenState._faInt(item.value),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}
