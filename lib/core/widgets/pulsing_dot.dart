import 'package:flutter/material.dart';

/// Small pulsing "recording" dot used by the running-timer surfaces.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, this.size = 9, this.color});

  final double size;
  final Color? color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFFFF6B52);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Mirrors the mock's keyframes: full -> 35% opacity, 1 -> .8 scale.
        final t = Curves.easeInOut.transform(
            _controller.value < 0.5 ? _controller.value * 2 : (1 - _controller.value) * 2);
        return Transform.scale(
          scale: 1 - 0.2 * t,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 1 - 0.65 * t),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
