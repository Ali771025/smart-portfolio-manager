import '../state/import_flow_state.dart';

class DestinationPortfolioValidationResult {
  const DestinationPortfolioValidationResult({
    required this.isValid,
    this.message,
  });

  final bool isValid;
  final String? message;
}

class DestinationPortfolioValidator {
  const DestinationPortfolioValidator();

  DestinationPortfolioValidationResult validateForPreview(ImportFlowState state) {
    if ((state.selectedFileName ?? '').trim().isEmpty) {
      return const DestinationPortfolioValidationResult(
        isValid: false,
        message: 'ابتدا فایل اکسل را انتخاب کنید.',
      );
    }

    if (state.selectionMode == DestinationSelectionMode.createNew &&
        (state.selectedPortfolioId ?? '').trim().isEmpty) {
      return const DestinationPortfolioValidationResult(
        isValid: false,
        message: 'ابتدا پرتفوی جدید را ایجاد کنید، سپس پیش‌نمایش را بزنید.',
      );
    }

    if ((state.selectedPortfolioId ?? '').trim().isEmpty) {
      return const DestinationPortfolioValidationResult(
        isValid: false,
        message: 'لطفاً یک پرتفوی مقصد انتخاب کنید.',
      );
    }

    return const DestinationPortfolioValidationResult(isValid: true);
  }

  DestinationPortfolioValidationResult validateForCreateNew(ImportFlowState state) {
    final rawName = state.newPortfolioName;
    final trimmed = rawName.trim();

    if (trimmed.isEmpty) {
      return const DestinationPortfolioValidationResult(
        isValid: false,
        message: 'برای ایجاد پرتفوی جدید، وارد کردن نام الزامی است.',
      );
    }

    final duplicate = state.portfolios.any((item) => item.name.trim().toLowerCase() == trimmed.toLowerCase());
    if (duplicate) {
      return const DestinationPortfolioValidationResult(
        isValid: false,
        message: 'پرتفوی با این نام قبلاً ثبت شده است.',
      );
    }

    return const DestinationPortfolioValidationResult(isValid: true);
  }
}
