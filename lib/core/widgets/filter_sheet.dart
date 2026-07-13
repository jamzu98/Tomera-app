import 'package:flutter/material.dart';

/// Consistent entry point for feature filters. Grouping and view-mode controls
/// intentionally remain outside this button.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.label,
    required this.activeCount,
    required this.onPressed,
  });

  final String label;
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    container: true,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.tune_rounded),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (activeCount > 0) ...[
            const SizedBox(width: 7),
            Badge(label: Text('$activeCount')),
          ],
        ],
      ),
    ),
  );
}

class FilterSheetScaffold extends StatelessWidget {
  const FilterSheetScaffold({
    super.key,
    required this.title,
    required this.clearAllLabel,
    required this.onClearAll,
    required this.child,
  });

  final String title;
  final String clearAllLabel;
  final VoidCallback? onClearAll;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: onClearAll, child: Text(clearAllLabel)),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    ),
  );
}
