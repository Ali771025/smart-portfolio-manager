/// Domain models for watchlist and alert API responses.
/// Watchlist with symbols summary.
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    this.description,
    this.symbols = const [],
    this.symbolCount = 0,
    this.alertCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<WatchlistSymbol> symbols;
  final int symbolCount;
  final int alertCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Watchlist.fromJson(Map<String, dynamic> json) {
    return Watchlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      symbols: (_read(json, 'symbols') as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(WatchlistSymbol.fromJson)
              .toList() ??
          [],
      symbolCount: _parseInt(_read(json, 'symbolCount', 'symbol_count')) ?? 0,
      alertCount: _parseInt(_read(json, 'alertCount', 'alert_count')) ?? 0,
      createdAt: _parseDate(_read(json, 'createdAt', 'created_at')),
      updatedAt: _parseDate(_read(json, 'updatedAt', 'updated_at')),
    );
  }
}

/// Watchlist symbol with current market data.
class WatchlistSymbol {
  const WatchlistSymbol({
    required this.symbol,
    this.nameFa,
    this.nameEn,
    this.insCode,
    this.currentPrice,
    this.lastPrice,
    this.closingPrice,
    this.priceChange,
    this.priceChangePct,
    this.lastUpdatedAt,
    this.volume,
    this.isTradeable = true,
    required this.addedAt,
  });

  final String symbol;
  final String? nameFa;
  final String? nameEn;
  final String? insCode;
  final double? currentPrice;
  final double? lastPrice;
  final double? closingPrice;
  final double? priceChange;
  final double? priceChangePct;
  final DateTime? lastUpdatedAt;
  final int? volume;
  final bool isTradeable;
  final DateTime addedAt;

  factory WatchlistSymbol.fromJson(Map<String, dynamic> json) {
    final lastPrice = _parseDouble(
      _read(json, 'lastPrice', 'last_price') ??
          _read(json, 'currentPrice', 'current_price') ??
          _read(json, 'latestPrice', 'latest_price'),
    );
    return WatchlistSymbol(
      symbol: json['symbol']?.toString() ?? '',
      nameFa: _read(json, 'nameFa', 'name_fa')?.toString(),
      nameEn: _read(json, 'nameEn', 'name_en')?.toString(),
      insCode: _read(json, 'insCode', 'ins_code')?.toString(),
      currentPrice: _parseDouble(
        _read(json, 'currentPrice', 'current_price') ?? lastPrice,
      ),
      lastPrice: lastPrice,
      closingPrice: _parseDouble(
        _read(json, 'closingPrice', 'closing_price') ??
            _read(json, 'closePrice', 'close_price'),
      ),
      priceChange: _parseDouble(_read(json, 'priceChange', 'price_change')),
      priceChangePct: _parseDouble(
        _read(json, 'priceChangePct', 'price_change_pct') ??
            _read(json, 'priceChangePercent', 'price_change_percent'),
      ),
      lastUpdatedAt: _parseNullableDate(
        _read(json, 'lastUpdatedAt', 'last_updated_at') ??
            _read(json, 'lastMarketUpdate', 'last_market_update'),
      ),
      volume: _parseInt(_read(json, 'volume')),
      isTradeable: _parseBool(_read(json, 'isTradeable', 'is_tradeable')),
      addedAt: _parseDate(_read(json, 'addedAt', 'added_at')),
    );
  }
}

/// Alert rule definition.
class AlertRule {
  const AlertRule({
    required this.id,
    required this.symbol,
    required this.alertType,
    required this.threshold,
    this.thresholdPct,
    required this.status,
    this.frequency = 'always',
    this.notificationChannels = const [],
    this.messageTemplate,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastTriggeredAt,
    this.triggerCount = 0,
  });

  final String id;
  final String symbol;
  final String alertType;
  final double threshold;
  final double? thresholdPct;
  final String status;
  final String frequency;
  final List<String> notificationChannels;
  final String? messageTemplate;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastTriggeredAt;
  final int triggerCount;

  bool get isActive => status == 'ACTIVE';
  bool get isTriggered => status == 'TRIGGERED';
  bool get isPaused => status == 'PAUSED';

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      alertType: _read(json, 'alertType', 'alert_type')?.toString() ?? '',
      threshold: _parseDouble(_read(json, 'threshold')) ?? 0,
      thresholdPct: _parseDouble(_read(json, 'thresholdPct', 'threshold_pct')),
      status: json['status']?.toString() ?? 'ACTIVE',
      frequency: json['frequency']?.toString() ?? 'always',
      notificationChannels: (_read(
                json,
                'notificationChannels',
                'notification_channels',
              ) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      messageTemplate:
          _read(json, 'messageTemplate', 'message_template')?.toString(),
      expiresAt: _read(json, 'expiresAt', 'expires_at') != null
          ? DateTime.tryParse(_read(json, 'expiresAt', 'expires_at').toString())
          : null,
      createdAt: _parseDate(_read(json, 'createdAt', 'created_at')),
      updatedAt: _parseDate(_read(json, 'updatedAt', 'updated_at')),
      lastTriggeredAt: _read(json, 'lastTriggeredAt', 'last_triggered_at') != null
          ? DateTime.tryParse(
              _read(json, 'lastTriggeredAt', 'last_triggered_at').toString(),
            )
          : null,
      triggerCount: _parseInt(_read(json, 'triggerCount', 'trigger_count')) ?? 0,
    );
  }
}

/// Alert event record.
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.alertId,
    required this.symbol,
    required this.alertType,
    required this.triggeredAt,
    required this.priceAtTrigger,
    required this.thresholdValue,
    this.changePct,
    this.notificationSent = false,
    this.notificationChannels = const [],
    this.acknowledgedAt,
  });

  final String id;
  final String alertId;
  final String symbol;
  final String alertType;
  final DateTime triggeredAt;
  final double priceAtTrigger;
  final double thresholdValue;
  final double? changePct;
  final bool notificationSent;
  final List<String> notificationChannels;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      id: json['id']?.toString() ?? '',
      alertId: _read(json, 'alertId', 'alert_id')?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      alertType: _read(json, 'alertType', 'alert_type')?.toString() ?? '',
      triggeredAt: _parseDate(_read(json, 'triggeredAt', 'triggered_at')),
      priceAtTrigger:
          _parseDouble(_read(json, 'priceAtTrigger', 'price_at_trigger')) ?? 0,
      thresholdValue:
          _parseDouble(_read(json, 'thresholdValue', 'threshold_value')) ?? 0,
      changePct: _parseDouble(_read(json, 'changePct', 'change_pct')),
      notificationSent:
          _parseBool(_read(json, 'notificationSent', 'notification_sent')),
      notificationChannels: (_read(
                json,
                'notificationChannels',
                'notification_channels',
              ) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      acknowledgedAt: _read(json, 'acknowledgedAt', 'acknowledged_at') != null
          ? DateTime.tryParse(
              _read(json, 'acknowledgedAt', 'acknowledged_at').toString(),
            )
          : null,
    );
  }
}

/// Alert summary statistics.
class AlertSummary {
  const AlertSummary({
    this.totalActiveAlerts = 0,
    this.totalTriggeredToday = 0,
    this.totalUnacknowledged = 0,
    this.alertsByType = const {},
    this.mostTriggeredSymbol,
  });

  final int totalActiveAlerts;
  final int totalTriggeredToday;
  final int totalUnacknowledged;
  final Map<String, int> alertsByType;
  final String? mostTriggeredSymbol;

  factory AlertSummary.fromJson(Map<String, dynamic> json) {
    return AlertSummary(
      totalActiveAlerts:
          _parseInt(_read(json, 'totalActiveAlerts', 'total_active_alerts')) ?? 0,
      totalTriggeredToday:
          _parseInt(_read(json, 'totalTriggeredToday', 'total_triggered_today')) ??
              0,
      totalUnacknowledged:
          _parseInt(_read(json, 'totalUnacknowledged', 'total_unacknowledged')) ??
              0,
      alertsByType:
          (_read(json, 'alertsByType', 'alerts_by_type') as Map? ?? {})
              .map((key, value) => MapEntry(key.toString(), _parseInt(value) ?? 0)),
      mostTriggeredSymbol:
          _read(json, 'mostTriggeredSymbol', 'most_triggered_symbol')?.toString(),
    );
  }
}

/// Alert summary response with recent events.
class AlertSummaryResponse {
  const AlertSummaryResponse({
    required this.summary,
    this.recentEvents = const [],
  });

  final AlertSummary summary;
  final List<AlertEvent> recentEvents;

  factory AlertSummaryResponse.fromJson(Map<String, dynamic> json) {
    return AlertSummaryResponse(
      summary: AlertSummary.fromJson(
        (_read(json, 'summary') as Map?)?.cast<String, dynamic>() ?? {},
      ),
      recentEvents: (_read(json, 'recentEvents', 'recent_events') as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(AlertEvent.fromJson)
              .toList() ??
          [],
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _parseBool(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  return value.toString().toLowerCase() == 'true';
}

DateTime _parseDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

DateTime? _parseNullableDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

dynamic _read(
  Map<String, dynamic> json,
  String primary, [
  String? fallback,
]) {
  if (json.containsKey(primary)) return json[primary];
  if (fallback != null && json.containsKey(fallback)) return json[fallback];
  return null;
}
