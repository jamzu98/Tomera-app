import 'package:flutter/material.dart';

import '../money.dart';
import '../theme.dart';

/// Card of label/amount rows with hairline separators; the highlighted row
/// renders larger while remaining within the monochrome hierarchy.
class FinancialSummaryCard extends StatelessWidget {
  const FinancialSummaryCard({
    super.key,
    required this.rows,
    this.currency = 'EUR',
  });

  /// (label, cents, highlighted)
  final List<(String, int, bool)> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(editorialCardRadius),
      ),
      child: Column(
        children: [
          for (final (i, (label, cents, highlighted)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: tokens.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: bodyFontFamily,
                        fontSize: 13.5,
                        fontWeight: highlighted
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: highlighted
                            ? theme.colorScheme.onSurface
                            : tokens.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${formatCents(cents)} $currency',
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: highlighted ? 16 : 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: theme.colorScheme.onSurface,
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
