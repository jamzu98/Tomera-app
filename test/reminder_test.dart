import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/notifications/reminder_coordinator.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/calendar/reminder_offsets.dart';

void main() {
  group('notificationIdFor', () {
    test('is deterministic and positive', () {
      final id = notificationIdFor('task-abc');
      expect(id, notificationIdFor('task-abc'));
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('differs per entity and per kind', () {
      expect(
        notificationIdFor('task-abc'),
        isNot(notificationIdFor('event-abc')),
      );
      expect(
        notificationIdFor('task-abc'),
        isNot(notificationIdFor('task-abd')),
      );
    });
  });

  group('reminderFireAtMs', () {
    const start = 1000000000;

    test('computes offsets relative to the event start', () {
      expect(reminderFireAtMs(ReminderOffset.none, start), isNull);
      expect(reminderFireAtMs(ReminderOffset.atStart, start), start);
      expect(reminderFireAtMs(ReminderOffset.min15, start), start - 900000);
      expect(reminderFireAtMs(ReminderOffset.hour1, start), start - 3600000);
      expect(reminderFireAtMs(ReminderOffset.day1, start), start - 86400000);
    });

    test('offsetFromFireAt round-trips every offset', () {
      for (final offset in ReminderOffset.values) {
        expect(
          offsetFromFireAt(reminderFireAtMs(offset, start), start),
          offset,
        );
      }
    });

    test('offsetFromFireAt falls back to atStart for custom deltas', () {
      expect(offsetFromFireAt(start - 1234, start), ReminderOffset.atStart);
    });
  });

  test('restore reconciliation rebuilds reminders and running timer', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final notifications = _RecordingNotifications();
    final coordinator = ReminderCoordinator(notifications, database);
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.workspaceDao.insertWorkspace(
      WorkspacesCompanion.insert(
        id: 'workspace',
        name: 'Studio',
        color: 0xFF000000,
        icon: 'work',
        enabledModules: ModuleKey.values.toSet(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.taskDao.insertTask(
      TasksCompanion.insert(
        id: 'task',
        workspaceId: 'workspace',
        title: 'Send proposal',
        reminderAt: Value(now + 60000),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.eventDao.insertEvent(
      EventsCompanion.insert(
        id: 'event',
        workspaceId: 'workspace',
        title: 'Client call',
        startsAt: now + 120000,
        endsAt: now + 180000,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.reminderDao.upsertForParent(
      ParentType.event,
      'event',
      now + 90000,
    );
    await database.timerDao.insertSession(
      TimerSessionsCompanion.insert(
        id: 'timer',
        workspaceId: 'workspace',
        description: const Value('Deep work'),
        startedAt: now - 60000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await coordinator.reconcileFromDatabase();

    expect(notifications.cancelAllCount, 1);
    expect(
      notifications.scheduled.map((item) => item.title),
      containsAll(['Send proposal', 'Client call']),
    );
    expect(notifications.timerTitle, 'Deep work');
  });
}

class _ScheduledNotification {
  const _ScheduledNotification(this.id, this.title, this.fireAtMs);

  final int id;
  final String title;
  final int fireAtMs;
}

class _RecordingNotifications implements NotificationService {
  var cancelAllCount = 0;
  final scheduled = <_ScheduledNotification>[];
  String? timerTitle;

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required int fireAtMs,
  }) async {
    scheduled.add(_ScheduledNotification(id, title, fireAtMs));
  }

  @override
  Future<void> showOngoingTimer({
    required int id,
    required String title,
    required int startedAtMs,
  }) async {
    timerTitle = title;
  }
}
