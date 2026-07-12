import 'package:flutter/material.dart';

import '../theme.dart';

/// Grouped form card: an uppercase group label above a soft card whose rows
/// are separated by hairlines (the redesign's replacement for flat forms).
class FormGroupCard extends StatelessWidget {
  const FormGroupCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
                child: Text(
                  title!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: tokens.ink3,
                  ),
                ),
              ),
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(color: tokens.hairline, height: 1),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// A single form row: leading glyph, small uppercase field label, and the
/// live input (or value) beneath it, with an optional trailing affordance.
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    required this.icon,
    this.label,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, size: 21, color: tokens.ink3),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                      color: tokens.ink3,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                child,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Borderless input decoration for fields living inside a [FormFieldRow].
InputDecoration inlineFieldDecoration(BuildContext context, {String? hint}) {
  final tokens = Theme.of(context).extension<TomeraTokens>()!;
  return InputDecoration(
    isDense: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    hintText: hint,
    hintStyle: TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: tokens.ink3,
    ),
  );
}

/// Text style for values/inputs inside form rows.
TextStyle inlineFieldStyle(BuildContext context) => TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );

/// Pinned bottom bar with the primary save action.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(label),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                fontFamily: bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              elevation: 4,
            ),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
