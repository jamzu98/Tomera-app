import 'package:drift/drift.dart';

import '../../data/db/daos/reminder_dao.dart';
import '../../data/db/database.dart';
import 'notification_service.dart';

/// Orchestrates reminder persistence and notification scheduling so widgets
/// make a single call after saving a task or event (spec §6.3).
class ReminderCoordinator {
  ReminderCoordinator(this._notifications, this._database);

  final NotificationService _notifications;
  final AppDatabase _database;
  Future<void> _pendingMutation = Future.value();

  ReminderDao get _reminderDao => _database.reminderDao;

  Future<void> _serialize(Future<void> Function() mutation) {
    final next = _pendingMutation.then(
      (_) => mutation(),
      onError: (Object _, StackTrace __) => mutation(),
    );
    _pendingMutation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  /// Task reminders live in the `Tasks.reminderAt` column; only the
  /// notification needs syncing here.
  Future<void> syncTaskReminder({
    required String taskId,
    required String title,
    required int? reminderAtMs,
  }) => _serialize(() async {
    final id = notificationIdFor('task-$taskId');
    if (reminderAtMs == null) {
      await _notifications.cancel(id);
    } else {
      await _notifications.schedule(
        id: id,
        title: title,
        fireAtMs: reminderAtMs,
      );
    }
  });

  Future<void> cancelTaskReminder(String taskId) => _serialize(
    () => _notifications.cancel(notificationIdFor('task-$taskId')),
  );

  /// Event reminders persist as a row in the Reminders table plus a
  /// scheduled notification. [fireAtMs] null clears both.
  Future<void> syncEventReminder({
    required String eventId,
    required String title,
    required int? fireAtMs,
  }) => _serialize(() async {
    final id = notificationIdFor('event-$eventId');
    if (fireAtMs == null) {
      await _reminderDao.removeForParent(ParentType.event, eventId);
      await _notifications.cancel(id);
    } else {
      await _reminderDao.upsertForParent(ParentType.event, eventId, fireAtMs);
      await _notifications.schedule(id: id, title: title, fireAtMs: fireAtMs);
    }
  });

  Future<void> cancelEventReminder(String eventId) => _serialize(() async {
    await _reminderDao.removeForParent(ParentType.event, eventId);
    await _notifications.cancel(notificationIdFor('event-$eventId'));
  });

  Stream<Reminder?> watchEventReminder(String eventId) =>
      _reminderDao.watchActiveByParent(ParentType.event, eventId);

  /// Rebuilds device-only notification state after a portable/Auto restore.
  /// Database rows are authoritative; stale platform notifications are
  /// cleared before future task/event reminders and the active timer are
  /// recreated.
  Future<void> reconcileFromDatabase() => _serialize(() async {
    await _notifications.cancelAll();
    final now = DateTime.now().millisecondsSinceEpoch;

    final tasks = await _database.taskDao.watchAll().first;
    for (final task in tasks) {
      final fireAt = task.reminderAt;
      if (task.status != TaskStatus.done && fireAt != null && fireAt > now) {
        await _notifications.schedule(
          id: notificationIdFor('task-${task.id}'),
          title: task.title,
          fireAtMs: fireAt,
        );
      }
    }

    final eventReminders =
        await (_database.select(_database.reminders)..where(
              (reminder) =>
                  reminder.parentType.equalsValue(ParentType.event) &
                  reminder.deletedAt.isNull() &
                  reminder.delivered.equals(false) &
                  reminder.fireAt.isBiggerThanValue(now),
            ))
            .get();
    for (final reminder in eventReminders) {
      final event = await _database.eventDao.getById(reminder.parentId);
      if (event == null) continue;
      await _notifications.schedule(
        id: notificationIdFor('event-${event.id}'),
        title: event.title,
        fireAtMs: reminder.fireAt,
      );
    }

    final timer = await _database.timerDao.getRunning();
    if (timer != null) {
      final workspace = await _database.workspaceDao.getById(timer.workspaceId);
      await _notifications.showOngoingTimer(
        id: notificationIdFor('work-timer'),
        title: timer.description?.trim().isNotEmpty == true
            ? timer.description!.trim()
            : (workspace?.name ?? 'Timer running'),
        startedAtMs: timer.startedAt,
      );
    }
  });

  /// Schedules reminders created while extending recurring-event horizons.
  /// Unlike full restore reconciliation this never calls cancelAll, so app
  /// resume cannot erase a reminder concurrently saved by the user.
  Future<void> syncMaterializedEventReminders(Iterable<String> eventIds) =>
      _serialize(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final eventId in eventIds.toSet()) {
          final reminder = await _reminderDao.getActiveByParent(
            ParentType.event,
            eventId,
          );
          final event = await _database.eventDao.getById(eventId);
          final notificationId = notificationIdFor('event-$eventId');
          if (reminder == null ||
              event == null ||
              reminder.delivered ||
              reminder.fireAt <= now) {
            await _notifications.cancel(notificationId);
            continue;
          }
          await _notifications.schedule(
            id: notificationId,
            title: event.title,
            fireAtMs: reminder.fireAt,
          );
        }
      });
}
