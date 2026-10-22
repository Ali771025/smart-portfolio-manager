// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'row_error_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RowErrorModel _$RowErrorModelFromJson(Map<String, dynamic> json) =>
    _RowErrorModel(
      type: json['type'] as String? ?? 'about:blank',
      title: json['title'] as String? ?? 'Import row error',
      status: json['status'] == null ? 400 : _toInt(json['status']),
      detail: json['detail'] as String? ?? 'Unknown row import error.',
      instance: json['instance'] as String? ?? '',
      rowNumber: _toNullableInt(_readRowNumber(json, 'row_number')),
      rowPayload: json['row_payload'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RowErrorModelToJson(_RowErrorModel instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'status': instance.status,
      'detail': instance.detail,
      'instance': instance.instance,
      'row_number': instance.rowNumber,
      'row_payload': instance.rowPayload,
    };
