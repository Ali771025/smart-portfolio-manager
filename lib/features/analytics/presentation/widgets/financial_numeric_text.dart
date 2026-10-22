import 'package:flutter/material.dart';

const List<FontFeature> kFinancialNumericFontFeatures = <FontFeature>[
  FontFeature.tabularFigures(),
  FontFeature.liningFigures(),
];

class FinancialNumericText extends StatelessWidget {
  const FinancialNumericText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = (style ?? DefaultTextStyle.of(context).style).copyWith(
      color: color,
      fontFeatures: kFinancialNumericFontFeatures,
    );

    return Text(
      text,
      style: resolvedStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class AnimatedFinancialNumericText extends StatefulWidget {
  const AnimatedFinancialNumericText({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.color,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final String Function(double value) formatter;
  final TextStyle? style;
  final Color? color;
  final Duration duration;
  final Curve curve;

  @override
  State<AnimatedFinancialNumericText> createState() =>
      _AnimatedFinancialNumericTextState();
}

class _AnimatedFinancialNumericTextState extends State<AnimatedFinancialNumericText> {
  late double _begin;
  late double _end;

  @override
  void initState() {
    super.initState();
    _begin = widget.value;
    _end = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedFinancialNumericText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _begin = oldWidget.value;
      _end = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _begin, end: _end),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, value, _) {
        return FinancialNumericText(
          widget.formatter(value),
          style: widget.style,
          color: widget.color,
        );
      },
    );
  }
}
