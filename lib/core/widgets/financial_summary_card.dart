import 'package:flutter/material.dart';

import '../money.dart';
import '../theme.dart';

/// Card of label/amount rows with hairline separators; the highlighted row
/// renders larger with the accent color (mock's financial summary).
class FinancialSummaryCard extends StatelessWidget {
  const FinancialSummaryCard({super.key, required this.rows});

  /// (label, cents, highlighted)
  final List<(String, int, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        children: [
          for (final (i, (label, cents, highlighted)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: tokens.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: bodyFontFamily,
                        fontSize: 13.5,
                        fontWeight:
                            highlighted ? FontWeight.w800 : FontWeight.w600,
                        color: highlighted
                            ? theme.colorScheme.onSurface
                            : tokens.ink2,
                      ),
                    ),
                  ),
                  Text(
                    '${formatCents(cents)} EUR',
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: highlighted ? 16 : 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: highlighted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
