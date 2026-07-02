import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers.dart';

/// App bar action that filters list screens to one workspace or all of them.
class WorkspaceFilterButton extends ConsumerWidget {
  const WorkspaceFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedId = ref.watch(selectedWorkspaceIdProvider);
    final selected =
        workspaces.where((w) => w.id == selectedId).firstOrNull;

    return PopupMenuButton<String?>(
      tooltip: l10n.allWorkspaces,
      onSelected: (id) => ref
          .read(selectedWorkspaceIdProvider.notifier)
          .select(id == '' ? null : id),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Text(l10n.allWorkspaces),
        ),
        for (final w in workspaces)
          PopupMenuItem(
            value: w.id,
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: Color(w.color)),
                const SizedBox(width: 8),
                Text(w.name),
              ],
            ),
          ),
      ],
      icon: selected == null
          ? const Icon(Icons.filter_list)
          : Icon(Icons.circle, color: Color(selected.color)),
    );
  }
}
