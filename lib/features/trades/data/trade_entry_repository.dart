import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/api_base_url.dart';
import '../../../core/network/app_failure.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/models/trade_ticket.dart';

part 'trade_entry_repository.g.dart';

abstract class TradeEntryRepository {
  Future<Either<AppFailure, Unit>> submitTrade(TradeTicket ticket);
}

class TradeEntryApiRepository implements TradeEntryRepository {
  TradeEntryApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  @override
  Future<Either<AppFailure, Unit>> submitTrade(TradeTicket ticket) async {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      return const Left(
        AppFailure(
          message: 'نشست کاربری شما معتبر نیست.',
          statusCode: 401,
          isUnauthorized: true,
        ),
      );
    }

    final sidePath = ticket.side == TradeSide.buy ? 'buy' : 'sell';
    final uri = Uri.parse('$baseUrl/trades/$sidePath');
    final executedAt = (ticket.executedAt ?? DateTime.now()).toUtc().toIso8601String();

    final body = <String, dynamic>{
      'portfolio_id': ticket.portfolioId,
      'symbol': ticket.symbol.trim().toUpperCase(),
      'quantity': '${ticket.quantity}.00000000',  // Integer share count with 8 decimal places for backend
      'price': ticket.price.toStringAsFixed(8),
      'fees': ticket.fees.toStringAsFixed(8),
      'executed_at': executedAt,
      'notes': ticket.notes,
      'idempotency_key': '${ticket.symbol}-${DateTime.now().microsecondsSinceEpoch}',
    };

    try {
      final response = await client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          AppFailure(
            message: 'ثبت سفارش با خطا مواجه شد.',
            statusCode: response.statusCode,
          ),
        );
      }
      return const Right(unit);
    } on TimeoutException {
      return const Left(
        AppFailure(
          message: 'مهلت ارتباط با سرور برای ثبت سفارش به پایان رسید.',
          isNetwork: true,
        ),
      );
    } catch (_) {
      return const Left(
        AppFailure(message: 'خطای ناشناخته هنگام ثبت سفارش.'),
      );
    }
  }
}

@Riverpod(keepAlive: true)
TradeEntryRepository tradeEntryRepository(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return TradeEntryApiRepository(
    client: client,
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
}
