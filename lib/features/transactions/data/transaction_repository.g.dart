// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transactionDio)
final transactionDioProvider = TransactionDioProvider._();

final class TransactionDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  TransactionDioProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'transactionDioProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$transactionDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return transactionDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$transactionDioHash() => r'2e348d2437201c6d1d9b2c68778fd5690c0074d2';

@ProviderFor(transactionRepository)
final transactionRepositoryProvider = TransactionRepositoryProvider._();

final class TransactionRepositoryProvider extends $FunctionalProvider<
    TransactionRepository,
    TransactionRepository,
    TransactionRepository> with $Provider<TransactionRepository> {
  TransactionRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'transactionRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$transactionRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TransactionRepository create(Ref ref) {
    return transactionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionRepository>(value),
    );
  }
}

String _$transactionRepositoryHash() =>
    r'c6c76bafb3b823dd23c95d83b51c3aedd600b2de';
