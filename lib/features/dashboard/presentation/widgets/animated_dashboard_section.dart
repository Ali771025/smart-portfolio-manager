import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedDashboardSection extends StatelessWidget {
  const AnimatedDashboardSection({
    required this.child,
    required this.delay,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: 420.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, end: 0, duration: 420.ms, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.98, end: 1, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}
