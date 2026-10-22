import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'custom_theme_extension.dart';
import 'financial_palette_extension.dart';
import 'institutional_chart_theme_extension.dart';
import 'app_typography.dart';

/// Enterprise-grade theme configuration for fintech application.
/// Implements Material 3 with custom component overrides and fintech extensions.
class AppTheme {
  AppTheme._();

  static TextTheme _buildReadableLightTextTheme() {
    final base = AppTypography.lightTextTheme;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: AppColors.lightPrimaryText),
      displayMedium: base.displayMedium?.copyWith(color: AppColors.lightPrimaryText),
      displaySmall: base.displaySmall?.copyWith(color: AppColors.lightPrimaryText),
      headlineLarge: base.headlineLarge?.copyWith(color: AppColors.lightPrimaryText),
      headlineMedium: base.headlineMedium?.copyWith(color: AppColors.lightPrimaryText),
      headlineSmall: base.headlineSmall?.copyWith(color: AppColors.lightPrimaryText),
      titleLarge: base.titleLarge?.copyWith(color: AppColors.lightPrimaryText),
      titleMedium: base.titleMedium?.copyWith(color: AppColors.lightPrimaryText),
      titleSmall: base.titleSmall?.copyWith(color: AppColors.lightSecondaryText),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.lightPrimaryText),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.lightSecondaryText),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.lightSecondaryText),
      labelLarge: base.labelLarge?.copyWith(color: AppColors.lightPrimaryText),
      labelMedium: base.labelMedium?.copyWith(color: AppColors.lightSecondaryText),
      labelSmall: base.labelSmall?.copyWith(color: AppColors.lightSecondaryText),
    );
  }

  static TextTheme _buildReadableRtlLightTextTheme() {
    final base = AppTypography.rtlLightTextTheme;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: AppColors.lightPrimaryText),
      displayMedium: base.displayMedium?.copyWith(color: AppColors.lightPrimaryText),
      displaySmall: base.displaySmall?.copyWith(color: AppColors.lightPrimaryText),
      headlineLarge: base.headlineLarge?.copyWith(color: AppColors.lightPrimaryText),
      headlineMedium: base.headlineMedium?.copyWith(color: AppColors.lightPrimaryText),
      headlineSmall: base.headlineSmall?.copyWith(color: AppColors.lightPrimaryText),
      titleLarge: base.titleLarge?.copyWith(color: AppColors.lightPrimaryText),
      titleMedium: base.titleMedium?.copyWith(color: AppColors.lightPrimaryText),
      titleSmall: base.titleSmall?.copyWith(color: AppColors.lightSecondaryText),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.lightPrimaryText),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.lightSecondaryText),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.lightSecondaryText),
      labelLarge: base.labelLarge?.copyWith(color: AppColors.lightPrimaryText),
      labelMedium: base.labelMedium?.copyWith(color: AppColors.lightSecondaryText),
      labelSmall: base.labelSmall?.copyWith(color: AppColors.lightSecondaryText),
    );
  }

  // ============================================================================
  // LIGHT THEME - Enterprise Light
  // ============================================================================
  static ThemeData light() {
    final scheme = AppColors.lightColorScheme;
    final semantic = AppColors.lightSemanticColors;
    final textTheme = _buildReadableLightTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['DejaVuSans', 'NotoSansArabic', 'Roboto'],
      extensions: <ThemeExtension<dynamic>>[
        AppColors.lightFintechColors,
        semantic,
        CustomThemeExtension.light,
        FinancialPaletteExtension.light,
        InstitutionalChartThemeExtension.light,
      ],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: semantic.background,
      canvasColor: semantic.background,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      focusColor: scheme.primary.withValues(alpha: 0.16),
      cardTheme: CardThemeData(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
        color: scheme.surfaceContainer,
        shadowColor: const Color(0x140F172A),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.all(0),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.error,
            width: 2,
          ),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.lightSecondaryText,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.lightSecondaryText.withValues(alpha: 0.9),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: scheme.outline,
            width: 1.2,
          ),
          foregroundColor: scheme.primary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor: scheme.primary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightNavigationSurface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: AppColors.lightSecondaryText,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        showUnselectedLabels: false,
        showSelectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 1,
        selectedLabelStyle: textTheme.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightNavigationSurface,
        indicatorColor: scheme.primaryContainer,
        elevation: 1,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall;
          }
          return textTheme.labelSmall?.copyWith(
            color: AppColors.lightSecondaryText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.lightNavigationSurface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(
          color: scheme.primary,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.lightSecondaryText,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: semantic.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: scheme.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dialogTheme: DialogThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
        backgroundColor: scheme.surfaceContainer,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightNavigationSurface,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.outlineVariant,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelSmall!,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurface,
        size: 24,
      ),
      primaryIconTheme: IconThemeData(
        color: scheme.onSurface,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          highlightColor: scheme.primary.withValues(alpha: 0.14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightNavigationSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ============================================================================
  // DARK THEME - Terminal Dark
  // ============================================================================
  static ThemeData dark() {
    final scheme = AppColors.darkColorScheme;
    final semantic = AppColors.darkSemanticColors;
    final textTheme = AppTypography.darkTextTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: 'NotoSansArabic',
      fontFamilyFallback: const ['DejaVuSans', 'NotoSansArabic', 'Roboto'],

      // Inject custom fintech colors extension
      extensions: <ThemeExtension<dynamic>>[
        AppColors.darkFintechColors,
        semantic,
        CustomThemeExtension.dark,
        FinancialPaletteExtension.dark,
        InstitutionalChartThemeExtension.dark,
      ],

      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Scaffold background
      scaffoldBackgroundColor: semantic.background,
      canvasColor: semantic.background,

      // ========================================================================
      // CARD THEME - Subtle border, no elevation
      // ========================================================================
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        color: scheme.surfaceContainer,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.all(0),
        clipBehavior: Clip.antiAlias,
      ),

      // ========================================================================
      // INPUT DECORATION THEME
      // ========================================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.error,
            width: 2,
          ),
        ),
        labelStyle: AppTypography.darkTextTheme.bodyMedium,
        hintStyle: AppTypography.darkTextTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: AppTypography.darkTextTheme.bodySmall?.copyWith(
          color: scheme.error,
        ),
      ),

      // ========================================================================
      // ELEVATED BUTTON THEME
      // ========================================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),

      // ========================================================================
      // OUTLINED BUTTON THEME
      // ========================================================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: scheme.outline,
            width: 1.5,
          ),
          foregroundColor: scheme.primary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),

      // ========================================================================
      // TEXT BUTTON THEME
      // ========================================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundColor: scheme.primary,
          textStyle: AppTypography.button(textTheme),
        ),
      ),

      // ========================================================================
      // BOTTOM NAVIGATION BAR THEME
      // ========================================================================
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        showUnselectedLabels: false,
        showSelectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall,
      ),

      // ========================================================================
      // NAVIGATION BAR THEME (Material 3)
      // ========================================================================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.55),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall;
          }
          return textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          );
        }),
      ),

      // ========================================================================
      // NAVIGATION RAIL THEME
      // ========================================================================
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.55),
        selectedIconTheme: IconThemeData(
          color: scheme.primary,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ========================================================================
      // APP BAR THEME
      // ========================================================================
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: scheme.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // ========================================================================
      // DIALOG THEME
      // ========================================================================
      dialogTheme: DialogThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
        backgroundColor: scheme.surfaceContainer,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // ========================================================================
      // CHIP THEME
      // ========================================================================
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.outlineVariant,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelSmall!,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ========================================================================
      // DIVIDER THEME
      // ========================================================================
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.65),
        thickness: 1,
        space: 1,
      ),

      // ========================================================================
      // ICON THEME
      // ========================================================================
      iconTheme: IconThemeData(
        color: scheme.onSurface,
        size: 24,
      ),

      // ========================================================================
      // FLOATING ACTION BUTTON THEME
      // ========================================================================
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ============================================================================
  // CUSTOM SHADOWS FOR LIGHT THEME CARDS
  // ============================================================================
  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: const Color(0x120F172A),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: const Color(0x080F172A),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // ============================================================================
  // RTL THEME VARIANTS
  // ============================================================================
  static ThemeData lightRTL() {
    final base = light();
    return base.copyWith(
      textTheme: _buildReadableRtlLightTextTheme().apply(
        fontFamily: 'NotoSansArabic',
        fontFamilyFallback: const ['DejaVuSans', 'NotoSansArabic', 'Roboto'],
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColors.lightFintechColors,
        AppColors.lightSemanticColors,
        CustomThemeExtension.light,
        FinancialPaletteExtension.light,
        InstitutionalChartThemeExtension.light,
      ],
    );
  }

  static ThemeData darkRTL() {
    final base = dark();
    return base.copyWith(
      textTheme: AppTypography.rtlDarkTextTheme.apply(
        fontFamily: 'NotoSansArabic',
        fontFamilyFallback: const ['DejaVuSans', 'NotoSansArabic', 'Roboto'],
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColors.darkFintechColors,
        AppColors.darkSemanticColors,
        CustomThemeExtension.dark,
        FinancialPaletteExtension.dark,
        InstitutionalChartThemeExtension.dark,
      ],
    );
  }
}
