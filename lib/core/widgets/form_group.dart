import 'package:flutter/material.dart';

import '../theme.dart';

/// Grouped form card with editorial spacing and quiet row separators.
class FormGroupCard extends StatelessWidget {
  const FormGroupCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(editorialCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(color: tokens.borderSubtle, height: 1),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// A single form row: leading glyph, small field label, and the
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, size: 21, color: tokens.textTertiary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                      color: tokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                child,
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
      fontWeight: FontWeight.w400,
      color: tokens.textTertiary,
    ),
  );
}

/// Text style for values/inputs inside form rows.
TextStyle inlineFieldStyle(BuildContext context) => TextStyle(
  fontFamily: bodyFontFamily,
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Pinned bottom bar with the primary save action.
class SaveBar extends StatefulWidget {
  const SaveBar({super.key, required this.label, this.onPressed});

  final String label;
  final Future<void> Function()? onPressed;

  @override
  State<SaveBar> createState() => _SaveBarState();
}

class _SaveBarState extends State<SaveBar> {
  bool _saving = false;

  Future<void> _save() async {
    final save = widget.onPressed;
    if (save == null || _saving) return;
    setState(() => _saving = true);
    try {
      await save();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(widget.label),
            onPressed: widget.onPressed == null || _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}
