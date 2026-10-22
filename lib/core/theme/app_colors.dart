import 'package:flutter/material.dart';

/// Custom theme extension for fintech-specific semantic colors
/// that go beyond Material 3's standard ColorScheme.
@immutable
class FintechColors extends ThemeExtension<FintechColors> {
  const FintechColors({
    required this.pnlSuccess,
    required this.pnlDanger,
    required this.pnlWarning,
    required this.chartGridLine,
    required this.chartAxisLabel,
    required this.portfolioAllocation,
    required this.transactionIncome,
    required this.transactionExpense,
  });

  final Color pnlSuccess;
  final Color pnlDanger;
  final Color pnlWarning;
  final Color chartGridLine;
  final Color chartAxisLabel;
  final Color portfolioAllocation;
  final Color transactionIncome;
  final Color transactionExpense;

  @override
  FintechColors copyWith({
    Color? pnlSuccess,
    Color? pnlDanger,
    Color? pnlWarning,
    Color? chartGridLine,
    Color? chartAxisLabel,
    Color? portfolioAllocation,
    Color? transactionIncome,
    Color? transactionExpense,
  }) {
    return FintechColors(
      pnlSuccess: pnlSuccess ?? this.pnlSuccess,
      pnlDanger: pnlDanger ?? this.pnlDanger,
      pnlWarning: pnlWarning ?? this.pnlWarning,
      chartGridLine: chartGridLine ?? this.chartGridLine,
      chartAxisLabel: chartAxisLabel ?? this.chartAxisLabel,
      portfolioAllocation: portfolioAllocation ?? this.portfolioAllocation,
      transactionIncome: transactionIncome ?? this.transactionIncome,
      transactionExpense: transactionExpense ?? this.transactionExpense,
    );
  }

  @override
  FintechColors lerp(ThemeExtension<FintechColors>? other, double t) {
    if (other is! FintechColors) return this;
    return FintechColors(
      pnlSuccess: Color.lerp(pnlSuccess, other.pnlSuccess, t)!,
      pnlDanger: Color.lerp(pnlDanger, other.pnlDanger, t)!,
      pnlWarning: Color.lerp(pnlWarning, other.pnlWarning, t)!,
      chartGridLine: Color.lerp(chartGridLine, other.chartGridLine, t)!,
      chartAxisLabel: Color.lerp(chartAxisLabel, other.chartAxisLabel, t)!,
      portfolioAllocation:
          Color.lerp(portfolioAllocation, other.portfolioAllocation, t)!,
      transactionIncome:
          Color.lerp(transactionIncome, other.transactionIncome, t)!,
      transactionExpense:
          Color.lerp(transactionExpense, other.transactionExpense, t)!,
    );
  }
}

class AppColors {
  AppColors._();

  // Light mode primitives
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFF2F6FC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightNavigationSurface = Color(0xFFFDFEFF);
  static const Color lightPrimaryText = Color(0xFF0F172A);
  static const Color lightSecondaryText = Color(0xFF475569);
  static const Color lightAccent = Color(0xFF2563EB);
  static const Color lightSuccess = Color(0xFF10B981);
  static const Color lightDanger = Color(0xFFEF4444);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightInfo = Color(0xFF0EA5E9);
  static const Color lightBorder = Color(0xFFD9E2EC);

  // Dark mode primitives
  static const Color darkBackground = Color(0xFF081121);
  static const Color darkSurface = Color(0xFF0E1A2B);
  static const Color darkElevatedSurface = Color(0xFF14253D);
  static const Color darkCard = Color(0xFF12223A);
  static const Color darkPrimaryText = Color(0xFFE2EBFB);
  static const Color darkSecondaryText = Color(0xFFAAB8D6);
  static const Color darkAccent = Color(0xFF64FFDA);
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkDanger = Color(0xFFFF6B6B);
  static const Color darkWarning = Color(0xFFFFD166);
  static const Color darkInfo = Color(0xFF38BDF8);
  static const Color darkBorder = Color(0xFF294060);

  // ===========================================================================
  // LIGHT THEME - Financial Dashboard
  // ===========================================================================
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: lightAccent,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: Color(0xFF0EA5E9),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0F2FE),
    onSecondaryContainer: Color(0xFF0C4A6E),
    tertiary: Color(0xFF0284C7),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE0F2FE),
    onTertiaryContainer: Color(0xFF0C4A6E),
    error: lightDanger,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: lightSurface,
    onSurface: lightPrimaryText,
    surfaceContainer: lightCard,
    surfaceContainerHighest: lightElevatedSurface,
    onSurfaceVariant: lightSecondaryText,
    outline: lightBorder,
    outlineVariant: Color(0xFFE2EAF3),
    shadow: Color(0x1F0F172A),
    scrim: Color(0x660F172A),
    inverseSurface: Color(0xFF0F172A),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF93C5FD),
  );

  static const FintechColors lightFintechColors = FintechColors(
    pnlSuccess: lightSuccess,
    pnlDanger: lightDanger,
    pnlWarning: lightWarning,
    chartGridLine: Color(0xFFE4EAF3),
    chartAxisLabel: lightSecondaryText,
    portfolioAllocation: lightAccent,
    transactionIncome: lightSuccess,
    transactionExpense: lightDanger,
  );
 
  // ===========================================================================
  // DARK THEME - Terminal Dark (Trading Dashboard)
  // ===========================================================================
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: darkAccent,
    onPrimary: Color(0xFF05212B),
    primaryContainer: Color(0xFF1B3A54),
    onPrimaryContainer: Color(0xFFBBF7EF),
    secondary: darkInfo,
    onSecondary: Color(0xFF021A2C),
    secondaryContainer: Color(0xFF173858),
    onSecondaryContainer: Color(0xFFB7E6FF),
    tertiary: Color(0xFF9EBCFF),
    onTertiary: Color(0xFF14284A),
    tertiaryContainer: Color(0xFF223B67),
    onTertiaryContainer: Color(0xFFDCE7FF),
    error: darkDanger,
    onError: Color(0xFF33080A),
    errorContainer: Color(0xFF5C1A22),
    onErrorContainer: Color(0xFFFFDADD),
    surface: darkSurface,
    onSurface: darkPrimaryText,
    surfaceContainer: darkCard,
    surfaceContainerHighest: darkElevatedSurface,
    onSurfaceVariant: darkSecondaryText,
    outline: darkBorder,
    outlineVariant: Color(0xFF213756),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6F1FF),
    onInverseSurface: Color(0xFF0A192F),
    inversePrimary: Color(0xFF2563EB),
  );
 
  static const FintechColors darkFintechColors = FintechColors(
    pnlSuccess: darkSuccess,
    pnlDanger: darkDanger,
    pnlWarning: darkWarning,
    chartGridLine: darkBorder,
    chartAxisLabel: darkSecondaryText,
    portfolioAllocation: darkAccent,
    transactionIncome: darkSuccess,
    transactionExpense: darkDanger,
  );

  static const AppSemanticColors lightSemanticColors = AppSemanticColors(
    background: lightBackground,
    surface: lightSurface,
    elevatedSurface: lightElevatedSurface,
    card: lightCard,
    border: lightBorder,
    textPrimary: lightPrimaryText,
    textSecondary: lightSecondaryText,
    primary: lightAccent,
    primaryContainer: Color(0xFFDBEAFE),
    success: lightSuccess,
    successContainer: Color(0xFFD1FAE5),
    danger: lightDanger,
    dangerContainer: Color(0xFFFEE2E2),
    warning: lightWarning,
    info: lightInfo,
  );

  static const AppSemanticColors darkSemanticColors = AppSemanticColors(
    background: darkBackground,
    surface: darkSurface,
    elevatedSurface: darkElevatedSurface,
    card: darkCard,
    border: darkBorder,
    textPrimary: darkPrimaryText,
    textSecondary: darkSecondaryText,
    primary: darkAccent,
    primaryContainer: Color(0xFF1B3A54),
    success: darkSuccess,
    successContainer: Color(0xFF173325),
    danger: darkDanger,
    dangerContainer: Color(0xFF5C1A22),
    warning: darkWarning,
    info: darkInfo,
  );
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primaryContainer,
    required this.success,
    required this.successContainer,
    required this.danger,
    required this.dangerContainer,
    required this.warning,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primaryContainer;
  final Color success;
  final Color successContainer;
  final Color danger;
  final Color dangerContainer;
  final Color warning;
  final Color info;

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? primaryContainer,
    Color? success,
    Color? successContainer,
    Color? danger,
    Color? dangerContainer,
    Color? warning,
    Color? info,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Extension to easily access FintechColors from BuildContext.
extension FintechColorsExtension on BuildContext {
  FintechColors get fintechColors =>
      Theme.of(this).extension<FintechColors>() ?? AppColors.lightFintechColors;
}

extension AppSemanticColorsExtension on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      AppColors.lightSemanticColors;
}
