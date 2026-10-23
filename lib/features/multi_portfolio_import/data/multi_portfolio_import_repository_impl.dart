import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_base_url.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'import_error_mapper.dart';
import '../domain/entities/import_entities.dart';
import '../domain/repositories/multi_portfolio_import_repository.dart';

class MultiPortfolioImportApiRepository implements MultiPortfolioImportRepository {
  MultiPortfolioImportApiRepository({
    required this.dio,
    required this.readAccessToken,
  });

  final Dio dio;
  final String? Function() readAccessToken;

  @override
  Future<List<PortfolioOption>> listPortfolios() async {
    final response = await _authorizedGet('/portfolios');
    final payload = _asList(response.data);
    return payload
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return PortfolioOption(
            id: (map['id'] ?? map['portfolio_id'] ?? '').toString(),
            name: (map['name'] ?? map['portfolio_name'] ?? 'پرتفوی بدون نام').toString(),
          );
        })
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<PortfolioOption> createPortfolio({
    required String name,
    required BrokerType manager,
  }) async {
    final response = await _authorizedPost(
      '/portfolios',
      data: <String, dynamic>{
        'name': name,
        'base_currency': 'IRR',
      },
    );
    final payload = _asMap(response.data);
    final id = (payload['id'] ?? payload['portfolio_id'] ?? '').toString();
    if (id.isEmpty) {
      throw const FormatException('Invalid portfolio creation response.');
    }

    await assignManager(portfolioId: id, manager: manager);
    return PortfolioOption(id: id, name: (payload['name'] ?? name).toString());
  }

  @override
  Future<ImportPreviewEntity> buildPreview({
    required String portfolioId,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    final multipartFile = await _buildMultipartFile(
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
    );
    final response = await _authorizedPost(
      '/imports/multi/preview',
      data: FormData.fromMap(
        <String, Object?>{
          'portfolio_id': portfolioId,
          'file': multipartFile,
        },
      ),
    );

    final payload = _asMap(response.data);
    final summary = Map<String, dynamic>.from((payload['summary'] as Map?) ?? const <String, dynamic>{});
    final rowsRaw = _asList(payload['rows']);
    return ImportPreviewEntity(
      previewId: payload['preview_id'].toString(),
      portfolioId: payload['portfolio_id'].toString(),
      detectedBroker: _brokerFromApi(payload['detected_broker']?.toString()),
      detectedImportType: _importTypeFromApi(payload['detected_import_type']?.toString()),
      totalRows: _asInt(summary['total_rows']),
      validRows: _asInt(summary['valid_rows']),
      invalidRows: _asInt(summary['invalid_rows']),
      duplicateRows: _asInt(summary['duplicate_rows']),
      warnings: _asList(summary['warnings']).map((e) => e.toString()).toList(growable: false),
      rows: rowsRaw
          .whereType<Map>()
          .map(
            (row) => _mapPreviewRow(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<ImportResultEntity> confirmImport({
    required String previewId,
  }) async {
    final response = await _authorizedPost(
      '/imports/multi/confirm',
      data: <String, dynamic>{
        'preview_id': previewId,
      },
    );
    final payload = _asMap(response.data);
    return ImportResultEntity(
      jobId: payload['job_id']?.toString(),
      portfolioId: payload['portfolio_id'].toString(),
      broker: _brokerFromApi(payload['broker']?.toString()),
      importType: _importTypeFromApi(payload['import_type']?.toString()),
      status: (payload['status'] ?? '').toString(),
      importedRows: _asInt(payload['imported_rows']),
      duplicateRows: _asInt(payload['duplicate_rows']),
      invalidRows: _asInt(payload['invalid_rows']),
      errors: _asList(payload['errors']).map((e) => e.toString()).toList(growable: false),
    );
  }

  @override
  Future<void> addManualTransaction({
    required String portfolioId,
    required String symbol,
    required String transactionType,
    required String quantity,
    required String price,
    String? notes,
  }) async {
    await _authorizedPost(
      '/imports/multi/manual',
      data: <String, dynamic>{
        'portfolio_id': portfolioId,
        'symbol': symbol.trim().toUpperCase(),
        'transaction_type': transactionType.trim().toUpperCase(),
        'quantity': quantity,
        'price': price,
        'notes': notes,
      },
    );
  }

  @override
  Future<void> assignManager({
    required String portfolioId,
    required BrokerType manager,
  }) async {
    await _authorizedPut(
      '/imports/multi/portfolios/$portfolioId/manager',
      data: <String, dynamic>{
        'manager': _brokerToApi(manager),
      },
    );
  }

  @override
  Future<PortfolioPerformanceEntity> getPortfolioPerformance({
    required String portfolioId,
  }) async {
    final response = await _authorizedGet('/imports/multi/performance/portfolio/$portfolioId');
    final payload = _asMap(response.data);
    return PortfolioPerformanceEntity(
      portfolioId: payload['portfolio_id'].toString(),
      portfolioName: (payload['portfolio_name'] ?? '').toString(),
      manager: _brokerFromApi(payload['manager']?.toString()),
      totalInvested: _asDecimal(payload['total_invested']),
      totalCurrentValue: _asDecimal(payload['total_current_value']),
      totalPnl: _asDecimal(payload['total_pnl']),
      roiPercent: _asDecimal(payload['roi_percent']),
    );
  }

  @override
  Future<AggregatePerformanceEntity> getAggregatePerformance() async {
    final response = await _authorizedGet('/imports/multi/performance/aggregate');
    final payload = _asMap(response.data);
    return AggregatePerformanceEntity(
      portfolioCount: _asInt(payload['portfolio_count']),
      totalInvested: _asDecimal(payload['total_invested']),
      totalCurrentValue: _asDecimal(payload['total_current_value']),
      totalPnl: _asDecimal(payload['total_pnl']),
      roiPercent: _asDecimal(payload['roi_percent']),
    );
  }

  @override
  Future<List<ManagerComparisonEntity>> compareManagers() async {
    final response = await _authorizedGet('/imports/multi/performance/managers/compare');
    final payload = _asList(response.data);
    return payload
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ManagerComparisonEntity(
            manager: _brokerFromApi(map['manager']?.toString()),
            portfolios: _asInt(map['portfolios']),
            totalInvested: _asDecimal(map['total_invested']),
            totalCurrentValue: _asDecimal(map['total_current_value']),
            totalPnl: _asDecimal(map['total_pnl']),
            roiPercent: _asDecimal(map['roi_percent']),
          );
        })
        .toList(growable: false);
  }

  ImportPreviewRowEntity _mapPreviewRow(Map<String, dynamic> row) {
    return ImportPreviewRowEntity(
      rowNo: _asInt(row['row_no']),
      status: _rowStatusFromApi(row['status']?.toString()),
      raw: Map<String, dynamic>.from((row['raw'] as Map?) ?? const <String, dynamic>{}),
      normalized: Map<String, dynamic>.from((row['normalized'] as Map?) ?? const <String, dynamic>{}),
      messages: _asList(row['messages']).map((e) => e.toString()).toList(growable: false),
    );
  }

  Future<Response<Object?>> _authorizedGet(String path) async {
    final token = _readToken();
    try {
      return await dio.get<Object?>(
        path,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Response<Object?>> _authorizedPost(
    String path, {
    required Object? data,
  }) async {
    final token = _readToken();
    try {
      return await dio.post<Object?>(
        path,
        data: data,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Response<Object?>> _authorizedPut(
    String path, {
    required Object? data,
  }) async {
    final token = _readToken();
    try {
      return await dio.put<Object?>(
        path,
        data: data,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  String _readToken() {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const FormatException('Authorization required.');
    }
    return token;
  }

  Future<MultipartFile> _buildMultipartFile({
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return MultipartFile.fromBytes(fileBytes, filename: fileName);
    }
    final resolvedPath = filePath?.trim() ?? '';
    if (resolvedPath.isEmpty) {
      throw const FormatException('File path or bytes must be provided.');
    }
    return MultipartFile.fromFile(
      resolvedPath,
      filename: fileName,
    );
  }

  Exception _mapDioError(DioException error) {
    return Exception(mapImportErrorToPersian(error));
  }
}

BrokerType _brokerFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'AGAH':
      return BrokerType.agah;
    case 'MOFID':
      return BrokerType.mofid;
    case 'BOURSIRAN':
      return BrokerType.boursiran;
    default:
      return BrokerType.unknown;
  }
}

String _brokerToApi(BrokerType broker) {
  switch (broker) {
    case BrokerType.agah:
      return 'AGAH';
    case BrokerType.mofid:
      return 'MOFID';
    case BrokerType.boursiran:
      return 'BOURSIRAN';
    case BrokerType.unknown:
      return 'UNKNOWN';
  }
}

ImportType _importTypeFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'HOLDINGS_SNAPSHOT':
      return ImportType.holdingsSnapshot;
    default:
      return ImportType.ledgerTransactions;
  }
}

ImportRowStatus _rowStatusFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'INVALID':
      return ImportRowStatus.invalid;
    case 'DUPLICATE':
      return ImportRowStatus.duplicate;
    default:
      return ImportRowStatus.valid;
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded;
    }
  }
  return const <dynamic>[];
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

Decimal _asDecimal(Object? value) {
  return Decimal.tryParse((value ?? '0').toString()) ?? Decimal.zero;
}

final multiImportDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final multiPortfolioImportRepositoryProvider = Provider<MultiPortfolioImportRepository>((ref) {
  return MultiPortfolioImportApiRepository(
    dio: ref.watch(multiImportDioProvider),
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
