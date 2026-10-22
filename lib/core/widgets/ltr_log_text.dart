import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Forces technical logs to render in LTR even inside RTL screens.
class LtrLogText extends StatelessWidget {
  const LtrLogText(
    this.value, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.stripHtml = true,
    this.useUnicodeIsolation = true,
  });

  final String value;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final bool stripHtml;
  final bool useUnicodeIsolation;

  static const String _lri = '\u2066';
  static const String _pdi = '\u2069';

  @override
  Widget build(BuildContext context) {
    String normalized = value;
    if (stripHtml) {
      normalized = intl.Bidi.stripHtmlIfNeeded(normalized);
    }
    if (useUnicodeIsolation) {
      normalized = '$_lri$normalized$_pdi';
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        normalized,
        textDirection: TextDirection.ltr,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}
