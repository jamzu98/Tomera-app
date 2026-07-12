import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../features/workspaces/workspace_style.dart';
import '../../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme.dart';
import 'workspace_avatar.dart';

const _allGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF7C7FF2),
    Color(0xFFE4AB3C),
    Color(0xFF23A896),
    Color(0xFFC169B4),
  ],
  stops: [0.0, 0.45, 0.78, 1.0],
);

/// The app's flagship control: a labeled pill in the app bar showing which
/// workspace the current tab is filtered to. Tapping opens a bottom sheet
/// to switch between "All workspaces" and individual ones.
class WorkspaceSwitcherPill extends ConsumerWidget {
  const WorkspaceSwitcherPill({super.key, this.compact = false});

  /// Compact pills sit next to a screen title; full-size pills replace it.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedId = ref.watch(selectedWorkspaceIdProvider);
    final selected = workspaces.where((w) => w.id == selectedId).firstOrNull;

    final height = compact ? 36.0 : 40.0;
    final dotSize = compact ? 18.0 : 22.0;

    final label = selected?.name ??
        (compact ? l10n.allWorkspacesShort : l10n.allWorkspaces);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: StadiumBorder(side: BorderSide(color: theme.colorScheme.outline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _showSwitcherSheet(context, ref),
        child: Container(
          height: height,
          padding: EdgeInsets.only(left: compact ? 8 : 12, right: compact ? 5 : 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WorkspaceMark(workspace: selected, size: dotSize),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: compact ? 13 : 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: compact ? 18 : 20,
                color: context.tokens.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwitcherSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
          final selectedId = ref.watch(selectedWorkspaceIdProvider);
          void select(String? id) {
            ref.read(selectedWorkspaceIdProvider.notifier).select(id);
            Navigator.of(sheetContext).pop();
          }

          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                _SwitcherRow(
                  mark: const _WorkspaceMark(workspace: null, size: 34),
                  label: l10n.allWorkspaces,
                  selected: selectedId == null,
                  onTap: () => select(null),
                ),
                for (final w in workspaces)
                  _SwitcherRow(
                    mark: _WorkspaceMark(workspace: w, size: 34),
                    label: w.name,
                    selected: selectedId == w.id,
                    onTap: () => select(w.id),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SwitcherRow extends StatelessWidget {
  const _SwitcherRow({
    required this.mark,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget mark;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: mark,
      title: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
    );
  }
}

/// The pill's identity mark: a workspace avatar, or the multicolour gradient
/// tile representing the "all workspaces" view.
class _WorkspaceMark extends StatelessWidget {
  const _WorkspaceMark({required this.workspace, required this.size});

  final Workspace? workspace;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = workspace;
    if (w != null) {
      return WorkspaceAvatar(
        color: Color(w.color),
        icon: workspaceIcon(w.icon),
        size: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _allGradient,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(Icons.grid_view_rounded, size: size * 0.62, color: Colors.white),
    );
  }
}
