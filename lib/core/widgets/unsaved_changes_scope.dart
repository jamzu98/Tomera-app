import 'package:flutter/material.dart';

/// Predictive-back-aware guard for editors with unsaved changes.
///
/// Callers own dirty tracking; this widget only centralizes the confirmation
/// behavior so every editor uses the same safe navigation pattern.
class UnsavedChangesScope extends StatefulWidget {
  const UnsavedChangesScope({
    super.key,
    required this.isDirty,
    required this.dialogTitle,
    required this.dialogBody,
    required this.keepEditingLabel,
    required this.discardLabel,
    required this.child,
  });

  final bool isDirty;
  final String dialogTitle;
  final String dialogBody;
  final String keepEditingLabel;
  final String discardLabel;
  final Widget child;

  @override
  State<UnsavedChangesScope> createState() => _UnsavedChangesScopeState();
}

class _UnsavedChangesScopeState extends State<UnsavedChangesScope> {
  bool _allowPop = false;
  bool _handlingPop = false;

  Future<void> _handlePop(Object? result) async {
    if (_handlingPop) return;
    _handlingPop = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.dialogTitle),
          content: Text(widget.dialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.keepEditingLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.discardLabel),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(result);
      });
    } finally {
      _handlingPop = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _allowPop || !widget.isDirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && widget.isDirty) _handlePop(result);
    },
    child: widget.child,
  );
}
