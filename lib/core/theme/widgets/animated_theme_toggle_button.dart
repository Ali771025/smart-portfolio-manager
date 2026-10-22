import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../theme_provider.dart';
import '../theme_reveal_provider.dart';

class AnimatedThemeToggleButton extends ConsumerWidget {
  const AnimatedThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final isDark = switch (currentMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final renderObject = context.findRenderObject();
          if (renderObject is RenderBox) {
            ref.read(themeRevealOriginProvider.notifier).state =
                renderObject.localToGlobal(renderObject.size.center(Offset.zero));
          }
          ref.read(themeModeProvider.notifier).toggleTheme();
        },
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 620),
              switchInCurve: Curves.elasticOut,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final rotation = Tween<double>(begin: -0.8, end: 0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                );
                final scale = Tween<double>(begin: 0.25, end: 1).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                );

                return FadeTransition(
                  opacity: animation,
                  child: AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, iconChild) {
                      return Transform.rotate(
                        angle: rotation.value * math.pi,
                        child: Transform.scale(
                          scale: scale.value,
                          child: iconChild,
                        ),
                      );
                    },
                  ),
                );
              },
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                key: ValueKey<bool>(isDark),
                size: 25,
                color: isDark ? Theme.of(context).colorScheme.primary : context.semanticColors.warning,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
