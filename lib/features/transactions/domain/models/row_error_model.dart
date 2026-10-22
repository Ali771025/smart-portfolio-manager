// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'row_error_model.freezed.dart';
part 'row_error_model.g.dart';

@freezed
abstract class RowErrorModel with _$RowErrorModel {
  const RowErrorModel._();

  const factory RowErrorModel({
    @Default('about:blank') String type,
    @Default('Import row error') String title,
    @JsonKey(fromJson: _toInt) @Default(400) int status,
    @Default('Unknown row import error.') String detail,
    @Default('') String instance,
    @JsonKey(
      name: 'row_number',
      readValue: _readRowNumber,
      fromJson: _toNullableInt,
    )
    int? rowNumber,
    @JsonKey(name: 'row_payload') Map<String, dynamic>? rowPayload,
  }) = _RowErrorModel;

  factory RowErrorModel.fromJson(Map<String, dynamic> json) =>
      _$RowErrorModelFromJson(json);

  String get readableLocation {
    final row = rowNumber;
    if (row == null) {
      return 'Unknown row';
    }
    return 'Row $row';
  }
}

Object? _readRowNumber(Map<dynamic, dynamic> json, String key) {
  return json[key] ?? json['row'] ?? json['line'];
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _toNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}
