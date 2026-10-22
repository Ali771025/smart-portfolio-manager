import 'package:flutter/material.dart';

/// Enterprise-grade typography system optimized for fintech applications.
/// Implements Material 3 text styles with tabular figures for numerical data.
class AppTypography {
  AppTypography._();

  // Font families - customize based on your pubspec.yaml
  static const String _primaryFontFamily = 'NotoSansArabic';
  static const String _rtlFontFamily = 'NotoSansArabic';

  /// Tabular + lining figures remove horizontal jitter during live updates.
  static const List<FontFeature> _numericFigureFeatures = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];
 
   // ============================================================================
   // LIGHT THEME TYPOGRAPHY
   // ============================================================================
  static TextTheme lightTextTheme = TextTheme(
     // Display styles - Hero sections, total balance
     displayLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 57,
       fontWeight: FontWeight.w700,
       letterSpacing: -0.25,
       height: 1.12,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures, // Critical for large numbers
     ),
     displayMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 45,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.16,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     displaySmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 36,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.22,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
 
     // Headline styles - Section headers, card titles
     headlineLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 32,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.25,
       color: const Color(0xFF121212),
     ),
     headlineMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 30,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.32,
       color: const Color(0xFF121212),
     ),
     headlineSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 26,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.35,
       color: const Color(0xFF121212),
     ),
 
     // Title styles - List items, dialog headers
     titleLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 22,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.27,
       color: const Color(0xFF121212),
     ),
     titleMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 17,
       fontWeight: FontWeight.w700,
       letterSpacing: 0.15,
       height: 1.46,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures, // For asset names with numbers
     ),
     titleSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.1,
       height: 1.43,
       color: const Color(0xFF424242),
     ),
 
     // Body styles - Paragraphs, descriptions
     bodyLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 16,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.5,
       height: 1.5,
       color: const Color(0xFF121212),
     ),
     bodyMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.25,
       height: 1.43,
       color: const Color(0xFF424242),
     ),
     bodySmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.4,
       height: 1.33,
       color: const Color(0xFF757575),
     ),
 
     // Label styles - Buttons, chips, tickers, prices
     labelLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.1,
       height: 1.43,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures, // Critical for price labels
     ),
     labelMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.5,
       height: 1.33,
       color: const Color(0xFF424242),
       fontFeatures: _numericFigureFeatures, // For ticker symbols
     ),
     labelSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 11,
       fontWeight: FontWeight.w500,
       letterSpacing: 0.5,
       height: 1.45,
       color: const Color(0xFF757575),
       fontFeatures: _numericFigureFeatures, // For small numerical labels
     ),
   );
 
   // ============================================================================
   // DARK THEME TYPOGRAPHY
   // ============================================================================
   static TextTheme darkTextTheme = TextTheme(
     // Display styles - Hero sections, total balance
     displayLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 57,
       fontWeight: FontWeight.w700,
       letterSpacing: -0.25,
       height: 1.12,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     displayMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 45,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.16,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     displaySmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 36,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.22,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
 
     // Headline styles - Section headers, card titles
     headlineLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 32,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.25,
       color: const Color(0xFFE6F1FF),
     ),
     headlineMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 30,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.32,
       color: const Color(0xFFE6F1FF),
     ),
     headlineSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 26,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.35,
       color: const Color(0xFFE6F1FF),
     ),
 
     // Title styles - List items, dialog headers
     titleLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 22,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.27,
       color: const Color(0xFFE6F1FF),
     ),
     titleMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 17,
       fontWeight: FontWeight.w700,
       letterSpacing: 0.15,
       height: 1.46,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     titleSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.1,
       height: 1.43,
       color: const Color(0xFFCCD6F6),
     ),
 
     // Body styles - Paragraphs, descriptions
     bodyLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 16,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.5,
       height: 1.5,
       color: const Color(0xFFE6F1FF),
     ),
     bodyMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.25,
       height: 1.43,
       color: const Color(0xFFCCD6F6),
     ),
     bodySmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w400,
       letterSpacing: 0.4,
       height: 1.33,
       color: const Color(0xFF8892B0),
     ),
 
     // Label styles - Buttons, chips, tickers, prices
     labelLarge: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.1,
       height: 1.43,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     labelMedium: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w600,
       letterSpacing: 0.5,
       height: 1.33,
       color: const Color(0xFFCCD6F6),
       fontFeatures: _numericFigureFeatures,
     ),
     labelSmall: TextStyle(
       fontFamily: _primaryFontFamily,
       fontSize: 11,
       fontWeight: FontWeight.w500,
       letterSpacing: 0.5,
       height: 1.45,
       color: const Color(0xFF8892B0),
       fontFeatures: _numericFigureFeatures,
     ),
   );
 
   // ============================================================================
   // RTL TYPOGRAPHY (Persian/Arabic)
   // ============================================================================
   static TextTheme rtlLightTextTheme = TextTheme(
     displayLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 57,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.12,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     displayMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 45,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.16,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     displaySmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 36,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.22,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     headlineLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 32,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.25,
       color: const Color(0xFF121212),
     ),
     headlineMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 30,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.32,
       color: const Color(0xFF121212),
     ),
     headlineSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 26,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.35,
       color: const Color(0xFF121212),
     ),
     titleLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 22,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.27,
       color: const Color(0xFF121212),
     ),
     titleMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 17,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.46,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     titleSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFF424242),
     ),
     bodyLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 16,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.5,
       color: const Color(0xFF121212),
     ),
     bodyMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFF424242),
     ),
     bodySmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.33,
       color: const Color(0xFF757575),
     ),
     labelLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFF121212),
       fontFeatures: _numericFigureFeatures,
     ),
     labelMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.33,
       color: const Color(0xFF424242),
       fontFeatures: _numericFigureFeatures,
     ),
     labelSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 11,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.45,
       color: const Color(0xFF757575),
       fontFeatures: _numericFigureFeatures,
     ),
   );
 
   static TextTheme rtlDarkTextTheme = TextTheme(
     displayLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 57,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.12,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     displayMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 45,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.16,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     displaySmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 36,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.22,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     headlineLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 32,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.25,
       color: const Color(0xFFE6F1FF),
     ),
     headlineMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 30,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.32,
       color: const Color(0xFFE6F1FF),
     ),
     headlineSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 26,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.35,
       color: const Color(0xFFE6F1FF),
     ),
     titleLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 22,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.27,
       color: const Color(0xFFE6F1FF),
     ),
     titleMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 17,
       fontWeight: FontWeight.w700,
       letterSpacing: 0,
       height: 1.46,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     titleSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFFCCD6F6),
     ),
     bodyLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 16,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.5,
       color: const Color(0xFFE6F1FF),
     ),
     bodyMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFFCCD6F6),
     ),
     bodySmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w400,
       letterSpacing: 0,
       height: 1.33,
       color: const Color(0xFF8892B0),
     ),
     labelLarge: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 14,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.43,
       color: const Color(0xFFE6F1FF),
       fontFeatures: _numericFigureFeatures,
     ),
     labelMedium: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 12,
       fontWeight: FontWeight.w600,
       letterSpacing: 0,
       height: 1.33,
       color: const Color(0xFFCCD6F6),
       fontFeatures: _numericFigureFeatures,
     ),
     labelSmall: TextStyle(
       fontFamily: _rtlFontFamily,
       fontSize: 11,
       fontWeight: FontWeight.w500,
       letterSpacing: 0,
       height: 1.45,
       color: const Color(0xFF8892B0),
       fontFeatures: _numericFigureFeatures,
     ),
   );
  // Typography tokens used across tabs/screens for consistent Persian headings.
  static TextStyle screenTitle(TextTheme textTheme) =>
      (textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w900,
        height: 1.35,
      );

  static TextStyle sectionTitle(TextTheme textTheme) =>
      (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        height: 1.4,
      );

  static TextStyle body(TextTheme textTheme) =>
      textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

  static TextStyle caption(TextTheme textTheme) =>
      textTheme.bodySmall ?? const TextStyle(fontSize: 12);

  static TextStyle button(TextTheme textTheme) =>
      (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
      );
}
