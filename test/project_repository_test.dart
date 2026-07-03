import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/billable_repository.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/project_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late ProjectRepository projects;
  late EventRepository events;
  late TaskRepository tasks;
  late BillableRepository billables;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    projects = ProjectRepository(db.projectDao);
    events = EventRepository(db.eventDao);
    tasks = TaskRepository(db.taskDao);
    billables = BillableRepository(db.billableDao);
  });

  tearDown(() => db.close());

  Future<String> createWorkspace({String name = 'DEV'}) => workspaces.create(
        name: name,
        color: 0xFF000000,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );

  group('ProjectRepository', () {
    test('create, filter by workspace, and hide archived by default',
        () async {
      final w1 = await createWorkspace(name: 'A');
      final w2 = await createWorkspace(name: 'B');
      final visible = await projects.create(workspaceId: w1, name: 'Course');
      await projects.create(workspaceId: w2, name: 'Elsewhere');
      final archived =
          await projects.create(workspaceId: w1, name: 'Old gig');
      await projects.update(archived, archived: true);

      final inW1 = await projects.watchAll(workspaceId: w1).first;
      expect(inW1.map((p) => p.id), [visible]);

      final withArchived =
          await projects.watchAll(workspaceId: w1, includeArchived: true).first;
      expect(withArchived, hasLength(2));
      expect(await projects.watchAll().first, hasLength(2));
    });

    test('soft delete hides the project but keeps the row', () async {
      final workspaceId = await createWorkspace();
      final id = await projects.create(workspaceId: workspaceId, name: 'P');
      await projects.delete(id);
      expect(await projects.watchAll().first, isEmpty);
      expect((await db.select(db.projects).get()).single.deletedAt, isNotNull);
    });
  });

  group('project links', () {
    test('events, tasks, and billables filter by project', () async {
      final workspaceId = await createWorkspace();
      final projectId =
          await projects.create(workspaceId: workspaceId, name: 'Course');

      await events.create(
          workspaceId: workspaceId,
          title: 'lecture',
          startsAt: 100,
          endsAt: 200,
          projectId: projectId);
      await events.create(
          workspaceId: workspaceId,
          title: 'unrelated',
          startsAt: 300,
          endsAt: 400);
      await tasks.create(
          workspaceId: workspaceId, title: 'grade exams', projectId: projectId);
      await billables.create(
          workspaceId: workspaceId,
          projectId: projectId,
          type: BillableType.fixed,
          title: 'teaching fee',
          amountCents: 50000);
      await billables.create(
          workspaceId: workspaceId,
          type: BillableType.fixed,
          title: 'other',
          amountCents: 99);

      expect((await events.watchForProject(projectId).first).single.title,
          'lecture');
      expect((await tasks.watchForProject(projectId).first).single.title,
          'grade exams');
      final totals = await billables.watchTotalsForProject(projectId).first;
      expect(totals.unbilled, 50000);
    });
  });

  group('EventRepository.createMany', () {
    test('creates one linked event per range', () async {
      final workspaceId = await createWorkspace();
      final projectId =
          await projects.create(workspaceId: workspaceId, name: 'Course');

      await events.createMany(
        workspaceId: workspaceId,
        title: 'Math 101',
        location: 'Room 5',
        projectId: projectId,
        ranges: [
          (startsAt: 1000, endsAt: 2000),
          (startsAt: 3000, endsAt: 4000),
          (startsAt: 5000, endsAt: 6000),
        ],
      );

      final created = await events.watchForProject(projectId).first;
      expect(created, hasLength(3));
      expect(created.map((e) => e.startsAt), [1000, 3000, 5000]);
      expect(created.every((e) => e.title == 'Math 101'), isTrue);
      expect(created.every((e) => e.location == 'Room 5'), isTrue);
      expect(created.every((e) => e.projectId == projectId), isTrue);
      // Each instance is an independent event visible to conflict detection.
      final conflicts = await events.findConflicts(startMs: 1500, endMs: 3500);
      expect(conflicts, hasLength(2));
    });
  });
}
