// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TradeTicket _$TradeTicketFromJson(Map<String, dynamic> json) => _TradeTicket(
      side: $enumDecode(_$TradeSideEnumMap, json['side']),
      symbol: json['symbol'] as String,
      portfolioId: json['portfolioId'] as String,
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      fees: (json['fees'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      executedAt: json['executedAt'] == null
          ? null
          : DateTime.parse(json['executedAt'] as String),
    );

Map<String, dynamic> _$TradeTicketToJson(_TradeTicket instance) =>
    <String, dynamic>{
      'side': _$TradeSideEnumMap[instance.side]!,
      'symbol': instance.symbol,
      'portfolioId': instance.portfolioId,
      'quantity': instance.quantity,
      'price': instance.price,
      'fees': instance.fees,
      'notes': instance.notes,
      'executedAt': instance.executedAt?.toIso8601String(),
    };

const _$TradeSideEnumMap = {
  TradeSide.buy: 'buy',
  TradeSide.sell: 'sell',
};
