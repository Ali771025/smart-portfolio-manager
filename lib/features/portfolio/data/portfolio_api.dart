import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_base_url.dart';
import '../../transactions/domain/transaction_request.dart';
import '../domain/portfolio_summary.dart';

class PortfolioApi {
  PortfolioApi({
    http.Client? client,
    String? baseUrl,
  })  : baseUrl = baseUrl ?? defaultApiBaseUrl,
        _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<PortfolioSummary> getPortfolioSummary({
    required String portfolioId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/portfolios/$portfolioId/summary');
    final response = await _client.get(
      uri,
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode != 200) {
      throw Exception('Summary request failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PortfolioSummary.fromJson(body);
  }

  Future<void> triggerMarketSync({
    required String accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/market/sync/live'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode == 404 || response.statusCode == 405) {
      final legacyResponse = await _client.post(
        Uri.parse('$baseUrl/market-data/sync'),
        headers: _authHeaders(accessToken),
      );
      if (legacyResponse.statusCode >= 200 && legacyResponse.statusCode < 300) {
        return;
      }
      throw Exception('Sync trigger failed: ${legacyResponse.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sync trigger failed: ${response.statusCode}');
    }
  }

  Future<void> submitTransaction({
    required String portfolioId,
    required String accessToken,
    required TransactionRequest request,
  }) async {
    final idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}-${request.assetId}';
    final uri = Uri.parse('$baseUrl/portfolios/$portfolioId/transactions/');
    final response = await _client.post(
      uri,
      headers: <String, String>{
        ..._authHeaders(accessToken),
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Transaction submission failed: ${response.statusCode}');
    }
  }

  Map<String, String> _authHeaders(String accessToken) {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }
}
