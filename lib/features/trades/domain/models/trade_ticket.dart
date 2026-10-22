import 'package:freezed_annotation/freezed_annotation.dart';

part 'trade_ticket.freezed.dart';
part 'trade_ticket.g.dart';

enum TradeSide { buy, sell }

/// Trade ticket for Tehran Stock Exchange transactions.
///
/// Tehran market constraints:
/// - quantity: Must be a positive integer (whole shares only)
/// - price: Positive decimal (IRR per share)
/// - fees: Non-negative decimal (broker commission + exchange fees)
@freezed
abstract class TradeTicket with _$TradeTicket {
  const factory TradeTicket({
    required TradeSide side,
    required String symbol,
    required String portfolioId,
    required int quantity,  // Tehran market: integer shares only
    required double price,
    @Default(0) double fees,
    String? notes,
    DateTime? executedAt,
  }) = _TradeTicket;

  factory TradeTicket.fromJson(Map<String, dynamic> json) =>
      _$TradeTicketFromJson(json);
}
