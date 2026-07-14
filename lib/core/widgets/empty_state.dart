import 'package:flutter/material.dart';

import '../theme.dart';

/// An action displayed by [EmptyState].
@immutable
class EmptyStateAction {
  const EmptyStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// Calm centered empty state with optional recovery and creation actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.onRetry,
    this.retryLabel,
  }) : assert(onRetry == null || retryLabel != null);

  final String title;
  final String? body;
  final IconData? icon;
  final EmptyStateAction? primaryAction;
  final EmptyStateAction? secondaryAction;

  /// A lightweight recovery affordance for provider or network failures.
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 30, color: tokens.textTertiary),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
            if (primaryAction != null ||
                secondaryAction != null ||
                onRetry != null) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (primaryAction case final action?)
                    _ActionButton(action: action, primary: true),
                  if (secondaryAction case final action?)
                    _ActionButton(action: action, primary: false),
                  if (onRetry != null)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(retryLabel!),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.primary});

  final EmptyStateAction action;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final icon = action.icon;
    return SizedBox(
      height: 48,
      child: primary
          ? icon == null
                ? FilledButton(
                    onPressed: action.onPressed,
                    child: Text(action.label),
                  )
                : FilledButton.icon(
                    onPressed: action.onPressed,
                    icon: Icon(icon),
                    label: Text(action.label),
                  )
          : icon == null
          ? OutlinedButton(
              onPressed: action.onPressed,
              child: Text(action.label),
            )
          : OutlinedButton.icon(
              onPressed: action.onPressed,
              icon: Icon(icon),
              label: Text(action.label),
            ),
    );
  }
}
