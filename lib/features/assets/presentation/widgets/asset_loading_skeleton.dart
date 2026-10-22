import 'package:flutter/material.dart';

class AssetLoadingSkeleton extends StatelessWidget {
  const AssetLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget block(double height) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        block(104),
        const SizedBox(height: 12),
        block(120),
        const SizedBox(height: 12),
        block(260),
        const SizedBox(height: 12),
        block(280),
      ],
    );
  }
}
