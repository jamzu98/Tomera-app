import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart' show StreamProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/db/database.dart';
import '../data/repositories/billable_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/timer_repository.dart';
import '../data/repositories/workspace_repository.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/notification_service.dart';
import 'notifications/reminder_coordinator.dart';

part 'providers.g.dart';

// NOTE: providers whose *signature* mentions a Drift-generated row class
// (Workspace, Task, ...) are declared manually below. riverpod_generator
// resolves this file before drift_dev's outputs exist in its build phase,
// so such signatures fail codegen with an InvalidTypeException.

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
WorkspaceRepository workspaceRepository(Ref ref) =>
    WorkspaceRepository(ref.watch(appDatabaseProvider).workspaceDao);

@Riverpod(keepAlive: true)
ProjectRepository projectRepository(Ref ref) =>
    ProjectRepository(ref.watch(appDatabaseProvider).projectDao);

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) =>
    TaskRepository(ref.watch(appDatabaseProvider).taskDao);

@Riverpod(keepAlive: true)
BillableRepository billableRepository(Ref ref) =>
    BillableRepository(ref.watch(appDatabaseProvider).billableDao);

@Riverpod(keepAlive: true)
ContactRepository contactRepository(Ref ref) =>
    ContactRepository(ref.watch(appDatabaseProvider).contactDao);

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    EventRepository(ref.watch(appDatabaseProvider).eventDao);

@Riverpod(keepAlive: true)
NoteRepository noteRepository(Ref ref) =>
    NoteRepository(ref.watch(appDatabaseProvider).noteDao);

/// No-op on web: local reminders are an Android feature (spec Phase 4 treats
/// web as a companion without notifications). The stop action resolves the
/// timer repository lazily at tap time, so there is no build-time cycle.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => kIsWeb
    ? const NoopNotificationService()
    : LocalNotificationService(onAction: (actionId) {
        if (actionId == LocalNotificationService.stopTimerAction) {
          ref.read(timerRepositoryProvider).stopRunning();
        }
      });

@Riverpod(keepAlive: true)
TimerRepository timerRepository(Ref ref) => TimerRepository(
      ref.watch(appDatabaseProvider).timerDao,
      ref.watch(notificationServiceProvider),
    );

@Riverpod(keepAlive: true)
ReminderCoordinator reminderCoordinator(Ref ref) => ReminderCoordinator(
      ref.watch(notificationServiceProvider),
      ref.watch(appDatabaseProvider).reminderDao,
    );

/// The workspace the list screens are filtered to; null means all workspaces
/// (spec §6.1 global view). Kept alive so the choice survives navigation.
@Riverpod(keepAlive: true)
class SelectedWorkspaceId extends _$SelectedWorkspaceId {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// All live workspaces, ordered by sort order.
final allWorkspacesProvider = StreamProvider.autoDispose<List<Workspace>>(
  (ref) => ref.watch(workspaceRepositoryProvider).watchAll(),
);

/// One workspace by id (for detail/edit screens).
final workspaceByIdProvider =
    StreamProvider.autoDispose.family<Workspace?, String>(
  (ref, id) => ref.watch(workspaceRepositoryProvider).watchById(id),
);

/// The currently selected workspace row, or null in the "all" view.
final selectedWorkspaceProvider = StreamProvider.autoDispose<Workspace?>(
  (ref) {
    final id = ref.watch(selectedWorkspaceIdProvider);
    if (id == null) return Stream.value(null);
    return ref.watch(workspaceRepositoryProvider).watchById(id);
  },
);
