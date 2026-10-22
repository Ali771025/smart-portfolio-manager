/// Domain models for Market API responses.
///
/// These models represent the backend Market API contracts:
/// - LiveMarketSnapshotResponse
/// - SymbolHistoryResponse
/// - MarketStatusResponse
/// - IndexSnapshotResponse
/// Current market overview returned by `/api/v1/market/overview`.
class MarketOverview {
  const MarketOverview({
    this.totalIndexValue,
    this.totalIndexChange,
    this.equalWeightIndexValue,
    this.equalWeightIndexChange,
    this.marketValue,
    this.tradesCount,
    this.tradesValue,
    this.tradesVolume,
    this.priceInfoTimestamp,
    this.serverReceivedAt,
    this.marketStatus = 'unknown',
    this.isCurrentSession = false,
    this.source = '',
    this.dataQualityStatus = 'unknown',
  });

  final double? totalIndexValue;
  final double? totalIndexChange;
  final double? equalWeightIndexValue;
  final double? equalWeightIndexChange;
  final double? marketValue;
  final int? tradesCount;
  final double? tradesValue;
  final double? tradesVolume;
  final DateTime? priceInfoTimestamp;
  final DateTime? serverReceivedAt;
  final String marketStatus;
  final bool isCurrentSession;
  final String source;
  final String dataQualityStatus;

  bool get isStale =>
      !isCurrentSession || dataQualityStatus.toLowerCase() == 'stale';

  factory MarketOverview.fromJson(Map<String, dynamic> json) {
    return MarketOverview(
      totalIndexValue: _parseNullableDouble(
        _read(json, 'totalIndexValue', 'total_index_value'),
      ),
      totalIndexChange: _parseNullableDouble(
        _read(json, 'totalIndexChange', 'total_index_change'),
      ),
      equalWeightIndexValue: _parseNullableDouble(
        _read(json, 'equalWeightIndexValue', 'equal_weight_index_value'),
      ),
      equalWeightIndexChange: _parseNullableDouble(
        _read(json, 'equalWeightIndexChange', 'equal_weight_index_change'),
      ),
      marketValue:
          _parseNullableDouble(_read(json, 'marketValue', 'market_value')),
      tradesCount:
          _parseNullableInt(_read(json, 'tradesCount', 'trades_count')),
      tradesValue:
          _parseNullableDouble(_read(json, 'tradesValue', 'trades_value')),
      tradesVolume:
          _parseNullableDouble(_read(json, 'tradesVolume', 'trades_volume')),
      priceInfoTimestamp: _parseDateTime(
        _read(json, 'priceInfoTimestamp', 'price_info_timestamp'),
      ),
      serverReceivedAt: _parseDateTime(
        _read(json, 'serverReceivedAt', 'server_received_at'),
      ),
      marketStatus:
          _read(json, 'marketStatus', 'market_status')?.toString() ?? 'unknown',
      isCurrentSession: _parseBool(
        _read(json, 'isCurrentSession', 'is_current_session'),
      ),
      source: json['source']?.toString() ?? '',
      dataQualityStatus:
          _read(json, 'dataQualityStatus', 'data_quality_status')?.toString() ??
              'unknown',
    );
  }
}

/// Quote-like response shared by watch, symbol quote, and portfolio display.
class MarketQuote {
  const MarketQuote({
    required this.symbol,
    this.instrumentId,
    this.lastPrice,
    this.closingPrice,
    this.yesterdayPrice,
    this.priceChange,
    this.priceChangePercent,
    this.volume,
    this.value,
    this.tradeCount,
    this.tradeDate,
    this.eventTime,
    this.receivedAt,
    this.marketStatus = 'unknown',
    this.isCurrentSession = false,
    this.isStale = true,
    this.source = '',
  });

  final String symbol;
  final String? instrumentId;
  final double? lastPrice;
  final double? closingPrice;
  final double? yesterdayPrice;
  final double? priceChange;
  final double? priceChangePercent;
  final double? volume;
  final double? value;
  final int? tradeCount;
  final DateTime? tradeDate;
  final DateTime? eventTime;
  final DateTime? receivedAt;
  final String marketStatus;
  final bool isCurrentSession;
  final bool isStale;
  final String source;

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    return MarketQuote(
      symbol: json['symbol']?.toString() ??
          json['ticker']?.toString() ??
          _read(json, 'tickerSymbol', 'ticker_symbol')?.toString() ??
          '',
      instrumentId: _read(json, 'instrumentId', 'instrument_id')?.toString() ??
          _read(json, 'insCode', 'ins_code')?.toString(),
      lastPrice: _parseNullableDouble(
        _read(json, 'lastPrice', 'last_price') ??
            _read(json, 'lastTradePrice', 'last_trade_price') ??
            _read(json, 'currentPrice', 'current_price'),
      ),
      closingPrice: _parseNullableDouble(
        _read(json, 'closingPrice', 'closing_price') ??
            _read(json, 'closePrice', 'close_price'),
      ),
      yesterdayPrice: _parseNullableDouble(
        _read(json, 'yesterdayPrice', 'yesterday_price'),
      ),
      priceChange:
          _parseNullableDouble(_read(json, 'priceChange', 'price_change')),
      priceChangePercent: _parseNullableDouble(
        _read(json, 'priceChangePercent', 'price_change_percent') ??
            _read(json, 'priceChangePct', 'price_change_pct'),
      ),
      volume: _parseNullableDouble(json['volume']),
      value: _parseNullableDouble(json['value']),
      tradeCount: _parseNullableInt(_read(json, 'tradeCount', 'trade_count')),
      tradeDate: _parseDateTime(_read(json, 'tradeDate', 'trade_date')),
      eventTime: _parseDateTime(_read(json, 'eventTime', 'event_time')),
      receivedAt: _parseDateTime(_read(json, 'receivedAt', 'received_at')),
      marketStatus:
          _read(json, 'marketStatus', 'market_status')?.toString() ?? 'unknown',
      isCurrentSession: _parseBool(
        _read(json, 'isCurrentSession', 'is_current_session'),
      ),
      isStale: _parseBool(_read(json, 'isStale', 'is_stale'), fallback: true),
      source: json['source']?.toString() ?? '',
    );
  }
}

class MarketWatchResponse {
  const MarketWatchResponse({
    this.items = const [],
    this.page = 1,
    this.pageSize = 100,
    this.count = 0,
    this.compact = false,
    this.serverTime,
    this.dataQualityStatus = 'unknown',
    this.marketStatus = 'unknown',
    this.isCurrentSession = false,
    this.isStale = true,
    this.source = '',
  });

  final List<MarketQuote> items;
  final int page;
  final int pageSize;
  final int count;
  final bool compact;
  final DateTime? serverTime;
  final String dataQualityStatus;
  final String marketStatus;
  final bool isCurrentSession;
  final bool isStale;
  final String source;

  factory MarketWatchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['quotes'] ?? json['data'];
    return MarketWatchResponse(
      items: _asMapList(rawItems)
          .map(MarketQuote.fromJson)
          .toList(growable: false),
      page: _parseInt(json['page'], fallback: 1),
      pageSize: _parseInt(_read(json, 'pageSize', 'page_size'), fallback: 100),
      count: _parseInt(json['count']),
      compact: _parseBool(json['compact']),
      serverTime: _parseDateTime(_read(json, 'serverTime', 'server_time')),
      dataQualityStatus:
          _read(json, 'dataQualityStatus', 'data_quality_status')?.toString() ??
              'unknown',
      marketStatus:
          _read(json, 'marketStatus', 'market_status')?.toString() ?? 'unknown',
      isCurrentSession: _parseBool(
        _read(json, 'isCurrentSession', 'is_current_session'),
      ),
      isStale: _parseBool(_read(json, 'isStale', 'is_stale'), fallback: true),
      source: json['source']?.toString() ?? '',
    );
  }
}

/// Live market snapshot for a single instrument.
class LiveMarketSnapshot {
  const LiveMarketSnapshot({
    required this.insCode,
    required this.ticker,
    required this.closePrice,
    required this.lastTradePrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.state,
    required this.hasCorporateAction,
    this.fetchedAt,
    this.lastUpdatedAt,
    this.isFresh = true,
  });

  final String insCode;
  final String ticker;
  final double closePrice;
  final double lastTradePrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int volume;
  final String state;
  final bool hasCorporateAction;
  final DateTime? fetchedAt;
  final DateTime? lastUpdatedAt;
  final bool isFresh;

  double get lastPrice => lastTradePrice;
  double get closingPrice => closePrice;

  /// Whether the instrument is currently tradeable.
  bool get isTradeable =>
      state.toUpperCase() != 'HALT' &&
      state.toUpperCase() != 'SUSPENDED' &&
      state.toUpperCase() != 'CLOSED' &&
      state.toUpperCase() != 'STOPPED';

  /// Price change from open.
  double get change => closePrice - openPrice;

  /// Price change percentage from open.
  double get changePercent => openPrice > 0 ? (change / openPrice) * 100 : 0;

  factory LiveMarketSnapshot.fromJson(Map<String, dynamic> json) {
    final quote = MarketQuote.fromJson(json);
    return LiveMarketSnapshot(
      insCode: quote.instrumentId ?? '',
      ticker: quote.symbol,
      closePrice: quote.closingPrice ?? 0,
      lastTradePrice: quote.lastPrice ?? 0,
      openPrice: _parseDouble(_read(json, 'openPrice', 'open_price')),
      highPrice: _parseDouble(_read(json, 'highPrice', 'high_price')),
      lowPrice: _parseDouble(_read(json, 'lowPrice', 'low_price')),
      volume: _parseInt(json['volume']),
      state: json['state']?.toString() ?? 'UNKNOWN',
      hasCorporateAction:
          _parseBool(_read(json, 'hasCorporateAction', 'has_corporate_action')),
      fetchedAt: _parseDateTime(_read(json, 'fetchedAt', 'fetched_at')),
      lastUpdatedAt: _parseDateTime(
        _read(json, 'lastUpdatedAt', 'last_updated_at') ??
            _read(json, 'lastMarketUpdate', 'last_market_update') ??
            _read(json, 'receivedAt', 'received_at'),
      ),
      isFresh: !_parseBool(_read(json, 'isStale', 'is_stale')) &&
          _parseBool(_read(json, 'isFresh', 'is_fresh'), fallback: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'insCode': insCode,
        'ticker': ticker,
        'closePrice': closePrice.toString(),
        'lastTradePrice': lastTradePrice.toString(),
        'lastPrice': lastPrice.toString(),
        'closingPrice': closingPrice.toString(),
        'openPrice': openPrice.toString(),
        'highPrice': highPrice.toString(),
        'lowPrice': lowPrice.toString(),
        'volume': volume,
        'state': state,
        'hasCorporateAction': hasCorporateAction,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
        'isFresh': isFresh,
      };
}

/// Historical price bar for a symbol.
class PriceBar {
  const PriceBar({
    required this.date,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.closePrice,
    required this.adjustedClose,
    required this.volume,
  });

  final DateTime date;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final double closePrice;
  final double adjustedClose;
  final int volume;

  factory PriceBar.fromJson(Map<String, dynamic> json) {
    return PriceBar(
      date: _parseDateTime(json['date']) ?? DateTime.now(),
      openPrice: _parseDouble(_read(json, 'openPrice', 'open_price')),
      highPrice: _parseDouble(_read(json, 'highPrice', 'high_price')),
      lowPrice: _parseDouble(_read(json, 'lowPrice', 'low_price')),
      closePrice: _parseDouble(_read(json, 'closePrice', 'close_price')),
      adjustedClose:
          _parseDouble(_read(json, 'adjustedClose', 'adjusted_close')),
      volume: _parseInt(json['volume']),
    );
  }
}

/// Symbol history response containing multiple price bars.
class SymbolHistory {
  const SymbolHistory({
    required this.assetId,
    required this.ticker,
    required this.bars,
    required this.startDate,
    required this.endDate,
  });

  final String assetId;
  final String ticker;
  final List<PriceBar> bars;
  final DateTime startDate;
  final DateTime endDate;

  int get count => bars.length;

  factory SymbolHistory.fromJson(Map<String, dynamic> json) {
    final barsList = (json['bars'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PriceBar.fromJson)
            .toList() ??
        [];

    return SymbolHistory(
      assetId: _read(json, 'assetId', 'asset_id')?.toString() ?? '',
      ticker: json['ticker']?.toString() ?? '',
      bars: barsList,
      startDate: _parseDateTime(_read(json, 'startDate', 'start_date')) ??
          DateTime.now(),
      endDate:
          _parseDateTime(_read(json, 'endDate', 'end_date')) ?? DateTime.now(),
    );
  }
}

/// Market status and freshness metadata.
class MarketStatus {
  const MarketStatus({
    required this.providerStatus,
    this.lastSyncAt,
    this.syncedAssets = 0,
    this.failedAssets = 0,
    this.isMarketOpen = true,
    this.isTradingDay = true,
    this.dataFreshnessSeconds,
    this.isStale = true,
    this.marketStatus = 'unknown',
    this.isCurrentSession = false,
    this.dataQualityStatus = 'unknown',
    this.serverTime,
    required this.checkedAt,
  });

  final String providerStatus;
  final String? lastSyncAt;
  final int syncedAssets;
  final int failedAssets;
  final bool isMarketOpen;
  final bool isTradingDay;
  final int? dataFreshnessSeconds;
  final bool isStale;
  final String marketStatus;
  final bool isCurrentSession;
  final String dataQualityStatus;
  final DateTime? serverTime;
  final DateTime checkedAt;

  /// Whether the provider is healthy.
  bool get isHealthy => providerStatus.toLowerCase() == 'healthy';

  /// Persian provider status label for UI.
  String get providerStatusLabel {
    return switch (providerStatus.toLowerCase()) {
      'healthy' => 'سالم',
      'degraded' => 'کند',
      'down' => 'قطع',
      'unknown' => 'ناشناخته',
      _ => 'ناشناخته',
    };
  }

  /// Human-readable freshness description.
  String get freshnessDescription {
    final seconds = dataFreshnessSeconds;
    if (seconds == null) return 'ناشناخته';
    if (seconds < 60) return 'لحظاتی پیش';
    if (seconds < 3600) {
      return '${(seconds / 60).floor()} دقیقه پیش';
    }
    if (seconds < 86400) {
      return '${(seconds / 3600).floor()} ساعت پیش';
    }
    return '${(seconds / 86400).floor()} روز پیش';
  }

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    return MarketStatus(
      providerStatus:
          _read(json, 'providerStatus', 'provider_status')?.toString() ??
              'unknown',
      lastSyncAt: _read(json, 'lastSyncAt', 'last_sync_at')?.toString(),
      syncedAssets: _parseInt(_read(json, 'syncedAssets', 'synced_assets')),
      failedAssets: _parseInt(_read(json, 'failedAssets', 'failed_assets')),
      isMarketOpen: _parseBool(_read(json, 'isMarketOpen', 'is_market_open'),
          fallback: true),
      isTradingDay: _parseBool(_read(json, 'isTradingDay', 'is_trading_day'),
          fallback: true),
      dataFreshnessSeconds: _parseNullableInt(
          _read(json, 'dataFreshnessSeconds', 'data_freshness_seconds')),
      isStale: _parseBool(_read(json, 'isStale', 'is_stale'), fallback: true),
      marketStatus: _read(json, 'marketStatus', 'market_status')?.toString() ??
          (_parseBool(_read(json, 'isMarketOpen', 'is_market_open'))
              ? 'open'
              : 'closed'),
      isCurrentSession: _parseBool(
        _read(json, 'isCurrentSession', 'is_current_session'),
      ),
      dataQualityStatus:
          _read(json, 'dataQualityStatus', 'data_quality_status')?.toString() ??
              'unknown',
      serverTime: _parseDateTime(_read(json, 'serverTime', 'server_time')),
      checkedAt: _parseDateTime(_read(json, 'checkedAt', 'checked_at')) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Market index snapshot (e.g., TEDPIX).
class IndexSnapshot {
  const IndexSnapshot({
    required this.indexCode,
    required this.name,
    required this.lastValue,
    required this.changeValue,
    required this.changePercent,
    required this.openValue,
    required this.highValue,
    required this.lowValue,
    required this.volume,
    this.fetchedAt,
    this.source = '',
  });

  final String indexCode;
  final String name;
  final double lastValue;
  final double changeValue;
  final double changePercent;
  final double openValue;
  final double highValue;
  final double lowValue;
  final int volume;
  final DateTime? fetchedAt;
  final String source;

  factory IndexSnapshot.fromJson(Map<String, dynamic> json) {
    return IndexSnapshot(
      indexCode: _read(json, 'indexCode', 'index_code')?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lastValue: _parseDouble(
        _read(json, 'lastValue', 'last_value') ?? _read(json, 'value', 'value'),
      ),
      changeValue: _parseDouble(_read(json, 'changeValue', 'change_value')),
      changePercent:
          _parseDouble(_read(json, 'changePercent', 'change_percent')),
      openValue: _parseDouble(_read(json, 'openValue', 'open_value')),
      highValue: _parseDouble(_read(json, 'highValue', 'high_value')),
      lowValue: _parseDouble(_read(json, 'lowValue', 'low_value')),
      volume: _parseInt(json['volume']),
      fetchedAt: _parseDateTime(_read(json, 'fetchedAt', 'fetched_at')),
      source: json['source']?.toString() ?? '',
    );
  }
}

/// Batch response for multiple live snapshots.
class LiveMarketBatch {
  const LiveMarketBatch({
    required this.snapshots,
    required this.count,
    required this.fetchedAt,
  });

  final List<LiveMarketSnapshot> snapshots;
  final int count;
  final DateTime fetchedAt;

  factory LiveMarketBatch.fromJson(Map<String, dynamic> json) {
    final snapshotsList = (json['snapshots'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(LiveMarketSnapshot.fromJson)
            .toList() ??
        [];

    return LiveMarketBatch(
      snapshots: snapshotsList,
      count: _parseInt(json['count']),
      fetchedAt: _parseDateTime(_read(json, 'fetchedAt', 'fetched_at')) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Normalized corporate disclosure served by the backend Codal pipeline.
class MarketDisclosure {
  const MarketDisclosure({
    required this.trackingNumber,
    required this.symbol,
    required this.title,
    required this.hasAttachment,
    required this.source,
    this.companyName,
    this.letterCode,
    this.sentAt,
    this.publishedAt,
    this.category,
    this.url,
  });

  final String trackingNumber;
  final String symbol;
  final String? companyName;
  final String title;
  final String? letterCode;
  final DateTime? sentAt;
  final DateTime? publishedAt;
  final String? category;
  final String? url;
  final bool hasAttachment;
  final String source;

  factory MarketDisclosure.fromJson(Map<String, dynamic> json) {
    return MarketDisclosure(
      trackingNumber:
          _read(json, 'trackingNumber', 'tracking_number')?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      companyName: _read(json, 'companyName', 'company_name')?.toString(),
      title: json['title']?.toString() ?? '',
      letterCode: _read(json, 'letterCode', 'letter_code')?.toString(),
      sentAt: _parseDateTime(_read(json, 'sentAt', 'sent_at')),
      publishedAt: _parseDateTime(_read(json, 'publishedAt', 'published_at')),
      category: json['category']?.toString(),
      url: json['url']?.toString(),
      hasAttachment: _parseBool(
        _read(json, 'hasAttachment', 'has_attachment'),
      ),
      source: json['source']?.toString() ?? 'CODAL',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════

double _parseDouble(Object? value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  return _parseNullableDouble(value) ?? fallback;
}

double? _parseNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) {
    final parsed = value.toDouble();
    return parsed.isFinite ? parsed : null;
  }
  final normalized = value
      .toString()
      .trim()
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll('،', '')
      .toLowerCase();
  if (normalized.isEmpty) return null;
  final hasBillionSuffix = RegExp(r'\b(b|bn|billion)\b').hasMatch(normalized);
  final numeric =
      normalized.replaceAll(RegExp(r'\b(bn|billion|b)\b'), '').trim();
  final parsed = double.tryParse(numeric);
  if (parsed == null || !parsed.isFinite) return null;
  return hasBillionSuffix ? parsed * 1000000000 : parsed;
}

Object? _read(Map<String, dynamic> json, String camelKey, String snakeKey) {
  if (json.containsKey(camelKey)) return json[camelKey];
  return json[snakeKey];
}

int _parseInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _parseNullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().replaceAll(',', '').replaceAll('٬', ''));
}

bool _parseBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase().trim();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
