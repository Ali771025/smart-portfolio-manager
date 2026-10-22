// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'excel_import_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExcelImportController)
final excelImportControllerProvider = ExcelImportControllerProvider._();

final class ExcelImportControllerProvider extends $AsyncNotifierProvider<
    ExcelImportController, ExcelImportFlowState> {
  ExcelImportControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'excelImportControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$excelImportControllerHash();

  @$internal
  @override
  ExcelImportController create() => ExcelImportController();
}

String _$excelImportControllerHash() =>
    r'd959bfc83aabd829512af6111b65d4a3d99180d2';

abstract class _$ExcelImportController
    extends $AsyncNotifier<ExcelImportFlowState> {
  FutureOr<ExcelImportFlowState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<ExcelImportFlowState>, ExcelImportFlowState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ExcelImportFlowState>, ExcelImportFlowState>,
        AsyncValue<ExcelImportFlowState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
