import '../../data/db/daos/reminder_dao.dart';
import '../../data/db/database.dart';
import 'notification_service.dart';

/// Orchestrates reminder persistence and notification scheduling so widgets
/// make a single call after saving a task or event (spec §6.3).
class ReminderCoordinator {
  ReminderCoordinator(this._notifications, this._reminderDao);

  final NotificationService _notifications;
  final ReminderDao _reminderDao;

  /// Task reminders live in the `Tasks.reminderAt` column; only the
  /// notification needs syncing here.
  Future<void> syncTaskReminder({
    required String taskId,
    required String title,
    required int? reminderAtMs,
  }) async {
    final id = notificationIdFor('task-$taskId');
    if (reminderAtMs == null) {
      await _notifications.cancel(id);
    } else {
      await _notifications.schedule(
          id: id, title: title, fireAtMs: reminderAtMs);
    }
  }

  Future<void> cancelTaskReminder(String taskId) =>
      _notifications.cancel(notificationIdFor('task-$taskId'));

  /// Event reminders persist as a row in the Reminders table plus a
  /// scheduled notification. [fireAtMs] null clears both.
  Future<void> syncEventReminder({
    required String eventId,
    required String title,
    required int? fireAtMs,
  }) async {
    final id = notificationIdFor('event-$eventId');
    if (fireAtMs == null) {
      await _reminderDao.removeForParent(ParentType.event, eventId);
      await _notifications.cancel(id);
    } else {
      await _reminderDao.upsertForParent(ParentType.event, eventId, fireAtMs);
      await _notifications.schedule(id: id, title: title, fireAtMs: fireAtMs);
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    await _reminderDao.removeForParent(ParentType.event, eventId);
    await _notifications.cancel(notificationIdFor('event-$eventId'));
  }

  Stream<Reminder?> watchEventReminder(String eventId) =>
      _reminderDao.watchActiveByParent(ParentType.event, eventId);
}
