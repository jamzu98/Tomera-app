import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';

/// Notes visible under the current workspace filter.
///
/// In the all-workspaces view, standalone notes (no workspace) are always
/// shown, and workspace notes only when that workspace has the notes module
/// enabled — disabling a module hides its data but never deletes it.
final visibleNotesProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  final notes =
      ref.watch(noteRepositoryProvider).watchAll(workspaceId: workspaceId);
  if (workspaceId != null) return notes;

  final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
  final enabledIds = {
    for (final w in workspaces)
      if (w.enabledModules.contains(ModuleKey.notes)) w.id,
  };
  return notes.map(
    (list) => list
        .where((n) =>
            n.workspaceId == null || enabledIds.contains(n.workspaceId))
        .toList(),
  );
});

/// FTS search results (spec §6.4), honoring the same visibility rules as
/// [visibleNotesProvider]: workspace filter, standalone notes, and the
/// notes module toggle in the all-workspaces view.
final noteSearchProvider =
    StreamProvider.autoDispose.family<List<Note>, String>((ref, query) {
  final results = ref.watch(noteRepositoryProvider).search(query);
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  if (workspaceId != null) {
    return results.map(
        (list) => list.where((n) => n.workspaceId == workspaceId).toList());
  }
  final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
  final enabledIds = {
    for (final w in workspaces)
      if (w.enabledModules.contains(ModuleKey.notes)) w.id,
  };
  return results.map(
    (list) => list
        .where((n) =>
            n.workspaceId == null || enabledIds.contains(n.workspaceId))
        .toList(),
  );
});

/// One note by id (edit screen).
final noteByIdProvider = StreamProvider.autoDispose.family<Note?, String>(
  (ref, id) => ref.watch(noteRepositoryProvider).watchById(id),
);
