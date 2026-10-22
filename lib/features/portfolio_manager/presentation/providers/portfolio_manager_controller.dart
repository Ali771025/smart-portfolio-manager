import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/app_failure.dart';
import '../../../portfolio/presentation/providers/portfolio_providers.dart';
import '../../data/portfolio_manager_repository.dart';
import '../../domain/models/portfolio_card_dto.dart';

part 'portfolio_manager_controller.g.dart';

final selectedPortfolioIdProvider = StateProvider<String?>((ref) => null);

class PortfolioCreateFailure {
  const PortfolioCreateFailure({
    required this.name,
    required this.failure,
  });

  final String name;
  final AppFailure failure;
}

class PortfolioBatchCreateResult {
  const PortfolioBatchCreateResult({
    required this.created,
    required this.failures,
  });

  final List<PortfolioCardDto> created;
  final List<PortfolioCreateFailure> failures;

  bool get hasFailures => failures.isNotEmpty;
}

@Riverpod(keepAlive: true)
class PortfolioManagerController extends _$PortfolioManagerController {
  static const _selectedPortfolioPrefsKey = 'selected_portfolio_id';
  static const _portfolioCacheKey = 'portfolio_manager_cache_v1';
  static const _legacyPortfolioListCacheKey = 'portfolio_list_cache_v1';

  PortfolioManagerRepository get _repository => ref.read(
        portfolioManagerRepositoryProvider,
      );

  final Map<String, ({PortfolioCardDto portfolio, DateTime createdAt})>
      _pendingPortfolios = {};

  final Set<String> _creatingNameKeys = <String>{};
  int _fetchEpoch = 0;
  bool _didRestoreSelection = false;
  bool _didBindSelectionPersistence = false;

  @override
  Future<List<PortfolioCardDto>> build() async {
    _bindSelectionPersistence();
    await _restoreSelectedPortfolio();
    final cachedPortfolios = await _restoreCachedPortfolios();
    if (cachedPortfolios.isNotEmpty) {
      state = AsyncValue.data(cachedPortfolios);
      _syncListProvider(cachedPortfolios);
    }
    final portfolios = await _fetchAndMerge(seed: cachedPortfolios);
    _ensureSelectedPortfolio(portfolios);
    _syncListProvider(portfolios);
    unawaited(_persistCachedPortfolios(portfolios));
    return portfolios;
  }

  Future<Either<AppFailure, PortfolioCardDto>> addPortfolio(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const Left(
        AppFailure(message: 'نام پرتفوی نباید خالی باشد.'),
      );
    }

    final nameKey = _portfolioNameKey(trimmedName);
    if (!_creatingNameKeys.add(nameKey)) {
      return const Left(
        AppFailure(message: 'این پرتفوی در حال ایجاد است.'),
      );
    }

    final optimisticId = 'tmp-${DateTime.now().microsecondsSinceEpoch}';
    final tempPortfolio = PortfolioCardDto(
      id: optimisticId,
      name: trimmedName,
      totalValue: 0,
      roiPercent: 0,
      riskStdDeviation: 0,
      sparklineValues: const <double>[],
      isDefault: false,
    );
    _pendingPortfolios[optimisticId] = (
      portfolio: tempPortfolio,
      createdAt: DateTime.now(),
    );

    state = AsyncValue.data(_mergeWithPending(state.value ?? const []));

    try {
      final result = await _repository.createPortfolio(name: trimmedName);
      if (result.isLeft()) {
        final failure = result.swap().getOrElse(
              (_) => const AppFailure(message: 'ایجاد پرتفوی انجام نشد.'),
            );
        _pendingPortfolios.remove(optimisticId);
        final cleaned = _removeById(
          state.value ?? const [],
          optimisticId,
        );
        await _commitPortfolios(_mergeWithPending(cleaned));
        return Left(failure);
      }

      final createdPortfolio = result.getOrElse(
        (_) => throw StateError('createPortfolio returned no portfolio.'),
      );
      _pendingPortfolios[createdPortfolio.id] = (
        portfolio: createdPortfolio,
        createdAt: DateTime.now(),
      );

      final cleaned = _removeById(
        state.value ?? const [],
        optimisticId,
      );
      final merged = _mergeWithPending(cleaned);
      await _commitPortfolios(
        _upsertPortfolio(merged, createdPortfolio),
        syncListProvider: true,
      );
      _setSelectedPortfolio(createdPortfolio.id);

      // Background revalidation deferred until server confirms
      _revalidateUntilVisible(createdPortfolio.id);

      return Right(createdPortfolio);
    } catch (_) {
      _pendingPortfolios.remove(optimisticId);
      final cleaned = _removeById(
        state.value ?? const [],
        optimisticId,
      );
      await _commitPortfolios(_mergeWithPending(cleaned));
      return const Left(
        AppFailure(message: 'خطای پیش‌بینی‌نشده در ایجاد پرتفوی.'),
      );
    } finally {
      _creatingNameKeys.remove(nameKey);
    }
  }

  Future<PortfolioBatchCreateResult> addPortfolios(
      Iterable<String> names) async {
    final uniqueNames = <String>[];
    final seen = <String>{};
    for (final rawName in names) {
      final name = rawName.trim();
      final key = _portfolioNameKey(name);
      if (name.isEmpty || !seen.add(key)) {
        continue;
      }
      uniqueNames.add(name);
    }

    final created = <PortfolioCardDto>[];
    final failures = <PortfolioCreateFailure>[];
    for (final name in uniqueNames) {
      final result = await addPortfolio(name);
      result.fold(
        (failure) => failures.add(
          PortfolioCreateFailure(name: name, failure: failure),
        ),
        created.add,
      );
    }

    return PortfolioBatchCreateResult(
      created: List<PortfolioCardDto>.unmodifiable(created),
      failures: List<PortfolioCreateFailure>.unmodifiable(failures),
    );
  }

  Future<Either<AppFailure, Unit>> deletePortfolio(String portfolioId) async {
    final normalizedId = portfolioId.trim();
    if (normalizedId.isEmpty) {
      return const Left(AppFailure(message: 'شناسه پرتفو معتبر نیست.'));
    }

    final result = await _repository.deletePortfolio(portfolioId: normalizedId);
    if (result.isLeft()) {
      return result;
    }

    _pendingPortfolios.remove(normalizedId);
    final next = _removeById(
      state.value ?? const <PortfolioCardDto>[],
      normalizedId,
    );
    await _commitPortfolios(next, syncListProvider: false);
    await ref
        .read(portfolioListProvider.notifier)
        .removePortfolio(normalizedId);
    _ensureSelectedPortfolio(next);
    return const Right(unit);
  }

  Future<void> refreshPortfolios() async {
    final previous = state;
    final previousItems = previous.value ?? const <PortfolioCardDto>[];
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAndMerge(seed: previousItems));
    final portfolios = state.value;
    if (portfolios != null) {
      _ensureSelectedPortfolio(portfolios);
      _syncListProvider(portfolios);
      unawaited(_persistCachedPortfolios(portfolios));
    }
  }

  Future<List<PortfolioCardDto>> _fetchAndMerge({
    List<PortfolioCardDto> seed = const <PortfolioCardDto>[],
  }) async {
    final requestEpoch = ++_fetchEpoch;
    final result = await _repository.fetchPortfolios();
    final localFallback = _localFallbackPortfolios(seed);
    final remote = result.fold((failure) {
      if (localFallback.isNotEmpty) {
        return localFallback;
      }
      throw failure;
    }, (data) => data);

    // Prevent out-of-order responses from overriding newer state.
    if (requestEpoch != _fetchEpoch) {
      return state.value ?? localFallback;
    }

    _removeConfirmedPending(remote);
    final merged = _mergePortfolioCards(
      preferred: remote,
      fallback: localFallback,
    );
    return _mergeWithPending(merged);
  }

  List<PortfolioCardDto> _mergeWithPending(List<PortfolioCardDto> remote) {
    final byId = <String, PortfolioCardDto>{
      for (final item in remote) item.id: item,
    };

    // Overlay pending portfolios
    for (final record in _pendingPortfolios.values) {
      final id = record.portfolio.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId.putIfAbsent(id, () => record.portfolio);
    }

    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return merged;
  }

  List<PortfolioCardDto> _mergePortfolioCards({
    required Iterable<PortfolioCardDto> preferred,
    required Iterable<PortfolioCardDto> fallback,
  }) {
    final byId = <String, PortfolioCardDto>{};
    for (final item in fallback) {
      final id = item.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = item;
    }
    for (final item in preferred) {
      final id = item.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = item;
    }

    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  List<PortfolioCardDto> _localFallbackPortfolios(List<PortfolioCardDto> seed) {
    final listFallback = ref
            .read(portfolioListProvider)
            .value
            ?.map(_toPortfolioCardFromList)
            .toList(growable: false) ??
        const <PortfolioCardDto>[];
    final current = state.value ?? const <PortfolioCardDto>[];
    final seeded = _mergePortfolioCards(
      preferred: seed,
      fallback: listFallback,
    );
    final merged = _mergePortfolioCards(
      preferred: current,
      fallback: seeded,
    );
    return _mergeWithPending(merged);
  }

  void _removeConfirmedPending(List<PortfolioCardDto> latestRemote) {
    final remoteIds = latestRemote.map((p) => p.id.trim()).toSet();
    final now = DateTime.now();

    _pendingPortfolios.removeWhere((id, record) {
      // Remove if confirmed by server OR older than 30 seconds
      return remoteIds.contains(id) ||
          now.difference(record.createdAt).inSeconds > 30;
    });
  }

  List<PortfolioCardDto> _upsertPortfolio(
    List<PortfolioCardDto> items,
    PortfolioCardDto created,
  ) {
    final createdId = created.id.trim();
    final withoutExisting = items.where(
      (item) => item.id.trim() != createdId,
    );
    final next = <PortfolioCardDto>[
      ...withoutExisting,
      created,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return next;
  }

  List<PortfolioCardDto> _removeById(
    List<PortfolioCardDto> items,
    String portfolioId,
  ) {
    final normalizedId = portfolioId.trim();
    return items
        .where((item) => item.id.trim() != normalizedId)
        .toList(growable: false);
  }

  Future<void> _revalidateUntilVisible(String createdId) async {
    const retries = <Duration>[
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];

    for (final delay in retries) {
      await Future<void>.delayed(delay);
      final fetchResult = await _repository.fetchPortfolios();
      final remote = fetchResult.fold<List<PortfolioCardDto>?>(
          (_) => null, (data) => data);
      if (remote == null) {
        continue;
      }
      if (remote.any((item) => item.id == createdId)) {
        _pendingPortfolios.remove(createdId);
        // Merge with current local state to avoid dropping portfolios that may
        // be missing from this specific revalidation snapshot.
        final current = state.value ?? const <PortfolioCardDto>[];
        final mergedRemote = _mergePortfolioCards(
          preferred: remote,
          fallback: current,
        );
        final merged = _mergeWithPending(mergedRemote);
        await _commitPortfolios(merged, syncListProvider: true);
        _ensureSelectedPortfolio(merged);

        return;
      }
    }
  }

  Future<void> _commitPortfolios(
    List<PortfolioCardDto> portfolios, {
    bool syncListProvider = true,
  }) async {
    state = AsyncValue.data(portfolios);
    if (syncListProvider) {
      await _syncListProvider(portfolios);
    }
    await _persistCachedPortfolios(portfolios);
  }

  Future<void> _syncListProvider(Iterable<PortfolioCardDto> portfolios) async {
    try {
      final listNotifier = ref.read(portfolioListProvider.notifier);
      await listNotifier.mergePortfolios(
        portfolios.map(_toPortfolioListItem),
      );
    } catch (_) {}
  }

  void _setSelectedPortfolio(String? portfolioId) {
    final normalized = portfolioId?.trim();
    final nextValue =
        (normalized == null || normalized.isEmpty) ? null : normalized;
    Future<void>(() async {
      ref.read(selectedPortfolioIdProvider.notifier).state = nextValue;
    });
  }

  void _ensureSelectedPortfolio(List<PortfolioCardDto> portfolios) {
    if (portfolios.isEmpty) {
      _setSelectedPortfolio(null);
      return;
    }

    final current = ref.read(selectedPortfolioIdProvider);
    final hasCurrent =
        current != null && portfolios.any((item) => item.id == current);
    if (hasCurrent) {
      return;
    }

    final preferred =
        portfolios.where((item) => item.isDefault).toList(growable: false);
    _setSelectedPortfolio(
        preferred.isNotEmpty ? preferred.first.id : portfolios.first.id);
  }

  PortfolioListItem _toPortfolioListItem(PortfolioCardDto item) {
    return PortfolioListItem(
      id: item.id,
      name: item.name,
      baseCurrency: 'IRR',
      totalCurrentValue: item.totalValue,
      totalInvestedCapital: 0,
      totalUnrealizedPnl: 0,
      dailyPnl: 0,
      roiPercent: item.roiPercent,
    );
  }

  PortfolioCardDto _toPortfolioCardFromList(PortfolioListItem item) {
    return PortfolioCardDto(
      id: item.id,
      name: item.name,
      totalValue: item.totalCurrentValue,
      roiPercent: item.roiPercent,
      riskStdDeviation: 0,
      sparklineValues: const <double>[],
      isDefault: false,
    );
  }

  Future<void> _restoreSelectedPortfolio() async {
    if (_didRestoreSelection) {
      return;
    }
    _didRestoreSelection = true;

    final prefs = await SharedPreferences.getInstance();
    final restored = prefs.getString(_selectedPortfolioPrefsKey)?.trim();
    if (restored == null || restored.isEmpty) {
      return;
    }
    Future<void>(() async {
      ref.read(selectedPortfolioIdProvider.notifier).state = restored;
    });
  }

  Future<void> _persistSelectedPortfolio(String? portfolioId) async {
    final prefs = await SharedPreferences.getInstance();
    if (portfolioId == null || portfolioId.isEmpty) {
      await prefs.remove(_selectedPortfolioPrefsKey);
      return;
    }
    await prefs.setString(_selectedPortfolioPrefsKey, portfolioId);
  }

  Future<List<PortfolioCardDto>> _restoreCachedPortfolios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_portfolioCacheKey);
      final restored = _decodePortfolioCache(raw);
      if (restored.isNotEmpty) {
        return restored;
      }

      final legacyRaw = prefs.getString(_legacyPortfolioListCacheKey);
      final legacyRestored = _decodeLegacyPortfolioListCache(legacyRaw);
      if (legacyRestored.isNotEmpty) {
        unawaited(_persistCachedPortfolios(legacyRestored));
      }
      return legacyRestored;
    } catch (_) {
      return const <PortfolioCardDto>[];
    }
  }

  List<PortfolioCardDto> _decodePortfolioCache(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <PortfolioCardDto>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PortfolioCardDto>[];
      }
      final restored = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_portfolioFromCache)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
      return _mergePortfolioCards(
        preferred: restored,
        fallback: const <PortfolioCardDto>[],
      );
    } catch (_) {
      return const <PortfolioCardDto>[];
    }
  }

  List<PortfolioCardDto> _decodeLegacyPortfolioListCache(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <PortfolioCardDto>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PortfolioCardDto>[];
      }
      final restored = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(PortfolioListItem.fromJson)
          .where((item) => item.id.trim().isNotEmpty)
          .map(_toPortfolioCardFromList)
          .toList(growable: false);
      return _mergePortfolioCards(
        preferred: restored,
        fallback: const <PortfolioCardDto>[],
      );
    } catch (_) {
      return const <PortfolioCardDto>[];
    }
  }

  Future<void> _persistCachedPortfolios(
      List<PortfolioCardDto> portfolios) async {
    try {
      final items = portfolios
          .where((item) =>
              item.id.trim().isNotEmpty && !item.id.startsWith('tmp-'))
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'name': item.name,
              'total_value': item.totalValue,
              'roi_percent': item.roiPercent,
              'risk_std_deviation': item.riskStdDeviation,
              'sparkline_values': item.sparklineValues,
              'is_default': item.isDefault,
            },
          )
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_portfolioCacheKey, jsonEncode(items));
    } catch (_) {
      // Cache write failures are non-fatal.
    }
  }

  PortfolioCardDto _portfolioFromCache(Map<String, dynamic> json) {
    return PortfolioCardDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'پرتفوی بدون نام').toString(),
      totalValue: _asDouble(json['total_value']),
      roiPercent: _asDouble(json['roi_percent']),
      riskStdDeviation: _asDouble(json['risk_std_deviation']),
      sparklineValues: _asDoubleList(json['sparkline_values']),
      isDefault: json['is_default'] == true,
    );
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

  List<double> _asDoubleList(Object? value) {
    if (value is! List) {
      return const <double>[];
    }
    return value.map(_asDouble).toList(growable: false);
  }

  String _portfolioNameKey(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _bindSelectionPersistence() {
    if (_didBindSelectionPersistence) {
      return;
    }
    _didBindSelectionPersistence = true;
    ref.listen<String?>(
      selectedPortfolioIdProvider,
      (_, next) => unawaited(_persistSelectedPortfolio(next)),
      fireImmediately: false,
    );
  }
}

@riverpod
List<PortfolioOptionDto> portfolioOptions(Ref ref) {
  final managerItems = ref.watch(
    portfolioManagerControllerProvider.select(
      (state) => state.value ?? const <PortfolioCardDto>[],
    ),
  );
  final listItems = ref.watch(
    portfolioListProvider.select(
      (state) => state.value ?? const <PortfolioListItem>[],
    ),
  );

  final byId = <String, PortfolioOptionDto>{};
  for (final item in listItems) {
    if (!_isUuid(item.id)) {
      continue;
    }
    byId[item.id] = PortfolioOptionDto(
      id: item.id,
      title: item.name,
    );
  }
  for (final item in managerItems) {
    if (!_isUuid(item.id)) {
      continue;
    }
    byId[item.id] = PortfolioOptionDto(
      id: item.id,
      title: item.name,
    );
  }

  final merged = byId.values.toList(growable: false)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return merged;
}

bool _isUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}
