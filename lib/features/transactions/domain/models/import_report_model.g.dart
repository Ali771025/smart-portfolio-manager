// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImportReportModel _$ImportReportModelFromJson(Map<String, dynamic> json) =>
    _ImportReportModel(
      insertedCount:
          json['inserted_count'] == null ? 0 : _toInt(json['inserted_count']),
      duplicatesSkippedCount: json['duplicates_skipped_count'] == null
          ? 0
          : _toInt(json['duplicates_skipped_count']),
      failedCount:
          json['failed_count'] == null ? 0 : _toInt(json['failed_count']),
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => RowErrorModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RowErrorModel>[],
      insertedReferenceHashes:
          (json['inserted_reference_hashes'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const <String>[],
      analysis: json['analysis'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      job: json['job'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ImportReportModelToJson(_ImportReportModel instance) =>
    <String, dynamic>{
      'inserted_count': instance.insertedCount,
      'duplicates_skipped_count': instance.duplicatesSkippedCount,
      'failed_count': instance.failedCount,
      'errors': instance.errors,
      'inserted_reference_hashes': instance.insertedReferenceHashes,
      'analysis': instance.analysis,
      'job': instance.job,
    };
