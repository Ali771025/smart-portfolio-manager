import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/fund_models.dart';

abstract class FundsRepository {
  Future<Either<AppFailure, List<FundSummary>>> listFunds({String? type});
  Future<Either<AppFailure, FundSummary>> getFund(String fundId);
  Future<Either<AppFailure, FundNavSnapshot>> getLatestNav(String fundId);
  Future<Either<AppFailure, RiskFreeBenchmark>> getRiskFreeBenchmark();
}

class FundsApiRepository implements FundsRepository {
  FundsApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  Map<String, String>? get _headers {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) return null;
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  @override
  Future<Either<AppFailure, List<FundSummary>>> listFunds({String? type}) async {
    final uri = Uri.parse('$baseUrl/funds').replace(
      queryParameters:
          type?.trim().isNotEmpty == true ? {'type': type!.trim()} : null,
    );
    return _request(uri, (json) {
      if (json is! List) throw const FormatException('Invalid funds response');
      return json
          .whereType<Map<String, dynamic>>()
          .map(FundSummary.fromJson)
          .toList(growable: false);
    });
  }

  @override
  Future<Either<AppFailure, FundSummary>> getFund(String fundId) => _request(
        Uri.parse('$baseUrl/funds/${Uri.encodeComponent(fundId)}'),
        (json) => FundSummary.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Either<AppFailure, FundNavSnapshot>> getLatestNav(String fundId) =>
      _request(
        Uri.parse('$baseUrl/funds/${Uri.encodeComponent(fundId)}/nav'),
        (json) => FundNavSnapshot.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Either<AppFailure, RiskFreeBenchmark>> getRiskFreeBenchmark() =>
      _request(
        Uri.parse('$baseUrl/benchmarks/risk-free'),
        (json) => RiskFreeBenchmark.fromJson(json as Map<String, dynamic>),
      );

  Future<Either<AppFailure, T>> _request<T>(
    Uri uri,
    T Function(Object? json) decode,
  ) async {
    final headers = _headers;
    if (headers == null) {
      return const Left(AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      ));
    }
    try {
      final response = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(AppFailure(
          message: 'دریافت اطلاعات صندوق ناموفق بود.',
          statusCode: response.statusCode,
          isUnauthorized: response.statusCode == 401,
        ));
      }
      return Right(decode(jsonDecode(response.body)));
    } on TimeoutException {
      return const Left(AppFailure(
        message: 'مهلت دریافت اطلاعات صندوق به پایان رسید.',
        isNetwork: true,
      ));
    } catch (_) {
      return const Left(AppFailure(message: 'پاسخ اطلاعات صندوق معتبر نیست.'));
    }
  }
}

final fundsRepositoryProvider = Provider<FundsRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return FundsApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});
