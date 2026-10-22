// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'row_error_model.dart';

part 'import_report_model.freezed.dart';
part 'import_report_model.g.dart';

@freezed
abstract class ImportReportModel with _$ImportReportModel {
  const ImportReportModel._();

  const factory ImportReportModel({
    @JsonKey(name: 'inserted_count', fromJson: _toInt)
    @Default(0)
    int insertedCount,
    @JsonKey(name: 'duplicates_skipped_count', fromJson: _toInt)
    @Default(0)
    int duplicatesSkippedCount,
    @JsonKey(name: 'failed_count', fromJson: _toInt)
    @Default(0)
    int failedCount,
    @Default(<RowErrorModel>[]) List<RowErrorModel> errors,
    @JsonKey(name: 'inserted_reference_hashes')
    @Default(<String>[])
    List<String> insertedReferenceHashes,
    @Default(<String, dynamic>{}) Map<String, dynamic> analysis,
    Map<String, dynamic>? job,
  }) = _ImportReportModel;

  factory ImportReportModel.fromJson(Map<String, dynamic> json) =>
      _$ImportReportModelFromJson(json);

  int get totalProcessed => insertedCount + duplicatesSkippedCount + failedCount;

  String? get jobId => job == null ? null : job!['id']?.toString();
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
