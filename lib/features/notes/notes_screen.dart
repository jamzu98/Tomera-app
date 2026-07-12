import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'note_providers.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() => setState(() {
        _searching = false;
        _query = '';
        _searchController.clear();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchActive = _searching && _query.trim().isNotEmpty;
    final notesValue = searchActive
        ? ref.watch(noteSearchProvider(_query))
        : ref.watch(visibleNotesProvider);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.notes);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : Text(l10n.tabNotes),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.closeSearch,
              onPressed: _closeSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: l10n.searchNotes,
              onPressed: () => setState(() => _searching = true),
            ),
          const Center(child: WorkspaceSwitcherPill(compact: true)),
          const SizedBox(width: 4),
          const AppBarOverflowMenu(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-notes',
        tooltip: l10n.newNote,
        onPressed: () => context.go('/notes/new'),
        child: const Icon(Icons.add_rounded),
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
                  padding: const EdgeInsets.only(top: 6, bottom: 88),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final workspace = workspaces
                        .where((w) => w.id == note.workspaceId)
                        .firstOrNull;
                    final color = workspace != null
                        ? Color(workspace.color)
                        : context.tokens.ink3;
                    return SoftTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_outlined,
                            size: 19, color: color),
                      ),
                      title: Text(note.title),
                      subtitle: note.body.isNotEmpty
                          ? Text(
                              note.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => context.go('/notes/${note.id}'),
                    );
                  },
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => searchActive
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: l10n.noSearchResults,
                    )
                  : EmptyState(
                      icon: Icons.notes_rounded,
                      title: l10n.emptyNotesTitle,
                      body: l10n.emptyNotesBody,
                    ),
            },
          ),
        ],
      ),
    );
  }
}
