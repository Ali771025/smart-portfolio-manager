import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/reconciliation_repository.dart';
import '../../domain/reconciliation_models.dart';

class ManualReconciliationArgs {
  const ManualReconciliationArgs({
    required this.sell,
    required this.portfolios,
  });

  final ReconciliationSellSelection sell;
  final List<ReconciliationPortfolioRef> portfolios;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualReconciliationArgs &&
          other.sell.transactionId == sell.transactionId;

  @override
  int get hashCode => sell.transactionId.hashCode;
}

class ManualReconciliationState {
  const ManualReconciliationState({
    this.candidates = const <ReconciliationBuyCandidate>[],
    this.allocations = const <String, Decimal>{},
    this.fieldErrors = const <String, String>{},
    this.isLoadingCandidates = true,
    this.isRequestingPreview = false,
    this.isConfirming = false,
    this.isSuccess = false,
    this.notes = '',
    this.errorMessage,
    this.draftReconciliationId,
    this.preview,
  });

  final List<ReconciliationBuyCandidate> candidates;
  final Map<String, Decimal> allocations;
  final Map<String, String> fieldErrors;
  final bool isLoadingCandidates;
  final bool isRequestingPreview;
  final bool isConfirming;
  final bool isSuccess;
  final String notes;
  final String? errorMessage;
  final String? draftReconciliationId;
  final ReconciliationPreview? preview;

  bool get isBusy => isLoadingCandidates || isRequestingPreview || isConfirming;

  Decimal get totalAllocated => allocations.values.fold(
        Decimal.zero,
        (sum, value) => sum + value,
      );

  ManualReconciliationState copyWith({
    List<ReconciliationBuyCandidate>? candidates,
    Map<String, Decimal>? allocations,
    Map<String, String>? fieldErrors,
    bool? isLoadingCandidates,
    bool? isRequestingPreview,
    bool? isConfirming,
    bool? isSuccess,
    String? notes,
    String? errorMessage,
    bool clearError = false,
    String? draftReconciliationId,
    bool clearDraft = false,
    ReconciliationPreview? preview,
    bool clearPreview = false,
  }) {
    return ManualReconciliationState(
      candidates: candidates ?? this.candidates,
      allocations: allocations ?? this.allocations,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      isLoadingCandidates: isLoadingCandidates ?? this.isLoadingCandidates,
      isRequestingPreview: isRequestingPreview ?? this.isRequestingPreview,
      isConfirming: isConfirming ?? this.isConfirming,
      isSuccess: isSuccess ?? this.isSuccess,
      notes: notes ?? this.notes,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      draftReconciliationId: clearDraft
          ? null
          : draftReconciliationId ?? this.draftReconciliationId,
      preview: clearPreview ? null : preview ?? this.preview,
    );
  }
}

class ManualReconciliationController
    extends StateNotifier<ManualReconciliationState> {
  ManualReconciliationController({
    required this.repository,
    required this.args,
  }) : super(const ManualReconciliationState()) {
    unawaited(loadCandidates());
  }

  final ReconciliationRepository repository;
  final ManualReconciliationArgs args;

  Future<void> loadCandidates() async {
    state = state.copyWith(
      isLoadingCandidates: true,
      clearError: true,
    );
    try {
      final candidates = await repository.fetchBuyCandidates(
        sell: args.sell,
        portfolios: args.portfolios,
      );
      state = state.copyWith(
        candidates: candidates,
        isLoadingCandidates: false,
      );
    } on ReconciliationApiException catch (error) {
      state = state.copyWith(
        isLoadingCandidates: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingCandidates: false,
        errorMessage: 'دریافت خریدهای کاندید ناموفق بود.',
      );
    }
  }

  void toggleCandidate(String transactionId, bool selected) {
    if (state.preview != null || state.isBusy) {
      return;
    }
    final next = Map<String, Decimal>.from(state.allocations);
    if (!selected) {
      next.remove(transactionId);
    } else {
      final candidate = state.candidates.firstWhere(
        (item) => item.transactionId == transactionId,
      );
      final remainingSell = args.sell.quantity - state.totalAllocated;
      final initial = candidate.availableQuantity < remainingSell
          ? candidate.availableQuantity
          : remainingSell;
      next[transactionId] =
          initial > Decimal.zero ? initial : candidate.availableQuantity;
    }
    state = state.copyWith(
      allocations: next,
      fieldErrors: const <String, String>{},
      clearError: true,
    );
  }

  void updateQuantity(String transactionId, String rawValue) {
    if (state.preview != null || state.isBusy) {
      return;
    }
    final normalized = rawValue.replaceAll(',', '').trim();
    final value = Decimal.tryParse(normalized) ?? Decimal.zero;
    final next = Map<String, Decimal>.from(state.allocations)
      ..[transactionId] = value;
    final errors = Map<String, String>.from(state.fieldErrors)
      ..remove(transactionId);
    state = state.copyWith(
      allocations: next,
      fieldErrors: errors,
      clearError: true,
    );
  }

  void updateNotes(String value) {
    state = state.copyWith(notes: value, clearError: true);
  }

  Future<void> requestPreview() async {
    final errors = _validateAllocations();
    if (errors.isNotEmpty) {
      state = state.copyWith(
        fieldErrors: errors,
        errorMessage: 'مقادیر تخصیص را اصلاح کنید.',
      );
      return;
    }

    state = state.copyWith(
      isRequestingPreview: true,
      fieldErrors: const <String, String>{},
      clearError: true,
    );
    try {
      final existing = await repository.findActiveSuggestionForSell(
        assetId: args.sell.assetId,
        sellTransactionId: args.sell.transactionId,
      );
      if (existing != null && existing.isNotEmpty) {
        await repository.reject(
          existing,
          notes: 'جایگزینی با تطبیق دستی توسط کاربر',
        );
      }

      final id = await repository.createManual(
        sellTransactionId: args.sell.transactionId,
        allocations: state.allocations,
        notes: state.notes,
      );
      state = state.copyWith(draftReconciliationId: id);
      final preview = await repository.preview(id);
      state = state.copyWith(
        isRequestingPreview: false,
        preview: preview,
      );
    } on ReconciliationApiException catch (error) {
      state = state.copyWith(
        isRequestingPreview: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isRequestingPreview: false,
        errorMessage: 'ایجاد پیش‌نمایش تطبیق ناموفق بود.',
      );
    }
  }

  Future<void> editDraft() async {
    final id = state.draftReconciliationId;
    state = state.copyWith(isRequestingPreview: true, clearError: true);
    try {
      if (id != null && id.isNotEmpty) {
        await repository.reject(id, notes: 'ویرایش پیش‌نویس تطبیق دستی');
      }
      state = state.copyWith(
        isRequestingPreview: false,
        clearDraft: true,
        clearPreview: true,
      );
    } on ReconciliationApiException catch (error) {
      state = state.copyWith(
        isRequestingPreview: false,
        errorMessage: error.message,
      );
    }
  }

  Future<void> confirm() async {
    final id = state.draftReconciliationId;
    if (id == null || id.isEmpty || state.preview == null) {
      state = state.copyWith(errorMessage: 'ابتدا پیش‌نمایش را دریافت کنید.');
      return;
    }
    state = state.copyWith(isConfirming: true, clearError: true);
    try {
      await repository.confirm(id, notes: state.notes);
      state = state.copyWith(
        isConfirming: false,
        isSuccess: true,
      );
    } on ReconciliationApiException catch (error) {
      state = state.copyWith(
        isConfirming: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isConfirming: false,
        errorMessage: 'تایید تطبیق ناموفق بود.',
      );
    }
  }

  Map<String, String> _validateAllocations() {
    final errors = <String, String>{};
    if (state.allocations.isEmpty) {
      errors['form'] = 'حداقل یک خرید مبدا را انتخاب کنید.';
      return errors;
    }
    for (final entry in state.allocations.entries) {
      final candidate = state.candidates.firstWhere(
        (item) => item.transactionId == entry.key,
      );
      if (entry.value <= Decimal.zero) {
        errors[entry.key] = 'مقدار باید بیشتر از صفر باشد.';
      } else if (entry.value > candidate.availableQuantity) {
        errors[entry.key] = 'مقدار از مانده قابل استفاده خرید بیشتر است.';
      }
    }
    if (state.totalAllocated > args.sell.quantity) {
      errors['form'] = 'مجموع تخصیص از مقدار فروش بیشتر است.';
    }
    return errors;
  }
}

final manualReconciliationControllerProvider = StateNotifierProvider.autoDispose
    .family<ManualReconciliationController, ManualReconciliationState,
        ManualReconciliationArgs>((ref, args) {
  return ManualReconciliationController(
    repository: ref.watch(reconciliationRepositoryProvider),
    args: args,
  );
});
