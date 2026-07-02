import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'module_labels.dart';
import 'workspace_style.dart';

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
        tooltip: l10n.newWorkspace,
        onPressed: () => context.push('/workspaces/new'),
        child: const Icon(Icons.add),
      ),
      body: switch (workspaces) {
        AsyncValue(value: final items?) when items.isNotEmpty =>
          _WorkspaceList(items: items),
        AsyncValue(isLoading: true) =>
          const Center(child: CircularProgressIndicator()),
        AsyncValue(:final error?) => Center(child: Text('$error')),
        _ => _EmptyState(l10n: l10n),
      },
    );
  }
}

class _WorkspaceList extends ConsumerWidget {
  const _WorkspaceList({required this.items});

  final List<Workspace> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = items.map((w) => w.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        ref.read(workspaceRepositoryProvider).reorder(ids);
      },
      itemBuilder: (context, index) {
        final workspace = items[index];
        final enabled = [
          for (final m in ModuleKey.values)
            if (workspace.enabledModules.contains(m)) moduleLabel(l10n, m),
        ];
        return ListTile(
          key: ValueKey(workspace.id),
          leading: CircleAvatar(
            backgroundColor: Color(workspace.color),
            child: Icon(workspaceIcon(workspace.icon), color: Colors.white),
          ),
          title: Text(workspace.name),
          subtitle: Text(enabled.join(' · ')),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          onTap: () => context.push('/workspaces/${workspace.id}'),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(l10n.emptyWorkspacesTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.emptyWorkspacesBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
