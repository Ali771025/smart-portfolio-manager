import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/import_exception.dart';
import '../domain/models/import_parse_response_model.dart';
import '../domain/models/import_report_model.dart';
import '../domain/models/row_error_model.dart';

part 'transaction_repository.g.dart';

const int _maxImportFileSizeBytes = 10 * 1024 * 1024;

class ImportFilePayload {
  const ImportFilePayload({
    required this.fileName,
    this.path,
    this.bytes,
  });

  final String fileName;
  final String? path;
  final List<int>? bytes;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;

  bool get hasPath => path != null && path!.trim().isNotEmpty;
}

enum ImportEndpointKind {
  trades,
  portfolioSnapshot,
}

enum ImportTargetMode {
  existing,
  createNew,
}

class ImportTargetPayload {
  const ImportTargetPayload.existing({
    required this.portfolioId,
  })  : targetMode = ImportTargetMode.existing,
        newPortfolioName = null;

  const ImportTargetPayload.createNew({
    required this.newPortfolioName,
  })  : targetMode = ImportTargetMode.createNew,
        portfolioId = null;

  final ImportTargetMode targetMode;
  final String? portfolioId;
  final String? newPortfolioName;
}

abstract class TransactionRepository {
  Future<ImportParseResponseModel> detectImportFileType({
    required ImportFilePayload file,
    CancelToken? cancelToken,
  });

  Future<ImportReportModel> importTradesFromExcel({
    ImportTargetPayload? importTarget,
    required bool previewOnly,
    ImportEndpointKind endpointKind = ImportEndpointKind.trades,
    required ImportFilePayload file,
    required void Function(double progress) onSendProgress,
    CancelToken? cancelToken,
  });
}

class TransactionApiRepository implements TransactionRepository {
  TransactionApiRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<ImportParseResponseModel> detectImportFileType({
    required ImportFilePayload file,
    CancelToken? cancelToken,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const ImportException.unauthorized(
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final multipartFile = await _buildMultipartFile(file);
    final formData = FormData.fromMap(<String, Object?>{
      'file': multipartFile,
    });

    try {
      final response = await dio.post<Object?>(
        '/import/parse',
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final body = _decodeMap(response.data);
      if (body == null) {
        throw const ImportException.server(
          message: 'Parse completed but the server response is invalid.',
        );
      }
      return ImportParseResponseModel.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on ImportException {
      rethrow;
    } catch (_) {
      throw const ImportException.unknown(
        message: 'Unexpected error happened while parsing broker Excel file.',
      );
    }
  }

  @override
  Future<ImportReportModel> importTradesFromExcel({
    ImportTargetPayload? importTarget,
    required bool previewOnly,
    ImportEndpointKind endpointKind = ImportEndpointKind.trades,
    required ImportFilePayload file,
    required void Function(double progress) onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const ImportException.unauthorized(
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final normalizedPortfolioId = importTarget?.portfolioId?.trim();
    final normalizedNewName = importTarget?.newPortfolioName?.trim();
    final targetMode = importTarget?.targetMode ?? ImportTargetMode.existing;
    if (!previewOnly) {
      if (targetMode == ImportTargetMode.existing &&
          (normalizedPortfolioId == null || normalizedPortfolioId.isEmpty)) {
        throw const ImportException.validation(
          message: 'A portfolio must be selected before final import.',
        );
      }
      if (targetMode == ImportTargetMode.createNew &&
          (normalizedNewName == null || normalizedNewName.isEmpty)) {
        throw const ImportException.validation(
          message: 'A portfolio name is required when creating a new portfolio.',
        );
      }
    }

    final multipartFile = await _buildMultipartFile(file);

    final formData = FormData.fromMap(
      <String, Object?>{
        'preview_only': previewOnly.toString(),
        'target_mode': targetMode == ImportTargetMode.existing ? 'existing' : 'new',
        if (!previewOnly &&
            targetMode == ImportTargetMode.existing &&
            normalizedPortfolioId != null &&
            normalizedPortfolioId.isNotEmpty)
          'portfolio_id': normalizedPortfolioId,
        if (!previewOnly &&
            targetMode == ImportTargetMode.createNew &&
            normalizedNewName != null &&
            normalizedNewName.isNotEmpty)
          'name': normalizedNewName,
        'file': multipartFile,
      },
    );

    try {
      final endpointPath = endpointKind == ImportEndpointKind.portfolioSnapshot
          ? '/import/portfolio-snapshot'
          : '/import/trades';
      final response = await dio.post<Object?>(
        endpointPath,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
        onSendProgress: (sent, total) {
          if (total <= 0) {
            onSendProgress(0);
            return;
          }
          final progress = (sent / total).clamp(0, 1).toDouble();
          onSendProgress(progress);
        },
      );

      onSendProgress(1);

      final body = _decodeMap(response.data);
      if (body == null) {
        throw const ImportException.server(
          message: 'Import completed but the server response is invalid.',
        );
      }

      return ImportReportModel.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on ImportException {
      rethrow;
    } catch (_) {
      throw const ImportException.unknown(
        message: 'Unexpected error happened while importing broker Excel file.',
      );
    }
  }

  Future<MultipartFile> _buildMultipartFile(ImportFilePayload file) async {
    final lowerName = file.fileName.trim().toLowerCase();
    final validExt = lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.xlsm') ||
        lowerName.endsWith('.xls');
    if (!validExt) {
      throw const ImportException.validation(
        message: 'Only .xlsx, .xlsm, and .xls files are supported.',
      );
    }

    if (file.hasBytes) {
      if (file.bytes!.length > _maxImportFileSizeBytes) {
        throw const ImportException.validation(
          message: 'Selected file exceeds the 10 MB upload limit.',
        );
      }
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: file.fileName,
      );
    }

    if (!file.hasPath) {
      throw const ImportException.validation(
        message: 'Selected file is not accessible. Please choose another file.',
      );
    }

    return MultipartFile.fromFile(
      file.path!,
      filename: file.fileName,
    );
  }

  ImportException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ImportException.cancelled();
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const ImportException.network(
        message: 'Network timeout while uploading the file. Please retry.',
      );
    }

    final response = error.response;
    final payload = _decodeMap(response?.data);
    final message = _problemMessage(payload) ??
        error.message ??
        'Upload failed due to an unexpected server error.';
    final rowErrors = _extractRowErrors(payload);
    final statusCode = response?.statusCode;
    final problemType = payload?['type']?.toString();

    if (statusCode == 401) {
      return ImportException.unauthorized(
        message: message,
        statusCode: statusCode,
        rowErrors: rowErrors,
        problemType: problemType,
      );
    }

    // Map specific problem types to appropriate exception types
    if (problemType != null) {
      final lowerProblemType = problemType.toLowerCase();
      if (lowerProblemType.contains('parse') || lowerProblemType == 'parse_failure') {
        return ImportException.parseFailure(
          message: message,
          statusCode: statusCode,
          rowErrors: rowErrors,
          problemType: problemType,
        );
      }
      if (lowerProblemType.contains('format') || lowerProblemType == 'format_unsupported') {
        return ImportException.formatUnsupported(
          message: message,
          statusCode: statusCode,
          rowErrors: rowErrors,
          problemType: problemType,
        );
      }
      if (lowerProblemType.contains('integrity') || lowerProblemType == 'integrity_error' || statusCode == 409) {
        return ImportException.integrityError(
          message: message,
          statusCode: statusCode,
          rowErrors: rowErrors,
          problemType: problemType,
        );
      }
    }

    // Fallback to validation for client errors
    if (statusCode == 400 || statusCode == 404 || statusCode == 413 || statusCode == 415 || statusCode == 422) {
      return ImportException.validation(
        message: message,
        statusCode: statusCode,
        rowErrors: rowErrors,
        problemType: problemType,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ImportException.server(
        message: message,
        statusCode: statusCode,
        rowErrors: rowErrors,
        problemType: problemType,
      );
    }

    return ImportException.unknown(
      message: message,
      statusCode: statusCode,
      rowErrors: rowErrors,
      problemType: problemType,
    );
  }

  Map<String, dynamic>? _decodeMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _problemMessage(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    final detail = payload['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final item = Map<String, dynamic>.from(first);
        final message = item['msg']?.toString();
        final location = (item['loc'] as List<dynamic>?)
            ?.whereType<Object>()
            .map((value) => value.toString())
            .join('.');
        if (message != null && message.trim().isNotEmpty) {
          if (location != null && location.isNotEmpty) {
            return '$location: ${message.trim()}';
          }
          return message.trim();
        }
      }
      return detail.first.toString();
    }

    final title = payload['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }

    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        final firstMap = Map<String, dynamic>.from(first);
        final firstDetail = firstMap['detail']?.toString();
        if (firstDetail != null && firstDetail.trim().isNotEmpty) {
          return firstDetail.trim();
        }
      }
      return 'Import validation failed for one or more rows.';
    }

    return null;
  }

  List<RowErrorModel> _extractRowErrors(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const <RowErrorModel>[];
    }

    final errors = payload['errors'];
    if (errors is! List) {
      return const <RowErrorModel>[];
    }

    return errors
        .whereType<Map>()
        .map((item) {
          try {
            return RowErrorModel.fromJson(Map<String, dynamic>.from(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<RowErrorModel>()
        .toList(growable: false);
  }
}

@Riverpod(keepAlive: true)
Dio transactionDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 2),
      responseType: ResponseType.json,
    ),
  );

  ref.onDispose(dio.close);
  return dio;
}

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  return TransactionApiRepository(
    dio: ref.watch(transactionDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
}
