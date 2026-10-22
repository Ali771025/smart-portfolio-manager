import 'package:decimal/decimal.dart';

String formatAssetMoney(Decimal value) {
  final grouped = formatAssetNumber(_stripFraction(value.toString()));
  return 'ریال $grouped';
}

String formatOptionalAssetMoney(Decimal? value, {String fallback = 'ناموجود'}) {
  return value == null ? fallback : formatAssetMoney(value);
}

String formatAssetPercentValue(Decimal percent) {
  final normalized = _trimFraction(percent.toString(), maxFractionDigits: 2);
  return '$normalized%';
}

String formatOptionalAssetPercent(
  Decimal? percent, {
  String fallback = 'ناموجود',
}) {
  return percent == null ? fallback : formatAssetPercentValue(percent);
}

String formatAssetNumber(String raw) {
  final negative = raw.startsWith('-');
  final clean = negative ? raw.substring(1) : raw;
  final parts = clean.split('.');
  final whole = parts.first;
  final fraction =
      parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';

  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final idxFromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }

  final prefix = negative ? '-' : '';
  final grouped = buffer.toString();
  if (fraction.isEmpty) {
    return '$prefix$grouped';
  }
  return '$prefix$grouped.$fraction';
}

String formatTransactionTypeLabel(String transactionType) {
  switch (transactionType) {
    case 'BUY':
      return 'خرید';
    case 'SELL':
      return 'فروش';
    case 'DIVIDEND':
    case 'CASH_DIVIDEND':
      return 'سود نقدی';
    case 'BONUS':
    case 'CAPITAL_INCREASE_BONUS':
      return 'جایزه';
    case 'SPLIT':
    case 'STOCK_SPLIT':
      return 'تجزیه';
    case 'PRE_EMPTIVE_RIGHTS':
      return 'حق تقدم';
    case 'ASSET_TRANSFER':
      return 'انتقال';
    default:
      return transactionType;
  }
}

String _stripFraction(String value) {
  final dotIndex = value.indexOf('.');
  if (dotIndex == -1) {
    return value;
  }
  return value.substring(0, dotIndex);
}

String _trimFraction(String value, {required int maxFractionDigits}) {
  if (!value.contains('.')) {
    return value;
  }
  final parts = value.split('.');
  var fraction = parts[1];
  if (fraction.length > maxFractionDigits) {
    fraction = fraction.substring(0, maxFractionDigits);
  }
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (fraction.isEmpty) {
    return parts[0];
  }
  return '${parts[0]}.$fraction';
}
