import 'row_error_model.dart';

enum ImportExceptionType {
  unauthorized,
  validation,
  parseFailure,
  integrityError,
  formatUnsupported,
  cancelled,
  network,
  server,
  unknown,
}

class ImportException implements Exception {
  const ImportException({
    required this.type,
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  });

  const ImportException.unauthorized({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.unauthorized;

  const ImportException.validation({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.validation;

  const ImportException.cancelled({
    this.message = 'Upload cancelled by user.',
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.cancelled;

  const ImportException.network({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.network;

  const ImportException.server({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.server;

  const ImportException.unknown({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.unknown;

  const ImportException.parseFailure({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.parseFailure;

  const ImportException.integrityError({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.integrityError;

  const ImportException.formatUnsupported({
    required this.message,
    this.statusCode,
    this.rowErrors = const <RowErrorModel>[],
    this.problemType,
  }) : type = ImportExceptionType.formatUnsupported;

  final ImportExceptionType type;
  final String message;
  final int? statusCode;
  final List<RowErrorModel> rowErrors;
  final String? problemType;

  bool get isCancelled => type == ImportExceptionType.cancelled;

  @override
  String toString() => message;
}
