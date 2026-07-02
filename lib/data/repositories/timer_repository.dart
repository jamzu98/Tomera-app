import 'package:drift/drift.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/utils.dart';
import '../db/daos/timer_dao.dart';
import '../db/database.dart';

/// Fixed notification id: only one timer runs at a time (spec §6.6 v1).
final timerNotificationId = notificationIdFor('work-timer');

/// Work timer (spec §6.6). Correctness comes from the persisted
/// `started_at`; the ongoing notification is a convenience layer only.
class TimerRepository {
  TimerRepository(this._dao, this._notifications);

  final TimerDao _dao;
  final NotificationService _notifications;

  Stream<TimerSession?> watchRunning() => _dao.watchRunning();

  Future<TimerSession?> getRunning() => _dao.getRunning();

  /// Starts a session. Throws [StateError] if one is already running.
  /// [notificationTitle] is shown in the persistent notification.
  Future<String> start({
    required String workspaceId,
    String? contactId,
    String? description,
    required String notificationTitle,
  }) async {
    if (await _dao.getRunning() != null) {
      throw StateError('A timer is already running');
    }
    final id = newId();
    final now = utcNowMs();
    await _dao.insertSession(TimerSessionsCompanion.insert(
      id: id,
      workspaceId: workspaceId,
      contactId: Value.absentIfNull(contactId),
      description: Value.absentIfNull(description),
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    ));
    await _notifications.showOngoingTimer(
      id: timerNotificationId,
      title: notificationTitle,
      startedAtMs: now,
    );
    return id;
  }

  /// Stops the session and returns its final elapsed milliseconds.
  Future<int> stop(TimerSession session) async {
    final now = utcNowMs();
    await _dao.stopSession(session.id, now);
    await _notifications.cancel(timerNotificationId);
    return now - session.startedAt;
  }

  /// Stops whatever is running (notification stop action); no-op otherwise.
  Future<void> stopRunning() async {
    final running = await _dao.getRunning();
    if (running != null) await stop(running);
  }
}
