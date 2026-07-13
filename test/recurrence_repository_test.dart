import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/recurrence/recurrence_models.dart';
import 'package:tomera/data/recurrence/recurrence_rule.dart';
import 'package:tomera/data/repositories/contact_repository.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late ContactRepository contacts;
  late EventRepository events;
  late TaskRepository tasks;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    contacts = ContactRepository(db.contactDao);
    events = EventRepository(db.eventDao);
    tasks = TaskRepository(db.taskDao);
  });

  tearDown(() => db.close());

  Future<String> workspace() => workspaces.create(
    name: 'Workspace',
    color: 0,
    icon: 'work',
    enabledModules: {...ModuleKey.values},
  );

  int utc(int year, int month, int day, [int hour = 0]) =>
      DateTime.utc(year, month, day, hour).millisecondsSinceEpoch;

  test(
    'event series materializes real linked rows and extends idempotently',
    () async {
      final workspaceId = await workspace();
      final contactId = await contacts.create(name: 'Contact');
      final creation = await events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Stand-up',
          localStartsAt: DateTime.utc(2026, 1, 1, 9),
          duration: const Duration(minutes: 30),
          timezoneId: 'UTC',
          contactIds: {contactId},
          reminderOffsetMinutes: 15,
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        horizonUtcMs: utc(2026, 1, 3, 23),
      );

      expect(creation.occurrenceIds, hasLength(3));
      final rows = await events.watchSeriesOccurrences(creation.seriesId).first;
      expect(rows, hasLength(3));
      expect(rows.map((event) => event.id).toSet(), hasLength(3));
      expect(
        rows.every((event) => event.originalStartsAt == event.startsAt),
        isTrue,
      );
      expect(
        await db.select(db.eventContacts).get(),
        hasLength(3),
        reason: 'series contact links are copied onto every real occurrence',
      );
      expect(await db.select(db.reminders).get(), hasLength(3));

      expect(
        await events.materializeSeries(
          creation.seriesId,
          throughUtcMs: utc(2026, 1, 3, 23),
        ),
        isEmpty,
      );
      expect(
        await events.materializeSeries(
          creation.seriesId,
          throughUtcMs: utc(2026, 1, 5, 23),
        ),
        hasLength(2),
      );
      expect(
        await events.watchSeriesOccurrences(creation.seriesId).first,
        hasLength(5),
      );
      expect(
        await events.findConflicts(
          startMs: utc(2026, 1, 2, 9),
          endMs: utc(2026, 1, 2, 10),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'far-future weekly series reaches its first custom-interval day',
    () async {
      final workspaceId = await workspace();
      final creation = await events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Future cadence',
          localStartsAt: DateTime.utc(2035, 1, 3, 9),
          duration: const Duration(hours: 1),
          timezoneId: 'UTC',
        ),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 4,
          weekdays: {DateTime.monday},
          count: 1,
        ),
      );
      final occurrence =
          (await events.watchSeriesOccurrences(creation.seriesId).first).single;
      expect(occurrence.startsAt, utc(2035, 1, 29, 9));
    },
  );

  test('empty recurring creation rolls its template back', () async {
    final workspaceId = await workspace();
    await expectLater(
      events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Impossible cadence',
          localStartsAt: DateTime.utc(2035, 1, 3, 9),
          duration: const Duration(hours: 1),
          timezoneId: 'UTC',
        ),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 4,
          weekdays: {DateTime.monday},
          untilDate: DateTime.utc(2035, 1, 10),
        ),
      ),
      throwsStateError,
    );
    expect(await db.select(db.eventSeriesTable).get(), isEmpty);
  });

  test(
    'occurrence edits become exceptions and suppression cannot regenerate',
    () async {
      final workspaceId = await workspace();
      final contactId = await contacts.create(name: 'Student');
      final creation = await events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Lesson',
          localStartsAt: DateTime.utc(2026, 2, 1, 9),
          duration: const Duration(hours: 1),
          timezoneId: 'UTC',
          contactIds: {contactId},
          reminderOffsetMinutes: 10,
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 3),
        horizonUtcMs: utc(2026, 2, 10),
      );
      final rows = await events.watchSeriesOccurrences(creation.seriesId).first;

      await events.updateRecurrence(
        eventId: rows.first.id,
        scope: RecurrenceEditScope.occurrence,
        title: 'Special lesson',
      );
      final exception = await events.getById(rows.first.id);
      expect(exception?.title, 'Special lesson');
      expect(exception?.recurrenceException, isTrue);

      expect(
        await events.deleteRecurrence(
          rows[1].id,
          RecurrenceEditScope.occurrence,
        ),
        [rows[1].id],
      );
      expect(
        await events.watchSeriesOccurrences(creation.seriesId).first,
        hasLength(2),
      );
      await events.materializeSeries(
        creation.seriesId,
        throughUtcMs: utc(2026, 2, 10),
      );
      expect(
        await events.watchSeriesOccurrences(creation.seriesId).first,
        hasLength(2),
      );
      final suppressed = await (db.select(
        db.events,
      )..where((event) => event.id.equals(rows[1].id))).getSingle();
      expect(suppressed.recurrenceSuppressed, isTrue);
      expect(await events.watchForContact(contactId).first, hasLength(2));
      final reminder = await (db.select(
        db.reminders,
      )..where((row) => row.parentId.equals(rows[1].id))).getSingle();
      expect(reminder.deletedAt, isNotNull);

      await events.restoreRecurrenceOccurrence(rows[1].id);
      expect(
        await events.watchSeriesOccurrences(creation.seriesId).first,
        hasLength(3),
      );
      final restoredReminder = await (db.select(
        db.reminders,
      )..where((row) => row.parentId.equals(rows[1].id))).getSingle();
      expect(restoredReminder.deletedAt, isNull);
    },
  );

  test(
    'current/future edit splits a series and preserves prior history',
    () async {
      final workspaceId = await workspace();
      final original = await events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Original',
          localStartsAt: DateTime.utc(2026, 3, 1, 9),
          duration: const Duration(hours: 1),
          timezoneId: 'UTC',
          reminderOffsetMinutes: 10,
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 4),
        horizonUtcMs: utc(2026, 3, 10),
      );
      final originalRows = await events
          .watchSeriesOccurrences(original.seriesId)
          .first;

      final split = await events.updateRecurrence(
        eventId: originalRows[2].id,
        scope: RecurrenceEditScope.currentAndFuture,
        currentAndFutureTemplate: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Changed',
          localStartsAt: DateTime.utc(2026, 3, 3, 10),
          duration: const Duration(hours: 2),
          timezoneId: 'UTC',
          reminderOffsetMinutes: 20,
        ),
        currentAndFutureRule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 4,
        ),
        horizonUtcMs: utc(2026, 3, 10),
      );

      expect(split, isNotNull);
      final preserved = await events
          .watchSeriesOccurrences(original.seriesId)
          .first;
      expect(preserved.map((event) => event.title), ['Original', 'Original']);
      final changed = await events
          .watchSeriesOccurrences(split!.seriesId)
          .first;
      expect(changed, hasLength(2));
      expect(changed.every((event) => event.title == 'Changed'), isTrue);
      expect(changed.first.startsAt, utc(2026, 3, 3, 10));
      final reminderRows = await db.select(db.reminders).get();
      expect(reminderRows.where((row) => row.deletedAt == null), hasLength(4));
      expect(reminderRows.where((row) => row.deletedAt != null), hasLength(2));
    },
  );

  test(
    'current/future delete retains past events and terminates generation',
    () async {
      final workspaceId = await workspace();
      final creation = await events.createRecurring(
        template: EventSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Series',
          localStartsAt: DateTime.utc(2026, 4, 1, 9),
          duration: const Duration(hours: 1),
          timezoneId: 'UTC',
          reminderOffsetMinutes: 5,
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        horizonUtcMs: utc(2026, 4, 4, 23),
      );
      final rows = await events.watchSeriesOccurrences(creation.seriesId).first;
      final affected = await events.deleteRecurrence(
        rows[2].id,
        RecurrenceEditScope.currentAndFuture,
      );
      expect(affected.toSet(), {rows[2].id, rows[3].id});

      expect(
        await events.watchSeriesOccurrences(creation.seriesId).first,
        hasLength(2),
      );
      expect(await events.watchSeries(creation.seriesId).first, isNull);
      expect(
        await events.materializeSeries(
          creation.seriesId,
          throughUtcMs: utc(2026, 4, 20),
        ),
        isEmpty,
      );
      final deletedReminders = await (db.select(
        db.reminders,
      )..where((row) => row.parentId.isIn(affected))).get();
      expect(deletedReminders, hasLength(2));
      expect(deletedReminders.every((row) => row.deletedAt != null), isTrue);
      await expectLater(
        events.updateRecurrence(
          eventId: rows.first.id,
          scope: RecurrenceEditScope.currentAndFuture,
          currentAndFutureTemplate: EventSeriesTemplate(
            workspaceId: workspaceId,
            title: 'Must not resurrect',
            localStartsAt: DateTime.utc(2026, 4, 1, 10),
            duration: const Duration(hours: 1),
            timezoneId: 'UTC',
          ),
          currentAndFutureRule: RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            count: 2,
          ),
          horizonUtcMs: utc(2026, 4, 10),
        ),
        throwsStateError,
      );
    },
  );

  test('all-day occurrence preserves local midnight across DST', () async {
    final workspaceId = await workspace();
    final creation = await events.createRecurring(
      template: EventSeriesTemplate(
        workspaceId: workspaceId,
        title: 'DST day',
        localStartsAt: DateTime.utc(2026, 3, 29),
        duration: const Duration(days: 1),
        timezoneId: 'Europe/Helsinki',
        allDay: true,
      ),
      rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 1),
      horizonUtcMs: utc(2026, 4, 1),
    );
    final event =
        (await events.watchSeriesOccurrences(creation.seriesId).first).single;
    final engine = RecurrenceEngine();
    expect(
      engine.toLocalComponents(event.startsAt, 'Europe/Helsinki'),
      DateTime.utc(2026, 3, 29),
    );
    expect(
      engine.toLocalComponents(event.endsAt, 'Europe/Helsinki'),
      DateTime.utc(2026, 3, 30),
    );
    expect(
      event.endsAt - event.startsAt,
      const Duration(hours: 23).inMilliseconds,
    );
  });

  test(
    'schedule-anchored task chain skips invalid dates and is idempotent',
    () async {
      final workspaceId = await workspace();
      final creation = await tasks.createRepeating(
        template: TaskSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Month end',
          firstDueLocal: DateTime.utc(2026, 1, 31, 9),
          timezoneId: 'UTC',
          reminderOffsetMinutes: 60,
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.monthly, count: 3),
      );
      final first = await tasks.watchById(creation.firstTaskId).first;
      expect(first?.dueAt, utc(2026, 1, 31, 9));

      final completed = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 2, 2, 12),
      );
      final retry = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 2, 3, 12),
      );
      expect(retry.successorTaskId, completed.successorTaskId);
      final second = await tasks.watchById(completed.successorTaskId!).first;
      expect(second?.dueAt, utc(2026, 3, 31, 9));
      expect(second?.reminderAt, utc(2026, 3, 31, 8));

      final next = await tasks.complete(
        second!.id,
        completedAtMs: utc(2026, 4, 2, 12),
      );
      final third = await tasks.watchById(next.successorTaskId!).first;
      expect(third?.dueAt, utc(2026, 5, 31, 9));
      final finalResult = await tasks.complete(
        third!.id,
        completedAtMs: utc(2026, 6, 1, 12),
      );
      expect(finalResult.successorTaskId, isNull);
      expect(await tasks.watchAll().first, hasLength(3));
    },
  );

  test(
    'completion anchor advances from completion and respects end date',
    () async {
      final workspaceId = await workspace();
      final creation = await tasks.createRepeating(
        template: TaskSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Follow-up',
          firstDueLocal: DateTime.utc(2026, 6, 1, 9),
          timezoneId: 'Europe/Helsinki',
        ),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: 2,
          untilDate: DateTime.utc(2026, 6, 5),
        ),
        anchor: TaskRepeatAnchor.completion,
      );
      final completedAt = RecurrenceEngine().toUtcMs(
        DateTime.utc(2026, 6, 2, 15),
        'Europe/Helsinki',
      );
      final result = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: completedAt,
      );
      final second = await tasks.watchById(result.successorTaskId!).first;
      expect(
        RecurrenceEngine().toLocalComponents(second!.dueAt!, 'Europe/Helsinki'),
        DateTime.utc(2026, 6, 4, 15),
      );

      final secondCompletedAt = RecurrenceEngine().toUtcMs(
        DateTime.utc(2026, 6, 4, 16),
        'Europe/Helsinki',
      );
      final end = await tasks.complete(
        second.id,
        completedAtMs: secondCompletedAt,
      );
      expect(end.successorTaskId, isNull);
    },
  );

  test(
    'completion retry anchors from the persisted completion instant',
    () async {
      final workspaceId = await workspace();
      final creation = await tasks.createRepeating(
        template: TaskSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Durable anchor',
          firstDueLocal: DateTime.utc(2026, 7, 1, 9),
          timezoneId: 'UTC',
        ),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: 2,
          count: 2,
        ),
        anchor: TaskRepeatAnchor.completion,
      );
      await db.customStatement(
        'UPDATE task_series SET deleted_at = 1 WHERE id = ?',
        [creation.seriesId],
      );
      final firstCompletion = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 7, 2, 15),
      );
      expect(firstCompletion.successorTaskId, isNull);
      await db.customStatement(
        'UPDATE task_series SET deleted_at = NULL WHERE id = ?',
        [creation.seriesId],
      );

      final retry = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 7, 10, 15),
      );
      final successor = await tasks.getById(retry.successorTaskId!);
      expect(successor?.dueAt, utc(2026, 7, 4, 15));
    },
  );

  test(
    'completion undo removes and redo restores the generated successor',
    () async {
      final workspaceId = await workspace();
      final creation = await tasks.createRepeating(
        template: TaskSeriesTemplate(
          workspaceId: workspaceId,
          title: 'Undoable',
          firstDueLocal: DateTime.utc(2026, 8, 1, 9),
          timezoneId: 'UTC',
        ),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 2),
      );
      final completion = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 8, 1, 10),
      );
      final successorId = completion.successorTaskId!;

      expect(
        await tasks.undoCompletion(creation.firstTaskId, TaskStatus.open),
        successorId,
      );
      final reopened = await tasks.getById(creation.firstTaskId);
      expect(reopened?.status, TaskStatus.open);
      expect(reopened?.completedAt, isNull);
      expect(await tasks.getById(successorId), isNull);
      expect(
        await tasks.undoCompletion(creation.firstTaskId, TaskStatus.open),
        successorId,
      );

      final redone = await tasks.complete(
        creation.firstTaskId,
        completedAtMs: utc(2026, 8, 1, 11),
      );
      expect(redone.successorTaskId, successorId);
      expect(await tasks.getById(successorId), isNotNull);

      await tasks.update(successorId, status: TaskStatus.inProgress);
      await expectLater(
        tasks.undoCompletion(creation.firstTaskId, TaskStatus.open),
        throwsStateError,
      );
      expect(
        (await tasks.getById(creation.firstTaskId))?.status,
        TaskStatus.done,
      );
      expect((await tasks.getById(successorId))?.status, TaskStatus.inProgress);
    },
  );
}
