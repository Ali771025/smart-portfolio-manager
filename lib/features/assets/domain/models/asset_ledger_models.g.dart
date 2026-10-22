// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_ledger_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LedgerEntryDto _$LedgerEntryDtoFromJson(Map<String, dynamic> json) =>
    _LedgerEntryDto(
      id: json['id'] as String,
      portfolioId: json['portfolio_id'] as String,
      assetId: json['asset_id'] as String,
      transactionType: json['transaction_type'] as String,
      executedAt: DateTime.parse(json['executed_at'] as String),
      notes: json['notes'] as String?,
      quantity: const DecimalStringJsonConverter().fromJson(json['quantity']),
      pricePerUnit:
          const DecimalStringJsonConverter().fromJson(json['price_per_unit']),
      fees: const DecimalStringJsonConverter().fromJson(json['fees']),
      totalAmount:
          const DecimalStringJsonConverter().fromJson(json['total_amount']),
      realizedPnl:
          const DecimalStringJsonConverter().fromJson(json['realized_pnl']),
      wacAtExecution:
          const DecimalStringJsonConverter().fromJson(json['wac_at_execution']),
    );

Map<String, dynamic> _$LedgerEntryDtoToJson(_LedgerEntryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'portfolio_id': instance.portfolioId,
      'asset_id': instance.assetId,
      'transaction_type': instance.transactionType,
      'executed_at': instance.executedAt.toIso8601String(),
      'notes': instance.notes,
      'quantity': const DecimalStringJsonConverter().toJson(instance.quantity),
      'price_per_unit':
          const DecimalStringJsonConverter().toJson(instance.pricePerUnit),
      'fees': const DecimalStringJsonConverter().toJson(instance.fees),
      'total_amount':
          const DecimalStringJsonConverter().toJson(instance.totalAmount),
      'realized_pnl':
          const DecimalStringJsonConverter().toJson(instance.realizedPnl),
      'wac_at_execution':
          const DecimalStringJsonConverter().toJson(instance.wacAtExecution),
    };

_AssetLedgerPageDto _$AssetLedgerPageDtoFromJson(Map<String, dynamic> json) =>
    _AssetLedgerPageDto(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => LedgerEntryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LedgerEntryDto>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AssetLedgerPageDtoToJson(_AssetLedgerPageDto instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'limit': instance.limit,
      'offset': instance.offset,
    };

_AssetPositionDto _$AssetPositionDtoFromJson(Map<String, dynamic> json) =>
    _AssetPositionDto(
      portfolioId: json['portfolio_id'] as String,
      assetId: json['asset_id'] as String,
      quantity: const DecimalStringJsonConverter().fromJson(json['quantity']),
      weightedAvgCost: const DecimalStringJsonConverter()
          .fromJson(json['weighted_avg_cost']),
      totalCostBasis:
          const DecimalStringJsonConverter().fromJson(json['total_cost_basis']),
      latestPrice:
          const DecimalStringJsonConverter().fromJson(json['latest_price']),
      marketValue:
          const DecimalStringJsonConverter().fromJson(json['market_value']),
      unrealizedPnl:
          const DecimalStringJsonConverter().fromJson(json['unrealized_pnl']),
      realizedPnl:
          const DecimalStringJsonConverter().fromJson(json['realized_pnl']),
    );

Map<String, dynamic> _$AssetPositionDtoToJson(_AssetPositionDto instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'asset_id': instance.assetId,
      'quantity': const DecimalStringJsonConverter().toJson(instance.quantity),
      'weighted_avg_cost':
          const DecimalStringJsonConverter().toJson(instance.weightedAvgCost),
      'total_cost_basis':
          const DecimalStringJsonConverter().toJson(instance.totalCostBasis),
      'latest_price':
          const DecimalStringJsonConverter().toJson(instance.latestPrice),
      'market_value':
          const DecimalStringJsonConverter().toJson(instance.marketValue),
      'unrealized_pnl':
          const DecimalStringJsonConverter().toJson(instance.unrealizedPnl),
      'realized_pnl':
          const DecimalStringJsonConverter().toJson(instance.realizedPnl),
    };

_AssetValuationPointDto _$AssetValuationPointDtoFromJson(
        Map<String, dynamic> json) =>
    _AssetValuationPointDto(
      date: DateTime.parse(json['date'] as String),
      quantity: const DecimalStringJsonConverter().fromJson(json['quantity']),
      weightedAvgCost: const DecimalStringJsonConverter()
          .fromJson(json['weighted_avg_cost']),
      totalCostBasis:
          const DecimalStringJsonConverter().fromJson(json['total_cost_basis']),
      price: const DecimalStringJsonConverter().fromJson(json['price']),
      marketValue:
          const DecimalStringJsonConverter().fromJson(json['market_value']),
      unrealizedPnl:
          const DecimalStringJsonConverter().fromJson(json['unrealized_pnl']),
      realizedPnl:
          const DecimalStringJsonConverter().fromJson(json['realized_pnl']),
    );

Map<String, dynamic> _$AssetValuationPointDtoToJson(
        _AssetValuationPointDto instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'quantity': const DecimalStringJsonConverter().toJson(instance.quantity),
      'weighted_avg_cost':
          const DecimalStringJsonConverter().toJson(instance.weightedAvgCost),
      'total_cost_basis':
          const DecimalStringJsonConverter().toJson(instance.totalCostBasis),
      'price': const DecimalStringJsonConverter().toJson(instance.price),
      'market_value':
          const DecimalStringJsonConverter().toJson(instance.marketValue),
      'unrealized_pnl':
          const DecimalStringJsonConverter().toJson(instance.unrealizedPnl),
      'realized_pnl':
          const DecimalStringJsonConverter().toJson(instance.realizedPnl),
    };

_AssetValuationSeriesDto _$AssetValuationSeriesDtoFromJson(
        Map<String, dynamic> json) =>
    _AssetValuationSeriesDto(
      portfolioId: json['portfolio_id'] as String,
      assetId: json['asset_id'] as String,
      adjustedPrices: json['adjusted_prices'] as bool,
      points: (json['points'] as List<dynamic>?)
              ?.map((e) =>
                  AssetValuationPointDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AssetValuationPointDto>[],
    );

Map<String, dynamic> _$AssetValuationSeriesDtoToJson(
        _AssetValuationSeriesDto instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'asset_id': instance.assetId,
      'adjusted_prices': instance.adjustedPrices,
      'points': instance.points,
    };

_PortfolioPositionDto _$PortfolioPositionDtoFromJson(
        Map<String, dynamic> json) =>
    _PortfolioPositionDto(
      assetId: json['asset_id'] as String,
      tickerSymbol: json['ticker_symbol'] as String,
      quantity: const DecimalStringJsonConverter().fromJson(json['quantity']),
      weightedAvgCost: const DecimalStringJsonConverter()
          .fromJson(json['weighted_avg_cost']),
      totalCostBasis:
          const DecimalStringJsonConverter().fromJson(json['total_cost_basis']),
      latestPrice:
          const DecimalStringJsonConverter().fromJson(json['latest_price']),
      marketValue:
          const DecimalStringJsonConverter().fromJson(json['market_value']),
      unrealizedPnl:
          const DecimalStringJsonConverter().fromJson(json['unrealized_pnl']),
      realizedPnl:
          const DecimalStringJsonConverter().fromJson(json['realized_pnl']),
    );

Map<String, dynamic> _$PortfolioPositionDtoToJson(
        _PortfolioPositionDto instance) =>
    <String, dynamic>{
      'asset_id': instance.assetId,
      'ticker_symbol': instance.tickerSymbol,
      'quantity': const DecimalStringJsonConverter().toJson(instance.quantity),
      'weighted_avg_cost':
          const DecimalStringJsonConverter().toJson(instance.weightedAvgCost),
      'total_cost_basis':
          const DecimalStringJsonConverter().toJson(instance.totalCostBasis),
      'latest_price':
          const DecimalStringJsonConverter().toJson(instance.latestPrice),
      'market_value':
          const DecimalStringJsonConverter().toJson(instance.marketValue),
      'unrealized_pnl':
          const DecimalStringJsonConverter().toJson(instance.unrealizedPnl),
      'realized_pnl':
          const DecimalStringJsonConverter().toJson(instance.realizedPnl),
    };

_PortfolioPositionsDto _$PortfolioPositionsDtoFromJson(
        Map<String, dynamic> json) =>
    _PortfolioPositionsDto(
      portfolioId: json['portfolio_id'] as String,
      totalMarketValue: const DecimalStringJsonConverter()
          .fromJson(json['total_market_value']),
      totalCostBasis:
          const DecimalStringJsonConverter().fromJson(json['total_cost_basis']),
      totalUnrealizedPnl: const DecimalStringJsonConverter()
          .fromJson(json['total_unrealized_pnl']),
      totalRealizedPnl: const DecimalStringJsonConverter()
          .fromJson(json['total_realized_pnl']),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  PortfolioPositionDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PortfolioPositionDto>[],
    );

Map<String, dynamic> _$PortfolioPositionsDtoToJson(
        _PortfolioPositionsDto instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'total_market_value':
          const DecimalStringJsonConverter().toJson(instance.totalMarketValue),
      'total_cost_basis':
          const DecimalStringJsonConverter().toJson(instance.totalCostBasis),
      'total_unrealized_pnl': const DecimalStringJsonConverter()
          .toJson(instance.totalUnrealizedPnl),
      'total_realized_pnl':
          const DecimalStringJsonConverter().toJson(instance.totalRealizedPnl),
      'items': instance.items,
    };

_PortfolioTwrPointDto _$PortfolioTwrPointDtoFromJson(
        Map<String, dynamic> json) =>
    _PortfolioTwrPointDto(
      date: DateTime.parse(json['date'] as String),
      portfolioValue:
          const DecimalStringJsonConverter().fromJson(json['portfolio_value']),
      netCashFlow:
          const DecimalStringJsonConverter().fromJson(json['net_cash_flow']),
      periodReturn:
          const DecimalStringJsonConverter().fromJson(json['period_return']),
      cumulativeTwr:
          const DecimalStringJsonConverter().fromJson(json['cumulative_twr']),
    );

Map<String, dynamic> _$PortfolioTwrPointDtoToJson(
        _PortfolioTwrPointDto instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'portfolio_value':
          const DecimalStringJsonConverter().toJson(instance.portfolioValue),
      'net_cash_flow':
          const DecimalStringJsonConverter().toJson(instance.netCashFlow),
      'period_return':
          const DecimalStringJsonConverter().toJson(instance.periodReturn),
      'cumulative_twr':
          const DecimalStringJsonConverter().toJson(instance.cumulativeTwr),
    };

_PortfolioTwrDto _$PortfolioTwrDtoFromJson(Map<String, dynamic> json) =>
    _PortfolioTwrDto(
      portfolioId: json['portfolio_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      points: (json['points'] as List<dynamic>?)
              ?.map((e) =>
                  PortfolioTwrPointDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PortfolioTwrPointDto>[],
    );

Map<String, dynamic> _$PortfolioTwrDtoToJson(_PortfolioTwrDto instance) =>
    <String, dynamic>{
      'portfolio_id': instance.portfolioId,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate.toIso8601String(),
      'points': instance.points,
    };

_TransactionCreateDto _$TransactionCreateDtoFromJson(
        Map<String, dynamic> json) =>
    _TransactionCreateDto(
      assetId: json['asset_id'] as String,
      transactionType: json['transaction_type'] as String,
      quantity: const DecimalStringJsonConverter().fromJson(json['quantity']),
      pricePerUnit:
          const DecimalStringJsonConverter().fromJson(json['price_per_unit']),
      fees: const DecimalStringJsonConverter().fromJson(json['fees']),
      dividendPerUnit: const DecimalStringJsonConverter()
          .fromJson(json['dividend_per_unit']),
      bonusRatio:
          const DecimalStringJsonConverter().fromJson(json['bonus_ratio']),
      splitFrom: (json['split_from'] as num?)?.toInt(),
      splitTo: (json['split_to'] as num?)?.toInt(),
      rightsRatio:
          const DecimalStringJsonConverter().fromJson(json['rights_ratio']),
      subscriptionPrice: const DecimalStringJsonConverter()
          .fromJson(json['subscription_price']),
      notes: json['notes'] as String?,
      executedAt: DateTime.parse(json['executed_at'] as String),
    );

Map<String, dynamic> _$TransactionCreateDtoToJson(
        _TransactionCreateDto instance) =>
    <String, dynamic>{
      'asset_id': instance.assetId,
      'transaction_type': instance.transactionType,
      'quantity': const DecimalStringJsonConverter().toJson(instance.quantity),
      'price_per_unit': _$JsonConverterToJson<Object?, Decimal>(
          instance.pricePerUnit, const DecimalStringJsonConverter().toJson),
      'fees': _$JsonConverterToJson<Object?, Decimal>(
          instance.fees, const DecimalStringJsonConverter().toJson),
      'dividend_per_unit': _$JsonConverterToJson<Object?, Decimal>(
          instance.dividendPerUnit, const DecimalStringJsonConverter().toJson),
      'bonus_ratio': _$JsonConverterToJson<Object?, Decimal>(
          instance.bonusRatio, const DecimalStringJsonConverter().toJson),
      'split_from': instance.splitFrom,
      'split_to': instance.splitTo,
      'rights_ratio': _$JsonConverterToJson<Object?, Decimal>(
          instance.rightsRatio, const DecimalStringJsonConverter().toJson),
      'subscription_price': _$JsonConverterToJson<Object?, Decimal>(
          instance.subscriptionPrice,
          const DecimalStringJsonConverter().toJson),
      'notes': instance.notes,
      'executed_at': instance.executedAt.toIso8601String(),
    };

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
