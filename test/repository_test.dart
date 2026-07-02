import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late TaskRepository tasks;
  late NoteRepository notes;
  late EventRepository events;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    tasks = TaskRepository(db.taskDao);
    notes = NoteRepository(db.noteDao);
    events = EventRepository(db.eventDao);
  });

  tearDown(() => db.close());

  Future<String> createWorkspace({String name = 'DEV'}) => workspaces.create(
        name: name,
        color: 0xFF000000,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );

  group('WorkspaceRepository', () {
    test('create and watch, ordered by sort order', () async {
      await createWorkspace(name: 'A');
      await createWorkspace(name: 'B');
      final all = await workspaces.watchAll().first;
      expect(all.map((w) => w.name), ['A', 'B']);
      expect(all.every((w) => w.isDirty), isTrue);
    });

    test('soft delete hides the row but keeps it in the table', () async {
      final id = await createWorkspace();
      await workspaces.delete(id);
      expect(await workspaces.watchAll().first, isEmpty);
      final raw = await db.select(db.workspaces).get();
      expect(raw.single.deletedAt, isNotNull);
    });

    test('reorder rewrites sort order to match the given id order', () async {
      final a = await createWorkspace(name: 'A');
      final b = await createWorkspace(name: 'B');
      await workspaces.reorder([b, a]);
      final all = await workspaces.watchAll().first;
      expect(all.map((w) => w.name), ['B', 'A']);
    });

    test('update bumps updatedAt and sets isDirty', () async {
      final id = await createWorkspace();
      final before = (await workspaces.watchById(id).first)!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await workspaces.update(id, name: 'Renamed');
      final after = (await workspaces.watchById(id).first)!;
      expect(after.updatedAt, greaterThan(before.updatedAt));
      expect(after.isDirty, isTrue);
    });
  });

  group('TaskRepository', () {
    test('cycleStatus progresses open → in progress → done → open', () async {
      final workspaceId = await createWorkspace();
      final id = await tasks.create(workspaceId: workspaceId, title: 'T');

      Future<Task> current() async => (await tasks.watchById(id).first)!;
      expect((await current()).status, TaskStatus.open);

      await tasks.cycleStatus(await current());
      expect((await current()).status, TaskStatus.inProgress);
      await tasks.cycleStatus(await current());
      expect((await current()).status, TaskStatus.done);
      await tasks.cycleStatus(await current());
      expect((await current()).status, TaskStatus.open);
    });

    test('watchAll filters by workspace and hides soft-deleted rows',
        () async {
      final w1 = await createWorkspace(name: 'A');
      final w2 = await createWorkspace(name: 'B');
      final t1 = await tasks.create(workspaceId: w1, title: 'in w1');
      await tasks.create(workspaceId: w2, title: 'in w2');

      expect(await tasks.watchAll(workspaceId: w1).first, hasLength(1));
      expect(await tasks.watchAll().first, hasLength(2));

      await tasks.delete(t1);
      expect(await tasks.watchAll(workspaceId: w1).first, isEmpty);
    });

    test('update can clear the due date', () async {
      final workspaceId = await createWorkspace();
      final id = await tasks.create(
          workspaceId: workspaceId, title: 'T', dueAt: 12345);
      await tasks.update(id, dueAt: const Value(null));
      expect((await tasks.watchById(id).first)!.dueAt, isNull);
    });
  });

  group('NoteRepository', () {
    test('supports standalone notes and workspace filtering', () async {
      final workspaceId = await createWorkspace();
      await notes.create(title: 'standalone', body: '');
      await notes.create(workspaceId: workspaceId, title: 'scoped', body: '');

      expect(await notes.watchAll().first, hasLength(2));
      final scoped = await notes.watchAll(workspaceId: workspaceId).first;
      expect(scoped.single.title, 'scoped');
    });
  });

  group('EventRepository.findConflicts', () {
    test('detects overlaps across workspaces, ignoring boundaries and'
        ' soft-deleted and all-day events', () async {
      final w1 = await createWorkspace(name: 'A');
      final w2 = await createWorkspace(name: 'B');

      final overlapping = await events.create(
          workspaceId: w1, title: 'overlap', startsAt: 100, endsAt: 200);
      await events.create(
          workspaceId: w2, title: 'touching', startsAt: 250, endsAt: 300);
      final deleted = await events.create(
          workspaceId: w1, title: 'deleted', startsAt: 100, endsAt: 200);
      await events.delete(deleted);
      await events.create(
          workspaceId: w2,
          title: 'allday',
          startsAt: 0,
          endsAt: 1000,
          allDay: true);

      final conflicts = await events.findConflicts(startMs: 150, endMs: 250);
      expect(conflicts.map((e) => e.id), [overlapping]);
    });

    test('excludes the event being edited', () async {
      final workspaceId = await createWorkspace();
      final id = await events.create(
          workspaceId: workspaceId, title: 'E', startsAt: 100, endsAt: 200);
      final conflicts = await events.findConflicts(
          startMs: 100, endMs: 200, excludeEventId: id);
      expect(conflicts, isEmpty);
    });

    test('an all-day candidate never conflicts', () async {
      final workspaceId = await createWorkspace();
      await events.create(
          workspaceId: workspaceId, title: 'E', startsAt: 100, endsAt: 200);
      final conflicts =
          await events.findConflicts(startMs: 0, endMs: 1000, allDay: true);
      expect(conflicts, isEmpty);
    });
  });
}
