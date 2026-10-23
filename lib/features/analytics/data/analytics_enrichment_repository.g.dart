// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_enrichment_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for analytics enrichment repository.

@ProviderFor(analyticsEnrichmentRepository)
final analyticsEnrichmentRepositoryProvider =
    AnalyticsEnrichmentRepositoryProvider._();

/// Riverpod provider for analytics enrichment repository.

final class AnalyticsEnrichmentRepositoryProvider extends $FunctionalProvider<
        AnalyticsEnrichmentRepository,
        AnalyticsEnrichmentRepository,
        AnalyticsEnrichmentRepository>
    with $Provider<AnalyticsEnrichmentRepository> {
  /// Riverpod provider for analytics enrichment repository.
  AnalyticsEnrichmentRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'analyticsEnrichmentRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$analyticsEnrichmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AnalyticsEnrichmentRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsEnrichmentRepository create(Ref ref) {
    return analyticsEnrichmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsEnrichmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AnalyticsEnrichmentRepository>(value),
    );
  }
}

String _$analyticsEnrichmentRepositoryHash() =>
    r'7a4b3eb1550b44d1e7f8f69836be4abecc6d7a71';
