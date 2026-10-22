import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class FinancialPaletteExtension extends ThemeExtension<FinancialPaletteExtension> {
  const FinancialPaletteExtension({
    required this.profitColor,
    required this.lossColor,
    required this.neutralDrawdown,
    required this.liveTickUpGlow,
    required this.liveTickDownGlow,
    required this.benchmarkLine,
    required this.portfolioLine,
  });

  final Color profitColor;
  final Color lossColor;
  final Color neutralDrawdown;
  final Color liveTickUpGlow;
  final Color liveTickDownGlow;
  final Color benchmarkLine;
  final Color portfolioLine;

  static const FinancialPaletteExtension light = FinancialPaletteExtension(
    profitColor: AppColors.lightSuccess,
    lossColor: AppColors.lightDanger,
    neutralDrawdown: AppColors.lightSecondaryText,
    liveTickUpGlow: Color(0x3310B981),
    liveTickDownGlow: Color(0x33EF4444),
    benchmarkLine: Color(0xFF0EA5E9),
    portfolioLine: AppColors.lightAccent,
  );

  static const FinancialPaletteExtension dark = FinancialPaletteExtension(
    profitColor: Color(0xFF3DD598),
    lossColor: Color(0xFFFF6B6B),
    neutralDrawdown: Color(0xFF98A2B3),
    liveTickUpGlow: Color(0x4D3DD598),
    liveTickDownGlow: Color(0x4DFF6B6B),
    benchmarkLine: Color(0xFFC4B5FD),
    portfolioLine: Color(0xFF7DD3FC),
  );

  @override
  FinancialPaletteExtension copyWith({
    Color? profitColor,
    Color? lossColor,
    Color? neutralDrawdown,
    Color? liveTickUpGlow,
    Color? liveTickDownGlow,
    Color? benchmarkLine,
    Color? portfolioLine,
  }) {
    return FinancialPaletteExtension(
      profitColor: profitColor ?? this.profitColor,
      lossColor: lossColor ?? this.lossColor,
      neutralDrawdown: neutralDrawdown ?? this.neutralDrawdown,
      liveTickUpGlow: liveTickUpGlow ?? this.liveTickUpGlow,
      liveTickDownGlow: liveTickDownGlow ?? this.liveTickDownGlow,
      benchmarkLine: benchmarkLine ?? this.benchmarkLine,
      portfolioLine: portfolioLine ?? this.portfolioLine,
    );
  }

  @override
  FinancialPaletteExtension lerp(
    covariant ThemeExtension<FinancialPaletteExtension>? other,
    double t,
  ) {
    if (other is! FinancialPaletteExtension) {
      return this;
    }

    return FinancialPaletteExtension(
      profitColor: Color.lerp(profitColor, other.profitColor, t)!,
      lossColor: Color.lerp(lossColor, other.lossColor, t)!,
      neutralDrawdown: Color.lerp(neutralDrawdown, other.neutralDrawdown, t)!,
      liveTickUpGlow: Color.lerp(liveTickUpGlow, other.liveTickUpGlow, t)!,
      liveTickDownGlow: Color.lerp(liveTickDownGlow, other.liveTickDownGlow, t)!,
      benchmarkLine: Color.lerp(benchmarkLine, other.benchmarkLine, t)!,
      portfolioLine: Color.lerp(portfolioLine, other.portfolioLine, t)!,
    );
  }
}

extension FinancialPaletteContextX on BuildContext {
  FinancialPaletteExtension get financialPalette {
    final extension = Theme.of(this).extension<FinancialPaletteExtension>();
    return extension ?? FinancialPaletteExtension.light;
  }
}
