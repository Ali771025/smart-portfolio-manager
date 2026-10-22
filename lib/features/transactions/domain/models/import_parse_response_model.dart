import 'package:intl/intl.dart' as intl;

/// Canonical frontend import file type aligned with backend `file_type`.
enum ImportFileType {
  tradeLedger,
  portfolioSnapshot,
  unknown;

  static ImportFileType fromBackend(String? value) {
    return switch (value?.trim()) {
      'TRADE_LEDGER' => ImportFileType.tradeLedger,
      'PORTFOLIO_SNAPSHOT' => ImportFileType.portfolioSnapshot,
      _ => ImportFileType.unknown,
    };
  }

  String get backendValue {
    return switch (this) {
      ImportFileType.tradeLedger => 'TRADE_LEDGER',
      ImportFileType.portfolioSnapshot => 'PORTFOLIO_SNAPSHOT',
      ImportFileType.unknown => 'UNKNOWN',
    };
  }
}

/// Typed parse contract for `/import/parse`.
///
/// The backend returns a strict discriminated payload by `file_type`.
class ImportParseResponseModel {
  const ImportParseResponseModel({
    required this.status,
    required this.fileType,
    required this.invalidRowsCount,
  });

  final String status;
  final ImportFileType fileType;
  final int invalidRowsCount;

  bool get isSuccess => status.trim().toLowerCase() == 'success';

  factory ImportParseResponseModel.fromJson(Map<String, dynamic> json) {
    return ImportParseResponseModel(
      status: (json['status']?.toString() ?? 'unknown').trim(),
      fileType: ImportFileType.fromBackend(json['file_type']?.toString()),
      invalidRowsCount: _toInt(json['invalid_rows_count']),
    );
  }
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(intl.Bidi.stripHtmlIfNeeded(value?.toString() ?? '')) ?? 0;
}
