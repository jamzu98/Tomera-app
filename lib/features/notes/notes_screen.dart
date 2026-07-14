import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/editorial.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/work_section_switcher.dart';
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
    final moduleDisabled =
        selectedWorkspace != null &&
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
            : null,
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
      body: Column(
        children: [
          EditorialScreenHeader(
            title: l10n.tabWork,
            subtitle: l10n.tabNotes,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          ),
          const WorkSectionSwitcher(selected: WorkSection.notes),
          Expanded(
            child: moduleDisabled
                ? EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: l10n.moduleDisabledTitle,
                    body: l10n.notesModuleDisabled,
                    primaryAction: EmptyStateAction(
                      label: l10n.editWorkspace,
                      icon: Icons.tune_rounded,
                      onPressed: () =>
                          context.push('/workspaces/${selectedWorkspace.id}'),
                    ),
                  )
                : switch (notesValue) {
                    AsyncValue(value: final notes?) when notes.isNotEmpty =>
                      ListView(
                        padding: const EdgeInsets.only(top: 6, bottom: 88),
                        children: [
                          EditorialPanel(
                            children: [
                              for (final note in notes)
                                _NoteTile(
                                  note: note,
                                  workspace: workspaces
                                      .where((w) => w.id == note.workspaceId)
                                      .firstOrNull,
                                ),
                            ],
                          ),
                        ],
                      ),
                    AsyncValue(isLoading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    AsyncValue(hasError: true) => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.unableToLoadTitle,
                      body: l10n.unableToLoadBody,
                      retryLabel: l10n.retry,
                      onRetry: () => searchActive
                          ? ref.invalidate(noteSearchProvider(_query))
                          : ref.invalidate(visibleNotesProvider),
                    ),
                    _ =>
                      searchActive
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: l10n.noSearchResults,
                              secondaryAction: EmptyStateAction(
                                label: l10n.closeSearch,
                                onPressed: _closeSearch,
                              ),
                            )
                          : EmptyState(
                              icon: Icons.notes_rounded,
                              title: l10n.emptyNotesTitle,
                              body: l10n.emptyNotesBody,
                              primaryAction: EmptyStateAction(
                                label: l10n.newNote,
                                icon: Icons.add_rounded,
                                onPressed: () => context.go('/work/notes/new'),
                              ),
                            ),
                  },
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.workspace});

  final Note note;
  final Workspace? workspace;

  @override
  Widget build(BuildContext context) {
    final color = workspace != null
        ? Color(workspace!.color)
        : context.tokens.textTertiary;
    return SoftTile(
      embedded: true,
      margin: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.description_outlined, size: 19, color: color),
      ),
      title: Text(note.title),
      subtitle: note.body.isNotEmpty
          ? Text(note.body, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      onTap: () => context.go('/work/notes/${note.id}'),
    );
  }
}
