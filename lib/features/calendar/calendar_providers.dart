import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';

typedef MsRange = ({int start, int end});

/// Events visible in the calendar for a time range, honoring the workspace
/// filter and, in the all-workspaces view, each workspace's calendar module
/// toggle.
final calendarEventsProvider =
    StreamProvider.autoDispose.family<List<Event>, MsRange>((ref, range) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  final events = ref
      .watch(eventRepositoryProvider)
      .watchInRange(range.start, range.end, workspaceId: workspaceId);
  if (workspaceId != null) return events;

  final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
  final enabledIds = {
    for (final w in workspaces)
      if (w.enabledModules.contains(ModuleKey.calendar)) w.id,
  };
  return events.map(
    (list) => list.where((e) => enabledIds.contains(e.workspaceId)).toList(),
  );
});

/// Task deadlines shown in the agenda view for a time range (spec §6.2).
final agendaTasksProvider =
    StreamProvider.autoDispose.family<List<Task>, MsRange>((ref, range) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  final tasks = ref
      .watch(taskRepositoryProvider)
      .watchDueInRange(range.start, range.end, workspaceId: workspaceId);
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

/// One event by id (edit screen).
final eventByIdProvider = StreamProvider.autoDispose.family<Event?, String>(
  (ref, id) => ref.watch(eventRepositoryProvider).watchById(id),
);
