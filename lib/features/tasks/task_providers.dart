import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';

/// Tasks visible under the current workspace filter.
///
/// - A specific workspace selected: its tasks (the screen shows a hint when
///   that workspace has the tasks module disabled).
/// - All workspaces: tasks from every workspace that has the tasks module
///   enabled — disabling a module hides its data but never deletes it.
final visibleTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  final tasks =
      ref.watch(taskRepositoryProvider).watchAll(workspaceId: workspaceId);
  if (workspaceId != null) return tasks;

  final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
  final enabledIds = {
    for (final w in workspaces)
      if (w.enabledModules.contains(ModuleKey.tasks)) w.id,
  };
  return tasks.map(
    (list) => list.where((t) => enabledIds.contains(t.workspaceId)).toList(),
  );
});

/// One task by id (edit screen).
final taskByIdProvider = StreamProvider.autoDispose.family<Task?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchById(id),
);
