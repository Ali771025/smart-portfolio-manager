import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Displays mixed RTL/LTR content safely in RTL layouts.
///
/// Example output:
/// `پیام فنی: Unknown row: Unsupported Format 0`
/// where the technical fragment remains visually stable.
class BidiMixedText extends StatelessWidget {
  const BidiMixedText({
    required this.rtlPrefix,
    required this.ltrContent,
    super.key,
    this.style,
  });

  final String rtlPrefix;
  final String ltrContent;
  final TextStyle? style;

  static const String _lri = '\u2066';
  static const String _pdi = '\u2069';

  @override
  Widget build(BuildContext context) {
    final safePrefix = intl.Bidi.stripHtmlIfNeeded(rtlPrefix);
    final safeLtrContent = intl.Bidi.stripHtmlIfNeeded(ltrContent);
    final mixed = '$safePrefix $_lri$safeLtrContent$_pdi';

    return Text(
      mixed,
      style: style,
      textDirection: TextDirection.rtl,
    );
  }
}
