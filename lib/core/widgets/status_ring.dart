import 'package:flutter/material.dart';

/// Tappable circular status indicator (open ring / colored ring / filled).
/// Used for task status cycling and billable status.
class StatusRing extends StatelessWidget {
  const StatusRing({
    super.key,
    required this.icon,
    required this.color,
    this.filled = false,
    this.size = 34,
    this.squared = false,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;

  /// Filled rings paint [color] as background with a contrasting glyph.
  final bool filled;
  final double size;

  /// Billable status markers are rounded squares; task rings are circles.
  final bool squared;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final radius = squared ? BorderRadius.circular(size * 0.32) : null;
    final shape = squared ? BoxShape.rectangle : BoxShape.circle;

    final ring = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 2),
      ),
      child: Icon(
        icon,
        size: size * 0.56,
        color: filled ? const Color(0xFFFFFDF8) : color,
      ),
    );

    if (onTap == null) {
      return tooltip == null ? ring : Tooltip(message: tooltip!, child: ring);
    }

    final borderRadius = squared ? BorderRadius.circular(15) : null;
    Widget target = Semantics(
      button: true,
      label: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: squared
              ? RoundedRectangleBorder(borderRadius: borderRadius!)
              : const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Center(child: ring)),
        ),
      ),
    );
    if (tooltip != null) {
      target = Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: target,
      );
    }
    return target;
  }
}
