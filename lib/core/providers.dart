import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider, Provider, StreamProvider;
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

/// Owns the native Drift connection so restore can await a full close before
/// atomically replacing the SQLite file, then reopen it for all repositories.
String? _initialProfileUserId;

void configureInitialDataProfile(String? userId) {
  _initialProfileUserId = userId;
}

String _databaseNameForUser(String? userId) =>
    userId == null ? 'tomera' : 'tomera_user_${userId.replaceAll('-', '')}';

class DataProfile {
  const DataProfile.guest() : userId = null;
  const DataProfile.user(this.userId);

  final String? userId;
  bool get isGuest => userId == null;
  String get databaseName => _databaseNameForUser(userId);
}

class DatabaseLifecycle {
  DatabaseLifecycle({String? initialUserId})
    : _activeProfile = initialUserId == null
          ? const DataProfile.guest()
          : DataProfile.user(initialUserId),
      _database = AppDatabase.open(name: _databaseNameForUser(initialUserId));

  AppDatabase _database;
  DataProfile _activeProfile;
  var _closed = false;

  DataProfile get activeProfile => _activeProfile;

  AppDatabase get database {
    if (_closed) {
      throw StateError('The Tomera database is temporarily closed.');
    }
    return _database;
  }

  Future<void> closeForReplacement() async {
    if (_closed) return;
    _closed = true;
    await _database.close();
  }

  void reopen() {
    if (!_closed) return;
    _database = AppDatabase.open(name: _activeProfile.databaseName);
    _closed = false;
  }

  Future<void> switchProfile(DataProfile profile) async {
    if (_activeProfile.userId == profile.userId && !_closed) return;
    if (!_closed) await _database.close();
    _activeProfile = profile;
    _database = AppDatabase.open(name: profile.databaseName);
    _closed = false;
  }

  Future<void> clearUserProfile(String userId) async {
    final profile = DataProfile.user(userId);
    if (_activeProfile.userId == userId) {
      await _database.clearProfileData();
      return;
    }
    final database = AppDatabase.open(name: profile.databaseName);
    try {
      await database.clearProfileData();
    } finally {
      await database.close();
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _database.close();
  }
}

final databaseLifecycleProvider = Provider<DatabaseLifecycle>((ref) {
  final lifecycle = DatabaseLifecycle(initialUserId: _initialProfileUserId);
  ref.onDispose(() => unawaited(lifecycle.dispose()));
  return lifecycle;
});

class DatabaseRestoreEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final databaseRestoreEpochProvider =
    NotifierProvider<DatabaseRestoreEpoch, int>(DatabaseRestoreEpoch.new);

class DataProfileController extends Notifier<DataProfile> {
  @override
  DataProfile build() => _initialProfileUserId == null
      ? const DataProfile.guest()
      : DataProfile.user(_initialProfileUserId);

  Future<void> switchToGuest() => _switch(const DataProfile.guest());

  Future<void> switchToUser(String userId) => _switch(DataProfile.user(userId));

  Future<void> clearUser(String userId) async {
    final lifecycle = ref.read(databaseLifecycleProvider);
    await lifecycle.clearUserProfile(userId);
    if (state.userId == userId) await switchToGuest();
  }

  Future<void> _switch(DataProfile profile) async {
    if (state.userId == profile.userId) return;
    await ref.read(databaseLifecycleProvider).switchProfile(profile);
    state = profile;
    ref.read(databaseRestoreEpochProvider.notifier).bump();
    ref.read(selectedWorkspaceIdProvider.notifier).select(null);
    try {
      await ref.read(reminderCoordinatorProvider).reconcileFromDatabase();
    } on Object {
      // The profile is already switched; notification state can be repaired
      // on the next launch or resume if the OS service is unavailable.
    }
  }
}

final dataProfileControllerProvider =
    NotifierProvider<DataProfileController, DataProfile>(
      DataProfileController.new,
    );

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  ref.watch(databaseRestoreEpochProvider);
  return ref.watch(databaseLifecycleProvider).database;
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
    : LocalNotificationService(
        onAction: (actionId) {
          if (actionId == LocalNotificationService.stopTimerAction) {
            ref.read(timerRepositoryProvider).stopRunning();
          }
        },
      );

@Riverpod(keepAlive: true)
TimerRepository timerRepository(Ref ref) => TimerRepository(
  ref.watch(appDatabaseProvider).timerDao,
  ref.watch(notificationServiceProvider),
);

@Riverpod(keepAlive: true)
ReminderCoordinator reminderCoordinator(Ref ref) => ReminderCoordinator(
  ref.watch(notificationServiceProvider),
  ref.watch(appDatabaseProvider),
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
final workspaceByIdProvider = StreamProvider.autoDispose
    .family<Workspace?, String>(
      (ref, id) => ref.watch(workspaceRepositoryProvider).watchById(id),
    );

/// The currently selected workspace row, or null in the "all" view.
final selectedWorkspaceProvider = StreamProvider.autoDispose<Workspace?>((ref) {
  final id = ref.watch(selectedWorkspaceIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(workspaceRepositoryProvider).watchById(id);
});
