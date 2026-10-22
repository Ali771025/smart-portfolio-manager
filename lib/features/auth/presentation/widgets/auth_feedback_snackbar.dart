import 'package:flutter/material.dart';

class AuthFeedbackSnackbar {
  const AuthFeedbackSnackbar._();

  static void showError(BuildContext context, String message) {
    _show(context: context, message: message, isError: true);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context: context, message: message, isError: false);
  }

  static void _show({
    required BuildContext context,
    required String message,
    required bool isError,
  }) {
    final scheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 3),
          content: _SnackPanel(
            message: message,
            borderColor: isError ? scheme.error : scheme.primary,
            backgroundColor: isError
                ? scheme.error.withValues(alpha: 0.16)
                : scheme.primary.withValues(alpha: 0.16),
          ),
        ),
      );
  }
}

class _SnackPanel extends StatelessWidget {
  const _SnackPanel({
    required this.message,
    required this.borderColor,
    required this.backgroundColor,
  });

  final String message;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.75)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: borderColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
