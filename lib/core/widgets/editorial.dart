import 'package:flutter/material.dart';

import '../theme.dart';

/// Large, editorial heading used at the top of primary destinations.
class EditorialScreenHeader extends StatelessWidget {
  const EditorialScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 18),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.tokens.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

/// A raised, high-priority card. Ordinary list surfaces should use
/// [EditorialPanel] or [SoftTile] rather than this shadowed treatment.
class EditorialFeaturedCard extends StatelessWidget {
  const EditorialFeaturedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(editorialFeaturedRadius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? context.tokens.featuredSurface,
          borderRadius: radius,
          boxShadow: editorialShadow(context),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A continuous surface for related list rows, separated by quiet hairlines.
class EditorialPanel extends StatelessWidget {
  const EditorialPanel({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(editorialCardRadius),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Divider(
                    indent: 16,
                    endIndent: 16,
                    color: context.tokens.borderSubtle,
                  ),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular toolbar affordance used for filters and compact overflow actions.
class EditorialCircularAction extends StatelessWidget {
  const EditorialCircularAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        backgroundColor: filled ? scheme.primary : scheme.surfaceContainerHigh,
        foregroundColor: filled ? scheme.onPrimary : scheme.onSurface,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 21),
    );
  }
}

/// Soft rail used behind pill-shaped segmented controls.
class EditorialPillRail extends StatelessWidget {
  const EditorialPillRail({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: Colors.transparent,
        shape: StadiumBorder(),
      ),
      child: child,
    );
  }
}
