import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

class DecimalStringJsonConverter extends JsonConverter<Decimal, Object?> {
  const DecimalStringJsonConverter();

  @override
  Decimal fromJson(Object? json) {
    if (json == null) {
      return Decimal.zero;
    }
    if (json is String) {
      final trimmed = json.trim();
      if (trimmed.isEmpty) {
        return Decimal.zero;
      }
      return Decimal.parse(trimmed);
    }
    if (json is num) {
      return Decimal.parse(json.toString());
    }
    throw FormatException('Unsupported decimal value type: ${json.runtimeType}');
  }

  @override
  Object toJson(Decimal object) => object.toString();
}
