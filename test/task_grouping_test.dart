import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/tasks/task_grouping.dart';

Task makeTask({
  required String id,
  TaskStatus status = TaskStatus.open,
  int? dueAt,
}) =>
    Task(
      id: id,
      ownerId: null,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: null,
      isDirty: true,
      workspaceId: 'w1',
      title: id,
      description: null,
      status: status,
      dueAt: dueAt,
      reminderAt: null,
      eventId: null,
      contactId: null,
      priority: TaskPriority.normal,
    );

void main() {
  final now = DateTime(2026, 7, 2, 12); // Thursday noon, local.
  int ms(DateTime dateTime) => dateTime.toUtc().millisecondsSinceEpoch;

  group('groupByDueDate', () {
    test('buckets tasks relative to now and omits empty sections', () {
      final grouped = groupByDueDate([
        makeTask(id: 'overdue', dueAt: ms(now.subtract(const Duration(hours: 2)))),
        makeTask(id: 'today', dueAt: ms(DateTime(2026, 7, 2, 18))),
        makeTask(id: 'week', dueAt: ms(DateTime(2026, 7, 5))),
        makeTask(id: 'later', dueAt: ms(DateTime(2026, 8, 1))),
        makeTask(id: 'none'),
      ], now);

      expect(grouped[DueSection.overdue]!.single.id, 'overdue');
      expect(grouped[DueSection.today]!.single.id, 'today');
      expect(grouped[DueSection.thisWeek]!.single.id, 'week');
      expect(grouped[DueSection.later]!.single.id, 'later');
      expect(grouped[DueSection.noDueDate]!.single.id, 'none');
    });

    test('omits sections with no tasks', () {
      final grouped = groupByDueDate([makeTask(id: 'none')], now);
      expect(grouped.keys, [DueSection.noDueDate]);
    });
  });

  group('groupByStatus', () {
    test('orders sections open, in progress, done', () {
      final grouped = groupByStatus([
        makeTask(id: 'd', status: TaskStatus.done),
        makeTask(id: 'o', status: TaskStatus.open),
        makeTask(id: 'p', status: TaskStatus.inProgress),
      ]);
      expect(grouped.keys.toList(),
          [TaskStatus.open, TaskStatus.inProgress, TaskStatus.done]);
    });
  });

  group('isOverdue', () {
    test('past due and not done is overdue', () {
      final task =
          makeTask(id: 'a', dueAt: ms(now.subtract(const Duration(minutes: 1))));
      expect(isOverdue(task, now), isTrue);
    });

    test('done tasks are never overdue', () {
      final task = makeTask(
        id: 'a',
        status: TaskStatus.done,
        dueAt: ms(now.subtract(const Duration(days: 1))),
      );
      expect(isOverdue(task, now), isFalse);
    });

    test('future due dates are not overdue', () {
      final task =
          makeTask(id: 'a', dueAt: ms(now.add(const Duration(minutes: 1))));
      expect(isOverdue(task, now), isFalse);
    });
  });
}
