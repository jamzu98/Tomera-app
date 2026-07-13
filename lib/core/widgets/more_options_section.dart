import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// A consistent, compact disclosure for optional form fields.
///
/// Editors should keep their primary identity, schedule/value, and context
/// controls outside this section. Pass [initiallyExpanded] when any optional
/// value was prefilled so existing data is never hidden from the user.
class MoreOptionsSection extends StatefulWidget {
  const MoreOptionsSection({
    super.key,
    required this.children,
    this.initiallyExpanded = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry padding;

  @override
  State<MoreOptionsSection> createState() => _MoreOptionsSectionState();
}

class _MoreOptionsSectionState extends State<MoreOptionsSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(MoreOptionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: widget.padding,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Semantics(
                button: true,
                expanded: _expanded,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 21, color: tokens.ink3),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            l10n.moreOptions,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: tokens.ink3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(color: tokens.hairline, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, child) in widget.children.indexed) ...[
                      if (index > 0) Divider(color: tokens.hairline, height: 1),
                      child,
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
