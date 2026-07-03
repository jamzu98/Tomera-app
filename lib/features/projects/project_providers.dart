import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../finance/billable_math.dart';

/// Projects under the current workspace filter. The bool argument includes
/// archived projects (list screen toggle).
final visibleProjectsProvider =
    StreamProvider.autoDispose.family<List<Project>, bool>(
  (ref, includeArchived) => ref.watch(projectRepositoryProvider).watchAll(
        workspaceId: ref.watch(selectedWorkspaceIdProvider),
        includeArchived: includeArchived,
      ),
);

/// All active projects across workspaces (editor dropdowns).
final allProjectsProvider = StreamProvider.autoDispose<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

/// Every project including archived ones (color lookups for old events).
final allProjectsForLookupProvider = StreamProvider.autoDispose<List<Project>>(
  (ref) =>
      ref.watch(projectRepositoryProvider).watchAll(includeArchived: true),
);

final projectByIdProvider = StreamProvider.autoDispose.family<Project?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchById(id),
);

/// Linked entities for the project detail screen.
final eventsForProjectProvider =
    StreamProvider.autoDispose.family<List<Event>, String>(
  (ref, projectId) =>
      ref.watch(eventRepositoryProvider).watchForProject(projectId),
);

final tasksForProjectProvider =
    StreamProvider.autoDispose.family<List<Task>, String>(
  (ref, projectId) =>
      ref.watch(taskRepositoryProvider).watchForProject(projectId),
);

final notesForProjectProvider =
    StreamProvider.autoDispose.family<List<Note>, String>(
  (ref, projectId) => ref
      .watch(noteRepositoryProvider)
      .watchByParent(ParentType.project, projectId),
);

final billablesForProjectProvider =
    StreamProvider.autoDispose.family<List<BillableItem>, String>(
  (ref, projectId) =>
      ref.watch(billableRepositoryProvider).watchAll(projectId: projectId),
);

/// Unbilled/invoiced/paid totals for a project.
final projectTotalsProvider =
    StreamProvider.autoDispose.family<BillableTotals, String>(
  (ref, projectId) =>
      ref.watch(billableRepositoryProvider).watchTotalsForProject(projectId),
);
