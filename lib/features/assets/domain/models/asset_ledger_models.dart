import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/decimal_json_converter.dart';

part 'asset_ledger_models.freezed.dart';
part 'asset_ledger_models.g.dart';

@freezed
abstract class LedgerEntryDto with _$LedgerEntryDto {
  const factory LedgerEntryDto({
    required String id,
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'transaction_type') required String transactionType,
    @JsonKey(name: 'executed_at') required DateTime executedAt,
    String? notes,
    @DecimalStringJsonConverter() required Decimal quantity,
    @JsonKey(name: 'price_per_unit')
    @DecimalStringJsonConverter()
    required Decimal pricePerUnit,
    @DecimalStringJsonConverter() required Decimal fees,
    @JsonKey(name: 'total_amount')
    @DecimalStringJsonConverter()
    required Decimal totalAmount,
    @JsonKey(name: 'realized_pnl')
    @DecimalStringJsonConverter()
    required Decimal realizedPnl,
    @JsonKey(name: 'wac_at_execution')
    @DecimalStringJsonConverter()
    required Decimal wacAtExecution,
  }) = _LedgerEntryDto;

  factory LedgerEntryDto.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryDtoFromJson(json);
}

@freezed
abstract class AssetLedgerPageDto with _$AssetLedgerPageDto {
  const factory AssetLedgerPageDto({
    @Default(<LedgerEntryDto>[]) List<LedgerEntryDto> items,
    @Default(0) int total,
    @Default(50) int limit,
    @Default(0) int offset,
  }) = _AssetLedgerPageDto;

  factory AssetLedgerPageDto.fromJson(Map<String, dynamic> json) =>
      _$AssetLedgerPageDtoFromJson(json);
}

@freezed
abstract class AssetPositionDto with _$AssetPositionDto {
  const factory AssetPositionDto({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(name: 'asset_id') required String assetId,
    @DecimalStringJsonConverter() required Decimal quantity,
    @JsonKey(name: 'weighted_avg_cost')
    @DecimalStringJsonConverter()
    required Decimal weightedAvgCost,
    @JsonKey(name: 'total_cost_basis')
    @DecimalStringJsonConverter()
    required Decimal totalCostBasis,
    @JsonKey(name: 'latest_price')
    @DecimalStringJsonConverter()
    required Decimal latestPrice,
    @JsonKey(name: 'market_value')
    @DecimalStringJsonConverter()
    required Decimal marketValue,
    @JsonKey(name: 'unrealized_pnl')
    @DecimalStringJsonConverter()
    required Decimal unrealizedPnl,
    @JsonKey(name: 'realized_pnl')
    @DecimalStringJsonConverter()
    required Decimal realizedPnl,
  }) = _AssetPositionDto;

  factory AssetPositionDto.fromJson(Map<String, dynamic> json) =>
      _$AssetPositionDtoFromJson(json);
}

@freezed
abstract class AssetValuationPointDto with _$AssetValuationPointDto {
  const factory AssetValuationPointDto({
    required DateTime date,
    @DecimalStringJsonConverter() required Decimal quantity,
    @JsonKey(name: 'weighted_avg_cost')
    @DecimalStringJsonConverter()
    required Decimal weightedAvgCost,
    @JsonKey(name: 'total_cost_basis')
    @DecimalStringJsonConverter()
    required Decimal totalCostBasis,
    @DecimalStringJsonConverter() required Decimal price,
    @JsonKey(name: 'market_value')
    @DecimalStringJsonConverter()
    required Decimal marketValue,
    @JsonKey(name: 'unrealized_pnl')
    @DecimalStringJsonConverter()
    required Decimal unrealizedPnl,
    @JsonKey(name: 'realized_pnl')
    @DecimalStringJsonConverter()
    required Decimal realizedPnl,
  }) = _AssetValuationPointDto;

  factory AssetValuationPointDto.fromJson(Map<String, dynamic> json) =>
      _$AssetValuationPointDtoFromJson(json);
}

@freezed
abstract class AssetValuationSeriesDto with _$AssetValuationSeriesDto {
  const factory AssetValuationSeriesDto({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'adjusted_prices') required bool adjustedPrices,
    @Default(<AssetValuationPointDto>[]) List<AssetValuationPointDto> points,
  }) = _AssetValuationSeriesDto;

  factory AssetValuationSeriesDto.fromJson(Map<String, dynamic> json) =>
      _$AssetValuationSeriesDtoFromJson(json);
}

@freezed
abstract class PortfolioPositionDto with _$PortfolioPositionDto {
  const factory PortfolioPositionDto({
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'ticker_symbol') required String tickerSymbol,
    @DecimalStringJsonConverter() required Decimal quantity,
    @JsonKey(name: 'weighted_avg_cost')
    @DecimalStringJsonConverter()
    required Decimal weightedAvgCost,
    @JsonKey(name: 'total_cost_basis')
    @DecimalStringJsonConverter()
    required Decimal totalCostBasis,
    @JsonKey(name: 'latest_price')
    @DecimalStringJsonConverter()
    required Decimal latestPrice,
    @JsonKey(name: 'market_value')
    @DecimalStringJsonConverter()
    required Decimal marketValue,
    @JsonKey(name: 'unrealized_pnl')
    @DecimalStringJsonConverter()
    required Decimal unrealizedPnl,
    @JsonKey(name: 'realized_pnl')
    @DecimalStringJsonConverter()
    required Decimal realizedPnl,
  }) = _PortfolioPositionDto;

  factory PortfolioPositionDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioPositionDtoFromJson(json);
}

@freezed
abstract class PortfolioPositionsDto with _$PortfolioPositionsDto {
  const factory PortfolioPositionsDto({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(name: 'total_market_value')
    @DecimalStringJsonConverter()
    required Decimal totalMarketValue,
    @JsonKey(name: 'total_cost_basis')
    @DecimalStringJsonConverter()
    required Decimal totalCostBasis,
    @JsonKey(name: 'total_unrealized_pnl')
    @DecimalStringJsonConverter()
    required Decimal totalUnrealizedPnl,
    @JsonKey(name: 'total_realized_pnl')
    @DecimalStringJsonConverter()
    required Decimal totalRealizedPnl,
    @Default(<PortfolioPositionDto>[]) List<PortfolioPositionDto> items,
  }) = _PortfolioPositionsDto;

  factory PortfolioPositionsDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioPositionsDtoFromJson(json);
}

class PortfolioHoldingDto {
  const PortfolioHoldingDto({
    required this.assetId,
    required this.symbol,
    required this.quantity,
    required this.averageCost,
    required this.weightedAvgCost,
    required this.costBasis,
    required this.realizedPnl,
    required this.hasMarketPrice,
    required this.currency,
    required this.calculationStatus,
    required this.warnings,
    this.name,
    this.currentPrice,
    this.latestPrice,
    this.priceSource,
    this.priceDate,
    this.isPriceStale,
    this.marketValue,
    this.unrealizedPnl,
    this.unrealizedPnlPercent,
    this.totalPnl,
    this.totalPnlPercent,
    this.roi,
  });

  final String assetId;
  final String symbol;
  final String? name;
  final Decimal quantity;
  final Decimal averageCost;
  final Decimal weightedAvgCost;
  final Decimal costBasis;
  final Decimal? currentPrice;
  final Decimal? latestPrice;
  final String? priceSource;
  final DateTime? priceDate;
  final bool hasMarketPrice;
  final bool? isPriceStale;
  final Decimal? marketValue;
  final Decimal? unrealizedPnl;
  final Decimal? unrealizedPnlPercent;
  final Decimal realizedPnl;
  final Decimal? totalPnl;
  final Decimal? totalPnlPercent;
  final Decimal? roi;
  final String currency;
  final String calculationStatus;
  final List<String> warnings;

  Decimal? get displayPrice =>
      hasMarketPrice ? currentPrice ?? latestPrice : null;

  factory PortfolioHoldingDto.fromJson(Map<String, dynamic> json) {
    return PortfolioHoldingDto(
      assetId: _readValue(json, 'assetId', 'asset_id')?.toString() ?? '',
      symbol: _readValue(json, 'symbol', 'ticker_symbol')?.toString() ?? '',
      name: _nullableString(json['name']),
      quantity: _decimalOrZero(json['quantity']),
      averageCost:
          _decimalOrZero(_readValue(json, 'averageCost', 'average_cost')),
      weightedAvgCost: _decimalOrZero(
        _readValue(json, 'weightedAvgCost', 'weighted_avg_cost'),
      ),
      costBasis: _decimalOrZero(_readValue(json, 'costBasis', 'cost_basis')),
      currentPrice: _decimalOrNull(
        _readValue(json, 'currentPrice', 'current_price'),
      ),
      latestPrice: _decimalOrNull(
        _readValue(json, 'latestPrice', 'latest_price'),
      ),
      priceSource: _nullableString(
        _readValue(json, 'priceSource', 'price_source'),
      ),
      priceDate: _dateTimeOrNull(_readValue(json, 'priceDate', 'price_date')),
      hasMarketPrice: _boolOrFalse(
        _readValue(json, 'hasMarketPrice', 'has_market_price'),
      ),
      isPriceStale: _nullableBool(
        _readValue(json, 'isPriceStale', 'is_price_stale'),
      ),
      marketValue: _decimalOrNull(
        _readValue(json, 'marketValue', 'market_value'),
      ),
      unrealizedPnl: _decimalOrNull(
        _readValue(json, 'unrealizedPnl', 'unrealized_pnl'),
      ),
      unrealizedPnlPercent: _decimalOrNull(
        _readValue(json, 'unrealizedPnlPercent', 'unrealized_pnl_percent'),
      ),
      realizedPnl: _decimalOrZero(
        _readValue(json, 'realizedPnl', 'realized_pnl'),
      ),
      totalPnl: _decimalOrNull(_readValue(json, 'totalPnl', 'total_pnl')),
      totalPnlPercent: _decimalOrNull(
        _readValue(json, 'totalPnlPercent', 'total_pnl_percent'),
      ),
      roi: _decimalOrNull(json['roi']),
      currency: json['currency']?.toString() ?? 'IRR',
      calculationStatus:
          _readValue(json, 'calculationStatus', 'calculation_status')
                  ?.toString() ??
              'missing_market_price',
      warnings: _stringList(json['warnings']),
    );
  }
}

class PortfolioHoldingsDto {
  const PortfolioHoldingsDto({
    required this.portfolioId,
    required this.currency,
    required this.holdings,
    required this.pricedHoldingsCount,
    required this.missingPriceCount,
    required this.missingPriceSymbols,
    required this.hasMissingMarketPrices,
    required this.calculationStatus,
    required this.warnings,
  });

  final String portfolioId;
  final String currency;
  final List<PortfolioHoldingDto> holdings;
  final int pricedHoldingsCount;
  final int missingPriceCount;
  final List<String> missingPriceSymbols;
  final bool hasMissingMarketPrices;
  final String calculationStatus;
  final List<String> warnings;

  factory PortfolioHoldingsDto.fromJson(Map<String, dynamic> json) {
    final rawHoldings = json['holdings'];
    return PortfolioHoldingsDto(
      portfolioId:
          _readValue(json, 'portfolioId', 'portfolio_id')?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'IRR',
      holdings: rawHoldings is List
          ? rawHoldings
              .whereType<Map>()
              .map(
                (item) => PortfolioHoldingDto.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <PortfolioHoldingDto>[],
      pricedHoldingsCount: _intOrZero(
        _readValue(json, 'pricedHoldingsCount', 'priced_holdings_count'),
      ),
      missingPriceCount: _intOrZero(
        _readValue(json, 'missingPriceCount', 'missing_price_count'),
      ),
      missingPriceSymbols: _stringList(
        _readValue(json, 'missingPriceSymbols', 'missing_price_symbols'),
      ),
      hasMissingMarketPrices: _boolOrFalse(
        _readValue(json, 'hasMissingMarketPrices', 'has_missing_market_prices'),
      ),
      calculationStatus:
          _readValue(json, 'calculationStatus', 'calculation_status')
                  ?.toString() ??
              'complete',
      warnings: _stringList(json['warnings']),
    );
  }
}

class PortfolioFrontendSummaryDto {
  const PortfolioFrontendSummaryDto({
    required this.portfolioId,
    required this.totalCostBasis,
    required this.realizedPnl,
    required this.holdingsCount,
    required this.pricedHoldingsCount,
    required this.missingPriceCount,
    required this.missingPriceSymbols,
    required this.hasMissingMarketPrices,
    required this.calculationStatus,
    required this.warnings,
    required this.currency,
    this.totalMarketValue,
    this.unrealizedPnl,
    this.totalPnl,
    this.totalPnlPercent,
    this.roi,
  });

  final String portfolioId;
  final Decimal totalCostBasis;
  final Decimal? totalMarketValue;
  final Decimal realizedPnl;
  final Decimal? unrealizedPnl;
  final Decimal? totalPnl;
  final Decimal? totalPnlPercent;
  final Decimal? roi;
  final int holdingsCount;
  final int pricedHoldingsCount;
  final int missingPriceCount;
  final List<String> missingPriceSymbols;
  final bool hasMissingMarketPrices;
  final String calculationStatus;
  final List<String> warnings;
  final String currency;

  factory PortfolioFrontendSummaryDto.fromJson(Map<String, dynamic> json) {
    return PortfolioFrontendSummaryDto(
      portfolioId:
          _readValue(json, 'portfolioId', 'portfolio_id')?.toString() ?? '',
      totalCostBasis: _decimalOrZero(
        _readValue(json, 'totalCostBasis', 'total_cost_basis'),
      ),
      totalMarketValue: _decimalOrNull(
        _readValue(json, 'totalMarketValue', 'total_market_value'),
      ),
      realizedPnl: _decimalOrZero(
        _readValue(json, 'realizedPnl', 'realized_pnl'),
      ),
      unrealizedPnl: _decimalOrNull(
        _readValue(json, 'unrealizedPnl', 'unrealized_pnl'),
      ),
      totalPnl: _decimalOrNull(_readValue(json, 'totalPnl', 'total_pnl')),
      totalPnlPercent: _decimalOrNull(
        _readValue(json, 'totalPnlPercent', 'total_pnl_percent'),
      ),
      roi: _decimalOrNull(json['roi']),
      holdingsCount: _intOrZero(
        _readValue(json, 'holdingsCount', 'holdings_count'),
      ),
      pricedHoldingsCount: _intOrZero(
        _readValue(json, 'pricedHoldingsCount', 'priced_holdings_count'),
      ),
      missingPriceCount: _intOrZero(
        _readValue(json, 'missingPriceCount', 'missing_price_count'),
      ),
      missingPriceSymbols: _stringList(
        _readValue(json, 'missingPriceSymbols', 'missing_price_symbols'),
      ),
      hasMissingMarketPrices: _boolOrFalse(
        _readValue(json, 'hasMissingMarketPrices', 'has_missing_market_prices'),
      ),
      calculationStatus:
          _readValue(json, 'calculationStatus', 'calculation_status')
                  ?.toString() ??
              'complete',
      warnings: _stringList(json['warnings']),
      currency: json['currency']?.toString() ?? 'IRR',
    );
  }
}

@freezed
abstract class PortfolioTwrPointDto with _$PortfolioTwrPointDto {
  const factory PortfolioTwrPointDto({
    required DateTime date,
    @JsonKey(name: 'portfolio_value')
    @DecimalStringJsonConverter()
    required Decimal portfolioValue,
    @JsonKey(name: 'net_cash_flow')
    @DecimalStringJsonConverter()
    required Decimal netCashFlow,
    @JsonKey(name: 'period_return')
    @DecimalStringJsonConverter()
    required Decimal periodReturn,
    @JsonKey(name: 'cumulative_twr')
    @DecimalStringJsonConverter()
    required Decimal cumulativeTwr,
  }) = _PortfolioTwrPointDto;

  factory PortfolioTwrPointDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioTwrPointDtoFromJson(json);
}

@freezed
abstract class PortfolioTwrDto with _$PortfolioTwrDto {
  const factory PortfolioTwrDto({
    @JsonKey(name: 'portfolio_id') required String portfolioId,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    @Default(<PortfolioTwrPointDto>[]) List<PortfolioTwrPointDto> points,
  }) = _PortfolioTwrDto;

  factory PortfolioTwrDto.fromJson(Map<String, dynamic> json) =>
      _$PortfolioTwrDtoFromJson(json);
}

@freezed
abstract class TransactionCreateDto with _$TransactionCreateDto {
  const factory TransactionCreateDto({
    @JsonKey(name: 'asset_id') required String assetId,
    @JsonKey(name: 'transaction_type') required String transactionType,
    @DecimalStringJsonConverter() required Decimal quantity,
    @JsonKey(name: 'price_per_unit')
    @DecimalStringJsonConverter()
    Decimal? pricePerUnit,
    @DecimalStringJsonConverter() Decimal? fees,
    @JsonKey(name: 'dividend_per_unit')
    @DecimalStringJsonConverter()
    Decimal? dividendPerUnit,
    @JsonKey(name: 'bonus_ratio')
    @DecimalStringJsonConverter()
    Decimal? bonusRatio,
    @JsonKey(name: 'split_from') int? splitFrom,
    @JsonKey(name: 'split_to') int? splitTo,
    @JsonKey(name: 'rights_ratio')
    @DecimalStringJsonConverter()
    Decimal? rightsRatio,
    @JsonKey(name: 'subscription_price')
    @DecimalStringJsonConverter()
    Decimal? subscriptionPrice,
    String? notes,
    @JsonKey(name: 'executed_at') required DateTime executedAt,
  }) = _TransactionCreateDto;

  factory TransactionCreateDto.fromJson(Map<String, dynamic> json) =>
      _$TransactionCreateDtoFromJson(json);
}

extension LedgerEntryDtoCompat on LedgerEntryDto {
  String get assetSymbol => '';

  Decimal get commission => fees;

  Decimal get tax => Decimal.zero;

  Decimal get netAmount => totalAmount;

  Decimal get cashFlow {
    final side = transactionType.toUpperCase();
    if (side == 'BUY') {
      return -totalAmount;
    }
    if (side == 'SELL') {
      return totalAmount;
    }
    return Decimal.zero;
  }
}

extension AssetPositionDtoCompat on AssetPositionDto {
  String get symbol => '';

  String? get name => null;

  String? get assetType => null;

  Decimal get totalPnl => Decimal.zero;

  Decimal get lastPrice => latestPrice;

  Decimal get closingPrice => Decimal.zero;

  Decimal get dailyPnl => Decimal.zero;

  Decimal get roi => Decimal.zero;

  String get currency => 'IRR';

  DateTime? get lastPriceTimestamp => null;

  DateTime? get lastMarketUpdate => lastPriceTimestamp;
}

extension AssetValuationPointDtoCompat on AssetValuationPointDto {
  DateTime get timestamp => date;
}

extension PortfolioPositionDtoCompat on PortfolioPositionDto {
  String get symbol => tickerSymbol;

  String? get name => null;

  String? get assetType => null;

  Decimal get totalPnl => Decimal.zero;

  Decimal get lastPrice => latestPrice;

  Decimal get closingPrice => Decimal.zero;

  Decimal get dailyPnl => Decimal.zero;

  Decimal get roi => Decimal.zero;

  DateTime? get lastMarketUpdate => null;
}

Object? _readValue(
  Map<String, dynamic> json,
  String camelCase,
  String snakeCase,
) =>
    json.containsKey(camelCase) ? json[camelCase] : json[snakeCase];

Decimal _decimalOrZero(Object? value) => _decimalOrNull(value) ?? Decimal.zero;

Decimal? _decimalOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Decimal) {
    return value;
  }
  return Decimal.tryParse(value.toString().trim());
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

bool? _nullableBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return null;
}

bool _boolOrFalse(Object? value) => _nullableBool(value) ?? false;

int _intOrZero(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
