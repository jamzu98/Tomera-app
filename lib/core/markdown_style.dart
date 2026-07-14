import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'theme.dart';

/// Markdown stylesheet matching the editorial monochrome design system.
MarkdownStyleSheet tomeraMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final tokens = context.tokens;
  final textTheme = theme.textTheme;
  final codeBackground = theme.colorScheme.surfaceContainerHigh;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: textTheme.bodyMedium?.copyWith(height: 1.55),
    h1: textTheme.headlineMedium,
    h2: textTheme.headlineSmall,
    h3: textTheme.titleLarge,
    h4: textTheme.titleMedium,
    h5: textTheme.titleSmall,
    h6: textTheme.labelSmall,
    blockquote: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 4, 0, 4),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: theme.colorScheme.onSurface,
      backgroundColor: codeBackground,
    ),
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(editorialControlRadius),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: tokens.borderStrong)),
    ),
    listBullet: textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
    ),
    a: TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
    ),
    tableBorder: TableBorder.all(color: tokens.borderStrong, width: 1),
    tableHead: textTheme.titleSmall,
  );
}
