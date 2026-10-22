import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

@immutable
class CustomThemeExtension extends ThemeExtension<CustomThemeExtension> {
  const CustomThemeExtension({
    required this.primarySemantic,
    required this.benchmarkSemantic,
    required this.successSemantic,
    required this.dangerSemantic,
    required this.warningSemantic,
    required this.chartGrid,
    required this.chartAxis,
    required this.cardBackground,
    required this.cardStroke,
    required this.cardShadow,
    required this.segmentedBackground,
    required this.segmentedPill,
    required this.headerTitleStyle,
    required this.headerSubtitleStyle,
    required this.sectionTitleStyle,
    required this.kpiLabelStyle,
    required this.kpiValueStyle,
    required this.bodyStyle,
    required this.captionStyle,
  });

  final Color primarySemantic;
  final Color benchmarkSemantic;
  final Color successSemantic;
  final Color dangerSemantic;
  final Color warningSemantic;
  final Color chartGrid;
  final Color chartAxis;
  final Color cardBackground;
  final Color cardStroke;
  final Color cardShadow;
  final Color segmentedBackground;
  final Color segmentedPill;

  final TextStyle headerTitleStyle;
  final TextStyle headerSubtitleStyle;
  final TextStyle sectionTitleStyle;
  final TextStyle kpiLabelStyle;
  final TextStyle kpiValueStyle;
  final TextStyle bodyStyle;
  final TextStyle captionStyle;

  static final CustomThemeExtension light = CustomThemeExtension(
    primarySemantic: AppColors.lightColorScheme.primary,
    benchmarkSemantic: AppColors.lightFintechColors.chartAxisLabel,
    successSemantic: AppColors.lightFintechColors.pnlSuccess,
    dangerSemantic: AppColors.lightFintechColors.pnlDanger,
    warningSemantic: AppColors.lightFintechColors.pnlWarning,
    chartGrid: AppColors.lightFintechColors.chartGridLine,
    chartAxis: AppColors.lightFintechColors.chartAxisLabel,
    cardBackground: AppColors.lightSurface,
    cardStroke: AppColors.lightColorScheme.outlineVariant,
    cardShadow: const Color(0x1A0F172A),
    segmentedBackground: AppColors.lightNavigationSurface,
    segmentedPill: AppColors.lightColorScheme.primaryContainer,
    headerTitleStyle: AppTypography.lightTextTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.lightPrimaryText,
    ),
    headerSubtitleStyle: AppTypography.lightTextTheme.bodyMedium!.copyWith(
      color: AppColors.lightSecondaryText,
    ),
    sectionTitleStyle: AppTypography.lightTextTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.lightPrimaryText,
    ),
    kpiLabelStyle: AppTypography.lightTextTheme.labelMedium!.copyWith(
      color: AppColors.lightSecondaryText,
    ),
    kpiValueStyle: AppTypography.lightTextTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.lightPrimaryText,
    ),
    bodyStyle: AppTypography.lightTextTheme.bodyMedium!.copyWith(
      color: AppColors.lightSecondaryText,
    ),
    captionStyle: AppTypography.lightTextTheme.labelSmall!.copyWith(
      color: AppColors.lightSecondaryText,
    ),
  );

  static final CustomThemeExtension dark = CustomThemeExtension(
    primarySemantic: AppColors.darkColorScheme.primary,
    benchmarkSemantic: AppColors.darkFintechColors.chartAxisLabel,
    successSemantic: AppColors.darkFintechColors.pnlSuccess,
    dangerSemantic: AppColors.darkFintechColors.pnlDanger,
    warningSemantic: AppColors.darkFintechColors.pnlWarning,
    chartGrid: AppColors.darkFintechColors.chartGridLine,
    chartAxis: AppColors.darkFintechColors.chartAxisLabel,
    cardBackground:
        AppColors.darkColorScheme.surfaceContainer.withValues(alpha: 0.82),
    cardStroke:
        AppColors.darkColorScheme.outlineVariant.withValues(alpha: 0.88),
    cardShadow: AppColors.darkColorScheme.shadow.withValues(alpha: 0.3),
    segmentedBackground: AppColors.darkColorScheme.surfaceContainerHighest,
    segmentedPill: AppColors.darkColorScheme.primaryContainer,
    headerTitleStyle: AppTypography.darkTextTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.w800,
    ),
    headerSubtitleStyle: AppTypography.darkTextTheme.bodyMedium!,
    sectionTitleStyle: AppTypography.darkTextTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
    ),
    kpiLabelStyle: AppTypography.darkTextTheme.labelMedium!,
    kpiValueStyle: AppTypography.darkTextTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
    ),
    bodyStyle: AppTypography.darkTextTheme.bodyMedium!,
    captionStyle: AppTypography.darkTextTheme.labelSmall!,
  );

  @override
  CustomThemeExtension copyWith({
    Color? primarySemantic,
    Color? benchmarkSemantic,
    Color? successSemantic,
    Color? dangerSemantic,
    Color? warningSemantic,
    Color? chartGrid,
    Color? chartAxis,
    Color? cardBackground,
    Color? cardStroke,
    Color? cardShadow,
    Color? segmentedBackground,
    Color? segmentedPill,
    TextStyle? headerTitleStyle,
    TextStyle? headerSubtitleStyle,
    TextStyle? sectionTitleStyle,
    TextStyle? kpiLabelStyle,
    TextStyle? kpiValueStyle,
    TextStyle? bodyStyle,
    TextStyle? captionStyle,
  }) {
    return CustomThemeExtension(
      primarySemantic: primarySemantic ?? this.primarySemantic,
      benchmarkSemantic: benchmarkSemantic ?? this.benchmarkSemantic,
      successSemantic: successSemantic ?? this.successSemantic,
      dangerSemantic: dangerSemantic ?? this.dangerSemantic,
      warningSemantic: warningSemantic ?? this.warningSemantic,
      chartGrid: chartGrid ?? this.chartGrid,
      chartAxis: chartAxis ?? this.chartAxis,
      cardBackground: cardBackground ?? this.cardBackground,
      cardStroke: cardStroke ?? this.cardStroke,
      cardShadow: cardShadow ?? this.cardShadow,
      segmentedBackground: segmentedBackground ?? this.segmentedBackground,
      segmentedPill: segmentedPill ?? this.segmentedPill,
      headerTitleStyle: headerTitleStyle ?? this.headerTitleStyle,
      headerSubtitleStyle: headerSubtitleStyle ?? this.headerSubtitleStyle,
      sectionTitleStyle: sectionTitleStyle ?? this.sectionTitleStyle,
      kpiLabelStyle: kpiLabelStyle ?? this.kpiLabelStyle,
      kpiValueStyle: kpiValueStyle ?? this.kpiValueStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      captionStyle: captionStyle ?? this.captionStyle,
    );
  }

  @override
  CustomThemeExtension lerp(
    covariant ThemeExtension<CustomThemeExtension>? other,
    double t,
  ) {
    if (other is! CustomThemeExtension) {
      return this;
    }

    return CustomThemeExtension(
      primarySemantic: Color.lerp(primarySemantic, other.primarySemantic, t)!,
      benchmarkSemantic:
          Color.lerp(benchmarkSemantic, other.benchmarkSemantic, t)!,
      successSemantic: Color.lerp(successSemantic, other.successSemantic, t)!,
      dangerSemantic: Color.lerp(dangerSemantic, other.dangerSemantic, t)!,
      warningSemantic: Color.lerp(warningSemantic, other.warningSemantic, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartAxis: Color.lerp(chartAxis, other.chartAxis, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardStroke: Color.lerp(cardStroke, other.cardStroke, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      segmentedBackground:
          Color.lerp(segmentedBackground, other.segmentedBackground, t)!,
      segmentedPill: Color.lerp(segmentedPill, other.segmentedPill, t)!,
      headerTitleStyle:
          TextStyle.lerp(headerTitleStyle, other.headerTitleStyle, t)!,
      headerSubtitleStyle:
          TextStyle.lerp(headerSubtitleStyle, other.headerSubtitleStyle, t)!,
      sectionTitleStyle:
          TextStyle.lerp(sectionTitleStyle, other.sectionTitleStyle, t)!,
      kpiLabelStyle: TextStyle.lerp(kpiLabelStyle, other.kpiLabelStyle, t)!,
      kpiValueStyle: TextStyle.lerp(kpiValueStyle, other.kpiValueStyle, t)!,
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t)!,
      captionStyle: TextStyle.lerp(captionStyle, other.captionStyle, t)!,
    );
  }

  static CustomThemeExtension resolve(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CustomThemeExtension>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }
}
