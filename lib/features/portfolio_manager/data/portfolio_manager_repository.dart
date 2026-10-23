import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/portfolio_card_dto.dart';

part 'portfolio_manager_repository.g.dart';

abstract class PortfolioManagerRepository {
  Future<Either<AppFailure, List<PortfolioCardDto>>> fetchPortfolios();
  Future<Either<AppFailure, PortfolioCardDto>> createPortfolio({
    required String name,
  });
  Future<Either<AppFailure, Unit>> deletePortfolio({
    required String portfolioId,
  });
}

class PortfolioManagerApiRepository implements PortfolioManagerRepository {
  PortfolioManagerApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  @override
  Future<Either<AppFailure, PortfolioCardDto>> createPortfolio({
    required String name,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/portfolios');
      final response = await client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(
              <String, dynamic>{
                'name': name.trim(),
                'base_currency': 'IRR',
                'is_default': false,
              },
            ),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          AppFailure(
            message: 'ایجاد پرتفوی انجام نشد.',
            statusCode: response.statusCode,
          ),
        );
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const Left(
          AppFailure(message: 'پاسخ ایجاد پرتفوی معتبر نیست.'),
        );
      }
      return Right(_mapPortfolio(payload));
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'پاسخ سرور با تاخیر غیرمجاز مواجه شد.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در ایجاد پرتفوی.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, Unit>> deletePortfolio({
    required String portfolioId,
  }) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    final normalizedId = portfolioId.trim();
    if (normalizedId.isEmpty) {
      return const Left(AppFailure(message: 'شناسه پرتفو معتبر نیست.'));
    }

    try {
      final uri = Uri.parse('$baseUrl/portfolios/$normalizedId');
      final response = await client
          .delete(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          AppFailure(
            message: _errorMessage(
              response.body,
              fallback: 'حذف پرتفو انجام نشد.',
            ),
            statusCode: response.statusCode,
            isUnauthorized: response.statusCode == 401,
          ),
        );
      }

      return const Right(unit);
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'پاسخ سرور با تاخیر غیرمجاز مواجه شد.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در حذف پرتفو.'),
      );
    }
  }

  @override
  Future<Either<AppFailure, List<PortfolioCardDto>>> fetchPortfolios() async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'ابتدا وارد حساب کاربری شوید.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    try {
      final portfoliosUri = Uri.parse('$baseUrl/portfolios');
      final response = await client.get(
        portfoliosUri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          AppFailure(
            message: 'دریافت لیست پرتفوی‌ها ناموفق بود.',
            statusCode: response.statusCode,
          ),
        );
      }

      final payload = jsonDecode(response.body);
      final items = _extractPortfolioItems(payload);
      final mapped = items
          .map(_mapPortfolio)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      return Right(mapped);
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت دریافت لیست پرتفوی‌ها به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(
          message: 'خطای ناشناخته در دریافت پرتفوی‌ها.',
        ),
      );
    }
  }

  PortfolioCardDto _mapPortfolio(Map<String, dynamic> json) {
    // Backend list endpoint returns portfolio_id/portfolio_name while create
    // returns id/name, so support both shapes to avoid dropping portfolios.
    final id = (json['id'] ?? json['portfolio_id'] ?? '').toString();
    final name = (json['name'] ?? json['portfolio_name'] ?? '').toString();
    final isDefault = json['is_default'] == true;

    // Back-end may expose this in separate endpoints; keep graceful fallback values.
    final totalValue = _asDouble(
      json['total_current_value'] ?? json['total_value'] ?? 0,
    );
    final roi = _asDouble(
      json['roi_percent'] ?? json['roi_pct'] ?? json['overall_roi_percent'] ?? 0,
    );
    final risk = _asDouble(json['risk_std_deviation'] ?? 0);

    final sparkline = _buildSparkline(totalValue: totalValue, roi: roi, seed: id.hashCode);
    return PortfolioCardDto(
      id: id,
      name: name.isEmpty ? 'پرتفوی بدون نام' : name,
      totalValue: totalValue,
      roiPercent: roi,
      riskStdDeviation: risk,
      sparklineValues: sparkline,
      isDefault: isDefault,
    );
  }

  List<Map<String, dynamic>> _extractPortfolioItems(Object? payload) {
    if (payload is List<dynamic>) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (payload is Map<String, dynamic>) {
      final items = payload['items'];
      if (items is List<dynamic>) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<double> _buildSparkline({
    required double totalValue,
    required double roi,
    required int seed,
  }) {
    final base = totalValue <= 0 ? 10000000 : totalValue;
    final trend = roi / 100;
    final random = math.Random(seed);

    return List<double>.generate(12, (index) {
      final progress = index / 11;
      final drift = (progress - 0.5) * trend * base * 0.45;
      final noise = (random.nextDouble() - 0.5) * base * 0.03;
      return base + drift + noise;
    }, growable: false);
  }

  static double _asDouble(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _errorMessage(String body, {required String fallback}) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        final title = payload['title'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          return detail.toString();
        }
        if (title != null && title.toString().trim().isNotEmpty) {
          return title.toString();
        }
      }
    } catch (_) {
      // Keep fallback message.
    }
    return fallback;
  }
}

@Riverpod(keepAlive: true)
PortfolioManagerRepository portfolioManagerRepository(
  Ref ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PortfolioManagerApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
}
