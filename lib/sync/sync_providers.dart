import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../core/providers.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingChanges = 0,
    this.lastSuccessfulSyncAt,
    this.error,
  });

  final SyncPhase phase;
  final int pendingChanges;
  final DateTime? lastSuccessfulSyncAt;
  final Object? error;
}

class SyncCoordinator extends Notifier<SyncStatus> {
  StreamSubscription<void>? _dirtySubscription;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _retry;
  RealtimeChannel? _channel;
  bool _running = false;
  var _retrySeconds = 2;

  @override
  SyncStatus build() {
    final account = ref.watch(accountControllerProvider).value;
    ref.watch(dataProfileControllerProvider);
    ref.watch(databaseRestoreEpochProvider);
    ref.onDispose(_dispose);
    if (account?.isSignedIn == true) {
      Future<void>.microtask(() => _start(account!.user!.id));
    } else {
      _dispose();
    }
    return const SyncStatus();
  }

  SyncEngine? _engine() {
    final account = ref.read(accountControllerProvider).value;
    final client = ref.read(authRepositoryProvider).client;
    if (account?.isSignedIn != true || client == null) return null;
    return SyncEngine(
      database: ref.read(appDatabaseProvider),
      client: client,
      userId: account!.user!.id,
    );
  }

  Future<void> syncNow() async {
    if (_running) return;
    final engine = _engine();
    if (engine == null) return;
    _running = true;
    state = SyncStatus(
      phase: SyncPhase.syncing,
      pendingChanges: state.pendingChanges,
      lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
    );
    try {
      await engine.synchronize();
      state = SyncStatus(
        pendingChanges: await engine.pendingCount(),
        lastSuccessfulSyncAt: DateTime.now().toUtc(),
      );
      _retry?.cancel();
      _retry = null;
      _retrySeconds = 2;
    } on Object catch (error) {
      await engine.recordError(error);
      state = SyncStatus(
        phase: _isOfflineError(error) ? SyncPhase.offline : SyncPhase.error,
        pendingChanges: await engine.pendingCount(),
        lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
        error: error,
      );
      _retry?.cancel();
      _retry = Timer(Duration(seconds: _retrySeconds), syncNow);
      _retrySeconds = (_retrySeconds * 2).clamp(2, 60);
    } finally {
      _running = false;
    }
  }

  Future<void> _start(String userId) async {
    _dispose();
    final database = ref.read(appDatabaseProvider);
    final client = ref.read(authRepositoryProvider).client;
    if (client == null) return;
    final dirty = database
        .customSelect(
          _pendingSql,
          readsFrom: {
            database.workspaces,
            database.contacts,
            database.workspaceContacts,
            database.projects,
            database.eventSeriesTable,
            database.eventSeriesContacts,
            database.events,
            database.eventContacts,
            database.taskSeriesTable,
            database.tasks,
            database.notes,
            database.noteLinks,
            database.timerSessions,
            database.billableItems,
            database.reminders,
          },
        )
        .watch();
    _dirtySubscription = dirty.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), syncNow);
    });
    _periodic = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(syncNow()),
    );
    _channel = client
        .channel('tomera-sync-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sync_changes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: userId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), syncNow);
          },
        )
        .subscribe();
    await syncNow();
  }

  void _dispose() {
    _dirtySubscription?.cancel();
    _dirtySubscription = null;
    _debounce?.cancel();
    _debounce = null;
    _periodic?.cancel();
    _periodic = null;
    _retry?.cancel();
    _retry = null;
    _retrySeconds = 2;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(
        ref.read(authRepositoryProvider).client?.removeChannel(channel),
      );
    }
  }
}

bool _isOfflineError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('socket') ||
      message.contains('network') ||
      message.contains('failed host lookup') ||
      message.contains('connection refused') ||
      message.contains('clientexception');
}

final syncCoordinatorProvider = NotifierProvider<SyncCoordinator, SyncStatus>(
  SyncCoordinator.new,
);

const _pendingSql = '''
SELECT
  (SELECT COUNT(*) FROM workspaces WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM contacts WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM workspace_contacts WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM projects WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM event_series WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM event_series_contacts WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM events WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM event_contacts WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM task_series WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM tasks WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM notes WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM note_links WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM timer_sessions WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM billable_items WHERE is_dirty = 1) +
  (SELECT COUNT(*) FROM reminders WHERE is_dirty = 1) AS pending
''';
