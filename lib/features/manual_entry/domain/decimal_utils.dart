import 'package:decimal/decimal.dart';

final Decimal decimalZero = Decimal.zero;

Decimal parseDecimalOrZero(String raw) {
  final cleaned = raw.replaceAll(',', '').trim();
  if (cleaned.isEmpty) {
    return decimalZero;
  }
  try {
    return Decimal.parse(cleaned);
  } catch (_) {
    return decimalZero;
  }
}

String decimalToApiString(Decimal value) {
  return value.toString();
}
