import 'package:flutter/material.dart';

@immutable
class InstitutionalChartThemeExtension
    extends ThemeExtension<InstitutionalChartThemeExtension> {
  const InstitutionalChartThemeExtension({
    required this.portfolioLine,
    required this.totalIndexLine,
    required this.equalWeightedLine,
    required this.bankDepositLine,
    required this.fixedIncomeLine,
    required this.crosshairColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
    required this.brushFill,
    required this.brushBorder,
    required this.miniMapTrack,
    required this.mainLineStrokeWidth,
    required this.benchmarkLineStrokeWidth,
    required this.crosshairStrokeWidth,
    required this.brushStrokeWidth,
    required this.miniMapStrokeWidth,
  });

  final Color portfolioLine;
  final Color totalIndexLine;
  final Color equalWeightedLine;
  final Color bankDepositLine;
  final Color fixedIncomeLine;
  final Color crosshairColor;
  final Color tooltipBackground;
  final Color tooltipBorder;
  final Color brushFill;
  final Color brushBorder;
  final Color miniMapTrack;

  final double mainLineStrokeWidth;
  final double benchmarkLineStrokeWidth;
  final double crosshairStrokeWidth;
  final double brushStrokeWidth;
  final double miniMapStrokeWidth;

  static const InstitutionalChartThemeExtension light =
      InstitutionalChartThemeExtension(
        portfolioLine: Color(0xFF005C9A),
        totalIndexLine: Color(0xFF047857),
        equalWeightedLine: Color(0xFF7C2D12),
        bankDepositLine: Color(0xFF334155),
        fixedIncomeLine: Color(0xFF6D28D9),
        crosshairColor: Color(0xB31E293B),
        tooltipBackground: Color(0xF8FFFFFF),
        tooltipBorder: Color(0xFFCBD5E1),
        brushFill: Color(0x332563EB),
        brushBorder: Color(0xFF2563EB),
        miniMapTrack: Color(0xFFE2E8F0),
        mainLineStrokeWidth: 2.8,
        benchmarkLineStrokeWidth: 1.9,
        crosshairStrokeWidth: 1.0,
        brushStrokeWidth: 1.2,
        miniMapStrokeWidth: 1.1,
      );

  static const InstitutionalChartThemeExtension dark =
      InstitutionalChartThemeExtension(
        portfolioLine: Color(0xFF7DD3FC),
        totalIndexLine: Color(0xFF6EE7B7),
        equalWeightedLine: Color(0xFFFDA4AF),
        bankDepositLine: Color(0xFF94A3B8),
        fixedIncomeLine: Color(0xFFC4B5FD),
        crosshairColor: Color(0xCCCBD5E1),
        tooltipBackground: Color(0xF81E293B),
        tooltipBorder: Color(0xFF334155),
        brushFill: Color(0x334F46E5),
        brushBorder: Color(0xFFA5B4FC),
        miniMapTrack: Color(0xFF334155),
        mainLineStrokeWidth: 2.8,
        benchmarkLineStrokeWidth: 1.9,
        crosshairStrokeWidth: 1.0,
        brushStrokeWidth: 1.2,
        miniMapStrokeWidth: 1.1,
      );

  @override
  InstitutionalChartThemeExtension copyWith({
    Color? portfolioLine,
    Color? totalIndexLine,
    Color? equalWeightedLine,
    Color? bankDepositLine,
    Color? fixedIncomeLine,
    Color? crosshairColor,
    Color? tooltipBackground,
    Color? tooltipBorder,
    Color? brushFill,
    Color? brushBorder,
    Color? miniMapTrack,
    double? mainLineStrokeWidth,
    double? benchmarkLineStrokeWidth,
    double? crosshairStrokeWidth,
    double? brushStrokeWidth,
    double? miniMapStrokeWidth,
  }) {
    return InstitutionalChartThemeExtension(
      portfolioLine: portfolioLine ?? this.portfolioLine,
      totalIndexLine: totalIndexLine ?? this.totalIndexLine,
      equalWeightedLine: equalWeightedLine ?? this.equalWeightedLine,
      bankDepositLine: bankDepositLine ?? this.bankDepositLine,
      fixedIncomeLine: fixedIncomeLine ?? this.fixedIncomeLine,
      crosshairColor: crosshairColor ?? this.crosshairColor,
      tooltipBackground: tooltipBackground ?? this.tooltipBackground,
      tooltipBorder: tooltipBorder ?? this.tooltipBorder,
      brushFill: brushFill ?? this.brushFill,
      brushBorder: brushBorder ?? this.brushBorder,
      miniMapTrack: miniMapTrack ?? this.miniMapTrack,
      mainLineStrokeWidth: mainLineStrokeWidth ?? this.mainLineStrokeWidth,
      benchmarkLineStrokeWidth:
          benchmarkLineStrokeWidth ?? this.benchmarkLineStrokeWidth,
      crosshairStrokeWidth: crosshairStrokeWidth ?? this.crosshairStrokeWidth,
      brushStrokeWidth: brushStrokeWidth ?? this.brushStrokeWidth,
      miniMapStrokeWidth: miniMapStrokeWidth ?? this.miniMapStrokeWidth,
    );
  }

  @override
  InstitutionalChartThemeExtension lerp(
    covariant ThemeExtension<InstitutionalChartThemeExtension>? other,
    double t,
  ) {
    if (other is! InstitutionalChartThemeExtension) {
      return this;
    }

    return InstitutionalChartThemeExtension(
      portfolioLine: Color.lerp(portfolioLine, other.portfolioLine, t)!,
      totalIndexLine: Color.lerp(totalIndexLine, other.totalIndexLine, t)!,
      equalWeightedLine:
          Color.lerp(equalWeightedLine, other.equalWeightedLine, t)!,
      bankDepositLine: Color.lerp(bankDepositLine, other.bankDepositLine, t)!,
      fixedIncomeLine: Color.lerp(fixedIncomeLine, other.fixedIncomeLine, t)!,
      crosshairColor: Color.lerp(crosshairColor, other.crosshairColor, t)!,
      tooltipBackground:
          Color.lerp(tooltipBackground, other.tooltipBackground, t)!,
      tooltipBorder: Color.lerp(tooltipBorder, other.tooltipBorder, t)!,
      brushFill: Color.lerp(brushFill, other.brushFill, t)!,
      brushBorder: Color.lerp(brushBorder, other.brushBorder, t)!,
      miniMapTrack: Color.lerp(miniMapTrack, other.miniMapTrack, t)!,
      mainLineStrokeWidth:
          _lerpDouble(mainLineStrokeWidth, other.mainLineStrokeWidth, t),
      benchmarkLineStrokeWidth: _lerpDouble(
        benchmarkLineStrokeWidth,
        other.benchmarkLineStrokeWidth,
        t,
      ),
      crosshairStrokeWidth:
          _lerpDouble(crosshairStrokeWidth, other.crosshairStrokeWidth, t),
      brushStrokeWidth: _lerpDouble(brushStrokeWidth, other.brushStrokeWidth, t),
      miniMapStrokeWidth:
          _lerpDouble(miniMapStrokeWidth, other.miniMapStrokeWidth, t),
    );
  }
}

double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

extension InstitutionalChartThemeContextX on BuildContext {
  InstitutionalChartThemeExtension get institutionalChartTheme {
    final extension = Theme.of(this).extension<InstitutionalChartThemeExtension>();
    return extension ?? InstitutionalChartThemeExtension.light;
  }
}
