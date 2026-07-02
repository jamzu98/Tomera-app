import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
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
      expect(notificationIdFor('task-abc'),
          isNot(notificationIdFor('event-abc')));
      expect(
          notificationIdFor('task-abc'), isNot(notificationIdFor('task-abd')));
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
}
