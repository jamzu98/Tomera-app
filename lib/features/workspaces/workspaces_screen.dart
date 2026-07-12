import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'module_labels.dart';

class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabWorkspaces),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-workspaces',
        tooltip: l10n.newWorkspace,
        onPressed: () => context.push('/workspaces/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: switch (workspaces) {
        AsyncValue(value: final items?) when items.isNotEmpty =>
          _WorkspaceList(items: items),
        AsyncValue(isLoading: true) =>
          const Center(child: CircularProgressIndicator()),
        AsyncValue(:final error?) => Center(child: Text('$error')),
        _ => EmptyState(
            icon: Icons.workspaces_outline,
            title: l10n.emptyWorkspacesTitle,
            body: l10n.emptyWorkspacesBody,
          ),
      },
    );
  }
}

class _WorkspaceList extends ConsumerWidget {
  const _WorkspaceList({required this.items});

  final List<Workspace> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = items.map((w) => w.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        ref.read(workspaceRepositoryProvider).reorder(ids);
      },
      itemBuilder: (context, index) => _WorkspaceCard(
        key: ValueKey(items[index].id),
        workspace: items[index],
        index: index,
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    super.key,
    required this.workspace,
    required this.index,
  });

  final Workspace workspace;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final enabled = [
      for (final m in ModuleKey.values)
        if (workspace.enabledModules.contains(m)) moduleLabel(l10n, m),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/workspaces/${workspace.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                WorkspaceAvatar.fromWorkspace(workspace, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: displayFontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (enabled.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final label in enabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: tokens.line),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: bodyFontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.ink2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child:
                        Icon(Icons.drag_indicator_rounded, color: tokens.ink3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
