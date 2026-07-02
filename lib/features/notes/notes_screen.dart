import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'note_providers.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesValue = ref.watch(visibleNotesProvider);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.notes);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabNotes),
        actions: const [WorkspaceFilterButton(), WorkspacesButton()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newNote,
        onPressed: () => context.go('/notes/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (moduleDisabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.notesModuleDisabled,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: switch (notesValue) {
              AsyncValue(value: final notes?) when notes.isNotEmpty =>
                ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final workspace = workspaces
                        .where((w) => w.id == note.workspaceId)
                        .firstOrNull;
                    return ListTile(
                      leading: Icon(
                        Icons.description_outlined,
                        color: workspace != null
                            ? Color(workspace.color)
                            : Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(note.title),
                      subtitle: note.body.isNotEmpty
                          ? Text(
                              note.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => context.go('/notes/${note.id}'),
                    );
                  },
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.emptyNotesTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(l10n.emptyNotesBody),
                    ],
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}
