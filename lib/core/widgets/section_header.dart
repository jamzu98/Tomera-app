import 'package:flutter/material.dart';

import '../theme.dart';

/// Strong editorial section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 10),
  });

  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: bodyFontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.25,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (onAction != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(
                        actionIcon,
                        size: 17,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (actionLabel != null)
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          fontFamily: bodyFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Group header for task-style lists: colored dot, label, and count.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.title,
    required this.color,
    this.count,
    this.labelColor,
  });

  final String title;
  final Color color;
  final int? count;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
              color: labelColor ?? color,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
