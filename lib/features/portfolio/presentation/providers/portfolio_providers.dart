import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/network/app_failure.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

@immutable
class PortfolioListItem {
  const PortfolioListItem({
    required this.id,
    required this.name,
    required this.baseCurrency,
    required this.totalCurrentValue,
    required this.totalInvestedCapital,
    required this.totalUnrealizedPnl,
    required this.dailyPnl,
    required this.roiPercent,
    this.currentPrice,
    this.closingPrice,
    this.lastMarketUpdate,
  });

  final String id;
  final String name;
  final String baseCurrency;
  final double totalCurrentValue;
  final double totalInvestedCapital;
  final double totalUnrealizedPnl;
  final double dailyPnl;
  final double roiPercent;
  final double? currentPrice;
  final double? closingPrice;
  final DateTime? lastMarketUpdate;

  bool get isPositive => roiPercent >= 0;

  factory PortfolioListItem.fromJson(Map<String, dynamic> json) {
    return PortfolioListItem(
      id: (json['portfolio_id'] ?? json['id'] ?? '').toString(),
      name: (json['portfolio_name'] ?? json['name'] ?? 'پرتفوی بدون نام').toString(),
      baseCurrency: (json['base_currency'] ?? 'IRR').toString(),
      totalCurrentValue: _asDouble(json['total_current_value']),
      totalInvestedCapital: _asDouble(json['total_invested_capital'] ?? json['total_invested_value']),
      totalUnrealizedPnl: _asDouble(json['total_unrealized_pnl']),
      dailyPnl: _asDouble(json['daily_pnl']),
      roiPercent: _asDouble(json['roi_percent'] ?? json['roi_pct']),
      currentPrice: _asNullableDouble(json['current_price']),
      closingPrice: _asNullableDouble(json['closing_price']),
      lastMarketUpdate: _asDate(json['last_market_update'] ?? json['last_updated_at']),
    );
  }

  factory PortfolioListItem.skeleton(int index) {
    return PortfolioListItem(
      id: 'skeleton-$index',
      name: 'پرتفوی نمونه $index',
      baseCurrency: 'IRR',
      totalCurrentValue: 42000000,
      totalInvestedCapital: 40000000,
      totalUnrealizedPnl: index.isEven ? 1900000 : -1300000,
      dailyPnl: index.isEven ? 250000 : -180000,
      roiPercent: index.isEven ? 4.75 : -3.25,
    );
  }
}

@immutable
class AssetPositionHeader {
  const AssetPositionHeader({
    required this.portfolioId,
    required this.ticker,
    required this.currentQuantity,
    required this.averageBuyPrice,
    required this.currentLivePrice,
    required this.lastPrice,
    required this.closingPrice,
    required this.assetPnl,
    required this.dailyPnl,
    this.lastMarketUpdate,
  });

  final String portfolioId;
  final String ticker;
  final double currentQuantity;
  final double averageBuyPrice;
  final double currentLivePrice;
  final double lastPrice;
  final double closingPrice;
  final double assetPnl;
  final double dailyPnl;
  final DateTime? lastMarketUpdate;

  bool get isPositive => assetPnl >= 0;

  factory AssetPositionHeader.fromJson(Map<String, dynamic> json) {
    return AssetPositionHeader(
      portfolioId: (json['portfolio_id'] ?? '').toString(),
      ticker: (json['ticker'] ?? '').toString(),
      currentQuantity: _asDouble(json['current_quantity']),
      averageBuyPrice: _asDouble(json['average_buy_price']),
      currentLivePrice: _asDouble(
        json['current_live_price'] ?? json['current_price'] ?? json['last_price'],
      ),
      lastPrice: _asDouble(json['last_price'] ?? json['current_price'] ?? json['latest_price']),
      closingPrice: _asDouble(json['closing_price'] ?? json['close_price']),
      assetPnl: _asDouble(json['asset_pnl'] ?? json['unrealized_pnl']),
      dailyPnl: _asDouble(json['daily_pnl']),
      lastMarketUpdate: _asDate(json['last_market_update'] ?? json['last_updated_at']),
    );
  }
}

@immutable
class TradeHistoryItemView {
  const TradeHistoryItemView({
    required this.dateJalali,
    required this.tradeType,
    required this.quantity,
    required this.unitPrice,
    required this.totalTradeValue,
  });

  final String dateJalali;
  final String tradeType;
  final double quantity;
  final double unitPrice;
  final double totalTradeValue;

  bool get isBuy => tradeType.toUpperCase() == 'BUY';

  factory TradeHistoryItemView.fromJson(Map<String, dynamic> json) {
    return TradeHistoryItemView(
      dateJalali: (json['date_jalali'] ?? '').toString(),
      tradeType: (json['trade_type'] ?? 'BUY').toString(),
      quantity: _asDouble(json['quantity']),
      unitPrice: _asDouble(json['unit_price']),
      totalTradeValue: _asDouble(json['total_trade_value']),
    );
  }
}

@immutable
class AssetLedgerState {
  const AssetLedgerState({
    required this.header,
    required this.trades,
    required this.total,
    required this.limit,
    required this.nextOffset,
    this.isLoadingMore = false,
  });

  final AssetPositionHeader header;
  final List<TradeHistoryItemView> trades;
  final int total;
  final int limit;
  final int nextOffset;
  final bool isLoadingMore;

  bool get hasMore => trades.length < total;

  AssetLedgerState copyWith({
    AssetPositionHeader? header,
    List<TradeHistoryItemView>? trades,
    int? total,
    int? limit,
    int? nextOffset,
    bool? isLoadingMore,
  }) {
    return AssetLedgerState(
      header: header ?? this.header,
      trades: trades ?? this.trades,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@immutable
class AssetLedgerArgs {
  const AssetLedgerArgs({
    required this.portfolioId,
    required this.ticker,
    this.limit = 20,
  });

  final String portfolioId;
  final String ticker;
  final int limit;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AssetLedgerArgs &&
            other.portfolioId == portfolioId &&
            other.ticker == ticker &&
            other.limit == limit);
  }

  @override
  int get hashCode => Object.hash(portfolioId, ticker, limit);
}

@immutable
class AssetLedgerPage {
  const AssetLedgerPage({
    required this.header,
    required this.trades,
    required this.total,
    required this.limit,
    required this.nextOffset,
  });

  final AssetPositionHeader header;
  final List<TradeHistoryItemView> trades;
  final int total;
  final int limit;
  final int nextOffset;
}

abstract class PortfolioRepository {
  Future<List<PortfolioListItem>> fetchPortfolioList();

  Future<AssetLedgerPage> fetchAssetLedger({
    required String portfolioId,
    required String ticker,
    required int limit,
    required int offset,
  });
}

class PortfolioApiRepository implements PortfolioRepository {
  PortfolioApiRepository({
    required this.client,
    required this.baseUrl,
    required this.readAccessToken,
  });

  final http.Client client;
  final String baseUrl;
  final String? Function() readAccessToken;

  @override
  Future<List<PortfolioListItem>> fetchPortfolioList() async {
    final token = _tokenOrThrow();

    final uri = Uri.parse('$baseUrl/portfolios');
    final response = await client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFromResponse(
        response,
        fallbackMessage: 'دریافت فهرست پرتفوی‌ها ناموفق بود.',
      );
    }

    final payload = jsonDecode(response.body);
    final entries = _listPayload(payload);
    return entries
        .whereType<Map<String, dynamic>>()
        .map(PortfolioListItem.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AssetLedgerPage> fetchAssetLedger({
    required String portfolioId,
    required String ticker,
    required int limit,
    required int offset,
  }) async {
    final token = _tokenOrThrow();

    final normalizedTicker = ticker.trim().toUpperCase();
    if (portfolioId.trim().isEmpty || normalizedTicker.isEmpty) {
      throw const AppFailure(
        message: 'شناسه پرتفو یا نماد معتبر نیست.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/portfolios/$portfolioId/assets/$normalizedTicker',
    ).replace(
      queryParameters: <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final response = await client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFromResponse(
        response,
        fallbackMessage: 'دریافت جزئیات دارایی ناموفق بود.',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final summaryRaw = payload['asset_summary'];
    final header = summaryRaw is Map<String, dynamic>
        ? AssetPositionHeader.fromJson(summaryRaw)
        : AssetPositionHeader(
            portfolioId: portfolioId,
            ticker: normalizedTicker,
            currentQuantity: 0,
            averageBuyPrice: 0,
            currentLivePrice: 0,
            lastPrice: 0,
            closingPrice: 0,
            assetPnl: 0,
            dailyPnl: 0,
          );

    final rawTrades = payload['transactions'] as List<dynamic>? ?? const <dynamic>[];
    final trades = rawTrades
        .whereType<Map<String, dynamic>>()
        .map(TradeHistoryItemView.fromJson)
        .toList(growable: false);

    final total = _asInt(payload['total']);
    final safeLimit = _asInt(payload['limit']);
    final nextOffset = offset + trades.length;

    return AssetLedgerPage(
      header: header,
      trades: trades,
      total: total,
      limit: safeLimit > 0 ? safeLimit : limit,
      nextOffset: nextOffset,
    );
  }

  String _tokenOrThrow() {
    final token = readAccessToken()?.trim() ?? '';
    if (token.isEmpty) {
      throw const AppFailure(
        message: 'نشست کاربری معتبر نیست.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    return token;
  }

  Map<String, String> _headers(String token) {
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  AppFailure _failureFromResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    String message = fallbackMessage;

    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        final title = payload['title'];

        if (detail != null && detail.toString().trim().isNotEmpty) {
          message = detail.toString();
        } else if (title != null && title.toString().trim().isNotEmpty) {
          message = title.toString();
        }
      }
    } catch (_) {
      // Keep fallback message.
    }

    return AppFailure(
      message: message,
      statusCode: response.statusCode,
      isUnauthorized: response.statusCode == 401,
    );
  }
}

final _portfolioHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioApiRepository(
    client: ref.watch(_portfolioHttpClientProvider),
    baseUrl: defaultApiBaseUrl,
    readAccessToken: () => ref.read(authControllerProvider).value?.accessToken,
  );
});

class PortfolioListNotifier extends StateNotifier<AsyncValue<List<PortfolioListItem>>> {
  PortfolioListNotifier({
    required this.repository,
  }) : super(const AsyncValue.loading());

  static const _cacheKey = 'portfolio_list_cache_v1';
  static const _managerCacheKey = 'portfolio_manager_cache_v1';
  final PortfolioRepository repository;
  int _loadEpoch = 0;
  List<PortfolioListItem> _items = const <PortfolioListItem>[];

  Future<void> restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listCached = _decodeListCache(prefs.getString(_cacheKey));
      final managerCached = _decodeManagerCache(
        prefs.getString(_managerCacheKey),
      );
      final cached = _mergeById(
        preferred: listCached,
        fallback: managerCached,
      );
      if (cached.isEmpty) {
        return;
      }
      _setItems(_mergeById(preferred: _items, fallback: cached));
    } catch (_) {
      // Cache is best effort and must not fail portfolio loading.
    }
  }

  Future<void> load() async {
    final requestEpoch = ++_loadEpoch;
    final previousItems = _items;
    state = const AsyncValue.loading();

    try {
      final remoteItems = await repository.fetchPortfolioList();
      // Prevent stale responses from overwriting newer state
      if (requestEpoch != _loadEpoch) {
        return;
      }

      final localItems = _items.isNotEmpty ? _items : previousItems;
      // Hardening: if backend temporarily returns an empty list while we
      // already have local portfolios, keep local state to avoid flicker/loss.
      if (remoteItems.isEmpty && localItems.isNotEmpty) {
        _setItems(localItems);
        unawaited(_persistCache(localItems));
        return;
      }

      final merged = _mergeById(preferred: remoteItems, fallback: _items);
      _setItems(merged);
      unawaited(_persistCache(merged));
    } catch (error, stackTrace) {
      if (requestEpoch != _loadEpoch) {
        return;
      }
      final latestItems = _items.isNotEmpty ? _items : previousItems;
      if (latestItems.isNotEmpty) {
        // Keep the last known list visible on transient failures.
        _setItems(latestItems);
        return;
      }
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> upsertPortfolio(PortfolioListItem item) async {
    final itemId = item.id.trim();
    if (!_isPersistedPortfolioId(itemId)) {
      return;
    }
    final withoutExisting = _items.where(
      (entry) => entry.id.trim() != itemId,
    );
    final next = <PortfolioListItem>[
      ...withoutExisting,
      item,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _setItems(next);
    await _persistCache(next);
  }

  Future<void> removePortfolio(String portfolioId) async {
    final normalizedId = portfolioId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final next = _items
        .where((item) => item.id.trim() != normalizedId)
        .toList(growable: false);
    _setItems(next);
    await _persistCache(next);
  }

  Future<void> mergePortfolios(
    Iterable<PortfolioListItem> items, {
    bool preserveRecent = true,
  }) async {
    if (preserveRecent) {
      final incomingIds = items
          .map((item) => item.id.trim())
          .where(_isPersistedPortfolioId)
          .toSet();
      final toPreserve = _items.where(
        (item) =>
            _isPersistedPortfolioId(item.id) &&
            !incomingIds.contains(item.id.trim()),
      );

      final merged = _mergeById(
        preferred: [...items, ...toPreserve],
        fallback: _items,
      );
      _setItems(merged);
      await _persistCache(merged);
    } else {
      final merged = _mergeById(preferred: items, fallback: _items);
      _setItems(merged);
      await _persistCache(merged);
    }
  }

  List<PortfolioListItem> _mergeById({
    required Iterable<PortfolioListItem> preferred,
    required Iterable<PortfolioListItem> fallback,
  }) {
    final mergedById = <String, PortfolioListItem>{};
    for (final item in fallback) {
      final id = item.id.trim();
      if (!_isPersistedPortfolioId(id)) {
        continue;
      }
      mergedById[id] = item;
    }
    for (final item in preferred) {
      final id = item.id.trim();
      if (!_isPersistedPortfolioId(id)) {
        continue;
      }
      mergedById[id] = item;
    }
    final merged = mergedById.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  void _setItems(List<PortfolioListItem> items) {
    _items = List<PortfolioListItem>.unmodifiable(items);
    state = AsyncValue.data(_items);
  }

  List<PortfolioListItem> _decodeListCache(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <PortfolioListItem>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PortfolioListItem>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(PortfolioListItem.fromJson)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <PortfolioListItem>[];
    }
  }

  List<PortfolioListItem> _decodeManagerCache(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <PortfolioListItem>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PortfolioListItem>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_portfolioFromManagerCache)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <PortfolioListItem>[];
    }
  }

  PortfolioListItem _portfolioFromManagerCache(Map<String, dynamic> json) {
    return PortfolioListItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'پرتفوی بدون نام').toString(),
      baseCurrency: (json['base_currency'] ?? 'IRR').toString(),
      totalCurrentValue: _asDouble(json['total_value']),
      totalInvestedCapital: 0,
      totalUnrealizedPnl: 0,
      dailyPnl: 0,
      roiPercent: _asDouble(json['roi_percent']),
    );
  }

  Future<void> _persistCache(List<PortfolioListItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items
          .where((item) => _isPersistedPortfolioId(item.id))
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'name': item.name,
              'base_currency': item.baseCurrency,
              'total_current_value': item.totalCurrentValue,
              'total_invested_capital': item.totalInvestedCapital,
              'total_unrealized_pnl': item.totalUnrealizedPnl,
              'daily_pnl': item.dailyPnl,
              'roi_percent': item.roiPercent,
              'current_price': item.currentPrice,
              'closing_price': item.closingPrice,
              'last_market_update': item.lastMarketUpdate?.toIso8601String(),
            },
          )
          .toList(growable: false);
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {
      // Cache write failures are non-fatal.
    }
  }
}

bool _isPersistedPortfolioId(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}

final portfolioListProvider =
    StateNotifierProvider<PortfolioListNotifier, AsyncValue<List<PortfolioListItem>>>(
  (ref) {
    final notifier = PortfolioListNotifier(
      repository: ref.watch(portfolioRepositoryProvider),
    );
    // Delay initial mutation until after the current build pass.
    unawaited(Future<void>(() async {
      await notifier.restoreCache();
      await notifier.load();
    }));
    return notifier;
  },
);

class AssetLedgerNotifier extends StateNotifier<AsyncValue<AssetLedgerState>> {
  AssetLedgerNotifier({
    required this.repository,
    required this.args,
  }) : super(const AsyncValue.loading());

  final PortfolioRepository repository;
  final AssetLedgerArgs args;

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await repository.fetchAssetLedger(
        portfolioId: args.portfolioId,
        ticker: args.ticker,
        limit: args.limit,
        offset: 0,
      );
      return AssetLedgerState(
        header: page.header,
        trades: page.trades,
        total: page.total,
        limit: page.limit,
        nextOffset: page.nextOffset,
      );
    });
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final page = await repository.fetchAssetLedger(
        portfolioId: args.portfolioId,
        ticker: args.ticker,
        limit: current.limit,
        offset: current.nextOffset,
      );

      final mergedTrades = <TradeHistoryItemView>[
        ...current.trades,
        ...page.trades,
      ];

      state = AsyncValue.data(
        current.copyWith(
          header: page.header,
          trades: mergedTrades,
          total: page.total,
          limit: page.limit,
          nextOffset: page.nextOffset,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final assetLedgerProvider = StateNotifierProvider.autoDispose
    .family<AssetLedgerNotifier, AsyncValue<AssetLedgerState>, AssetLedgerArgs>((ref, args) {
  final notifier = AssetLedgerNotifier(
    repository: ref.watch(portfolioRepositoryProvider),
    args: args,
  );
  unawaited(notifier.loadInitial());
  return notifier;
});

List<dynamic> _listPayload(dynamic payload) {
  if (payload is List<dynamic>) {
    return payload;
  }
  if (payload is Map<String, dynamic>) {
    final entries = payload['items'];
    if (entries is List<dynamic>) {
      return entries;
    }
  }
  return const <dynamic>[];
}

double _asDouble(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value.toString());
  if (parsed == null || parsed.isNaN || !parsed.isFinite) {
    return null;
  }
  return parsed;
}

DateTime? _asDate(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString())?.toUtc();
}

int _asInt(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? 0;
}
