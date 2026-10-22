import 'package:flutter/material.dart';

class GlowActionButton extends StatefulWidget {
  const GlowActionButton({
    required this.child,
    super.key,
    this.onPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<GlowActionButton> createState() => _GlowActionButtonState();
}

class _GlowActionButtonState extends State<GlowActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.95 : 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: _pressed ? 0.12 : 0.25),
                blurRadius: _pressed ? 12 : 20,
              ),
            ],
          ),
          child: IconButton.filledTonal(
            onPressed: widget.onPressed,
            icon: widget.child,
          ),
        ),
      ),
    );
  }
}
