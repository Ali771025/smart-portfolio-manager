import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_base_url.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class ImportJobErrorDto {
  const ImportJobErrorDto({
    required this.rowNumber,
    required this.rawText,
    required this.errorReason,
    this.type,
    this.symbol,
    this.assetId,
    this.quantity,
    this.price,
    this.amount,
    this.normalizedDescription,
    this.suggestion,
  });

  final int? rowNumber;
  final String rawText;
  final String errorReason;
  final String? type;
  final String? symbol;
  final String? assetId;
  final String? quantity;
  final String? price;
  final String? amount;
  final String? normalizedDescription;
  final String? suggestion;

  factory ImportJobErrorDto.fromJson(Map<String, dynamic> json) {
    return ImportJobErrorDto(
      rowNumber: json['row_number'] as int?,
      rawText: (json['raw_text'] ?? '').toString(),
      errorReason: (json['error_reason'] ?? 'Unknown parse error').toString(),
      type: json['type']?.toString(),
      symbol: json['symbol']?.toString(),
      assetId: json['asset_id']?.toString(),
      quantity: json['quantity']?.toString(),
      price: json['price']?.toString(),
      amount: json['amount']?.toString(),
      normalizedDescription: json['normalized_description']?.toString(),
      suggestion: json['suggestion']?.toString(),
    );
  }
}

class ImportJobDto {
  const ImportJobDto({
    required this.id,
    required this.portfolioId,
    required this.status,
    required this.sourceFilename,
    required this.totalRows,
    required this.parsedRows,
    required this.insertedRows,
    required this.failedRows,
    required this.duplicatesSkipped,
    required this.diagnostics,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String portfolioId;
  final String status;
  final String sourceFilename;
  final int totalRows;
  final int parsedRows;
  final int insertedRows;
  final int failedRows;
  final int duplicatesSkipped;
  final Map<String, dynamic> diagnostics;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isTerminal => status == 'COMPLETED' || status == 'FAILED';

  factory ImportJobDto.fromJson(Map<String, dynamic> json) {
    return ImportJobDto(
      id: (json['id'] ?? '').toString(),
      portfolioId: (json['portfolio_id'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      sourceFilename: (json['source_filename'] ?? '').toString(),
      totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
      parsedRows: (json['parsed_rows'] as num?)?.toInt() ?? 0,
      insertedRows: (json['inserted_rows'] as num?)?.toInt() ?? 0,
      failedRows: (json['failed_rows'] as num?)?.toInt() ?? 0,
      duplicatesSkipped: (json['duplicates_skipped'] as num?)?.toInt() ?? 0,
      diagnostics: (json['diagnostics'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      completedAt: _asDateTime(json['completed_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

DateTime? _asDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) {
    return null;
  }
  return parsed.toUtc();
}

class ImportUploadFile {
  const ImportUploadFile({
    required this.fileName,
    this.path,
    this.bytes,
  });

  final String fileName;
  final String? path;
  final List<int>? bytes;

  bool get hasPath => path != null && path!.trim().isNotEmpty;
  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

class ImportRepositoryException implements Exception {
  const ImportRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ImportRepository {
  Future<ImportJobDto> uploadExcel({
    required String portfolioId,
    required ImportUploadFile file,
  });

  Future<ImportJobDto> getJobStatus({
    required String jobId,
  });

  Future<List<ImportJobErrorDto>> getJobErrors({
    required String jobId,
  });
}

class DioImportRepository implements ImportRepository {
  DioImportRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<ImportJobDto> uploadExcel({
    required String portfolioId,
    required ImportUploadFile file,
  }) async {
    final token = _tokenOrThrow();
    final normalizedPortfolioId = portfolioId.trim();
    if (!_isUuid(normalizedPortfolioId)) {
      throw const ImportRepositoryException(
        'شناسه پرتفوی معتبر نیست. لطفاً یک پرتفوی معتبر انتخاب کنید.',
      );
    }
    final multipart = await _buildMultipartFile(file);
    final formData = FormData.fromMap(
      <String, Object?>{
        'portfolio_id': normalizedPortfolioId,
        'file': multipart,
      },
    );

    try {
      final response = await dio.post<Object?>(
        '/import/excel',
        data: formData,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const ImportRepositoryException(
            'Server returned an invalid response.');
      }
      final rawJob = body['job'];
      if (rawJob is! Map) {
        throw const ImportRepositoryException('Import job payload is missing.');
      }
      return ImportJobDto.fromJson(Map<String, dynamic>.from(rawJob));
    } on DioException catch (error) {
      throw ImportRepositoryException(_dioMessage(error));
    }
  }

  @override
  Future<ImportJobDto> getJobStatus({required String jobId}) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/import/$jobId',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const ImportRepositoryException(
            'Server returned an invalid job status response.');
      }
      return ImportJobDto.fromJson(body);
    } on DioException catch (error) {
      throw ImportRepositoryException(_dioMessage(error));
    }
  }

  @override
  Future<List<ImportJobErrorDto>> getJobErrors({required String jobId}) async {
    final token = _tokenOrThrow();
    try {
      final response = await dio.get<Object?>(
        '/import/$jobId/errors',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final body = _decodeMap(response.data);
      if (body == null) {
        throw const ImportRepositoryException(
            'Server returned an invalid error payload.');
      }
      final rawErrors = body['errors'];
      if (rawErrors is! List) {
        return const <ImportJobErrorDto>[];
      }
      return rawErrors
          .whereType<Map>()
          .map((item) =>
              ImportJobErrorDto.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ImportRepositoryException(_dioMessage(error));
    }
  }

  String _tokenOrThrow() {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const ImportRepositoryException(
          'Your session has expired. Please sign in again.');
    }
    return token;
  }

  Future<MultipartFile> _buildMultipartFile(ImportUploadFile file) async {
    if (file.hasBytes) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.fileName);
    }
    if (file.hasPath) {
      return MultipartFile.fromFile(file.path!, filename: file.fileName);
    }
    throw const ImportRepositoryException('Selected file is not accessible.');
  }

  String _dioMessage(DioException error) {
    final payload = _decodeMap(error.response?.data);
    final detail = payload?['detail'];
    final message = _extractDetailMessage(detail);
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }
    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'Unexpected network error during Excel import.';
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String? _extractDetailMessage(Object? detail) {
    if (detail is String) {
      return detail;
    }
    if (detail is List) {
      final hasPortfolioUuidError = detail.whereType<Map>().any((item) {
        final type = item['type']?.toString();
        final loc = item['loc'];
        return type == 'uuid_parsing' &&
            loc is List &&
            loc.map((part) => part.toString()).contains('portfolio_id');
      });
      if (hasPortfolioUuidError) {
        return 'شناسه پرتفوی معتبر نیست. لطفاً یک پرتفوی معتبر انتخاب کنید.';
      }
    }
    return null;
  }

  Map<String, dynamic>? _decodeMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

final importDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return DioImportRepository(
    dio: ref.watch(importDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
