import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/billable_repository.dart';
import 'package:tomera/data/repositories/contact_repository.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/project_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/timer_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late ContactRepository contacts;
  late ProjectRepository projects;
  late TaskRepository tasks;
  late NoteRepository notes;
  late TimerRepository timers;
  late BillableRepository billables;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    contacts = ContactRepository(db.contactDao);
    projects = ProjectRepository(db.projectDao);
    tasks = TaskRepository(db.taskDao);
    notes = NoteRepository(db.noteDao);
    timers = TimerRepository(db.timerDao, const NoopNotificationService());
    billables = BillableRepository(db.billableDao);
  });

  tearDown(() => db.close());

  Future<String> createWorkspace({int? rateCents}) => workspaces.create(
    name: 'Workspace',
    color: 0,
    icon: 'work',
    enabledModules: {...ModuleKey.values},
    defaultHourlyRateCents: rateCents,
  );

  test(
    'project timers remain recoverable until one billable is created',
    () async {
      final workspaceId = await createWorkspace(rateCents: 5000);
      final projectId = await projects.create(
        workspaceId: workspaceId,
        name: 'Project',
        hourlyRateCents: 7500,
      );
      final timerId = await timers.start(
        workspaceId: workspaceId,
        projectId: projectId,
        description: 'Implementation',
        notificationTitle: 'Implementation',
      );
      final running = await timers.getRunning();
      expect(running?.projectId, projectId);
      await timers.stop(running!);

      final stopped = (await timers.watchUnconverted().first).single;
      expect(stopped.id, timerId);

      final firstId = await billables.createFromTimer(
        session: stopped,
        title: 'Implementation',
        durationMinutes: 45,
      );
      final retryId = await billables.createFromTimer(
        session: stopped,
        title: 'A retry must not overwrite the first conversion',
        durationMinutes: 99,
      );
      expect(retryId, firstId);
      expect(await timers.watchUnconverted().first, isEmpty);

      final item = (await billables.watchAll().first).single;
      expect(item.timerSessionId, timerId);
      expect(item.projectId, projectId);
      expect(item.rateCents, 7500);
      expect(item.durationMinutes, 45);

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(
        () => db
            .into(db.billableItems)
            .insert(
              BillableItemsCompanion.insert(
                id: 'duplicate',
                workspaceId: workspaceId,
                timerSessionId: Value(timerId),
                type: BillableType.hourly,
                title: 'Duplicate',
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'task completion timestamp is stable on retry and clears on reopen',
    () async {
      final workspaceId = await createWorkspace();
      final taskId = await tasks.create(
        workspaceId: workspaceId,
        title: 'Complete me',
      );

      await tasks.update(taskId, status: TaskStatus.done);
      final first = await tasks.watchById(taskId).first;
      expect(first?.completedAt, isNotNull);

      await tasks.update(taskId, status: TaskStatus.done);
      final retry = await tasks.watchById(taskId).first;
      expect(retry?.completedAt, first?.completedAt);

      await tasks.update(taskId, status: TaskStatus.open);
      final reopened = await tasks.watchById(taskId).first;
      expect(reopened?.completedAt, isNull);
    },
  );

  test(
    'note links are idempotent, reparentable, and hide deleted targets',
    () async {
      final workspaceId = await createWorkspace();
      final taskId = await tasks.create(
        workspaceId: workspaceId,
        title: 'Task',
      );
      final projectId = await projects.create(
        workspaceId: workspaceId,
        name: 'Project',
      );
      final noteId = await notes.create(
        workspaceId: workspaceId,
        title: 'Linked note',
        body: 'Body',
      );

      final taskLink = await notes.addLink(noteId, ParentType.task, taskId);
      expect(await notes.addLink(noteId, ParentType.task, taskId), taskLink);
      final projectLink = await notes.addLink(
        noteId,
        ParentType.project,
        projectId,
      );
      expect(await notes.watchLinks(noteId).first, hasLength(2));
      expect(
        (await notes.watchBacklinks(ParentType.task, taskId).first).single.id,
        noteId,
      );

      await notes.update(
        noteId,
        parentType: const Value(ParentType.project),
        parentId: Value(projectId),
      );
      expect(
        (await notes.watchByParent(ParentType.project, projectId).first)
            .single
            .id,
        noteId,
      );

      await tasks.delete(taskId);
      expect(
        await notes.watchBacklinks(ParentType.task, taskId).first,
        isEmpty,
      );
      expect(await notes.watchLinks(noteId).first, hasLength(1));

      await notes.removeLink(noteId, ParentType.project, projectId);
      expect(await notes.watchLinks(noteId).first, isEmpty);
      expect(
        await notes.addLink(noteId, ParentType.project, projectId),
        projectLink,
        reason: 'soft-deleted relationships should be restored, not duplicated',
      );
    },
  );

  test(
    'hourly rates resolve project, pairing, contact, workspace in order',
    () async {
      final workspaceId = await createWorkspace(rateCents: 1000);
      final contactId = await contacts.create(
        name: 'Contact',
        defaultHourlyRateCents: 2000,
      );
      await contacts.setWorkspaceHourlyRate(contactId, workspaceId, 3000);
      final projectId = await projects.create(
        workspaceId: workspaceId,
        name: 'Project',
        contactId: contactId,
        hourlyRateCents: 4000,
      );

      Future<int?> resolve() => billables.resolveHourlyRateCents(
        workspaceId: workspaceId,
        projectId: projectId,
      );

      expect(await resolve(), 4000);
      await projects.update(projectId, hourlyRateCents: const Value(null));
      expect(await resolve(), 3000);
      await contacts.setWorkspaceHourlyRate(contactId, workspaceId, null);
      expect(await resolve(), 2000);
      await contacts.update(
        contactId,
        defaultHourlyRateCents: const Value(null),
      );
      expect(await resolve(), 1000);
    },
  );

  test('financial totals expose separate currency buckets', () async {
    final workspaceId = await createWorkspace();
    final contactId = await contacts.create(name: 'Contact');
    await billables.create(
      workspaceId: workspaceId,
      contactId: contactId,
      type: BillableType.fixed,
      title: 'Euro item',
      amountCents: 1000,
      currency: 'EUR',
    );
    await billables.create(
      workspaceId: workspaceId,
      contactId: contactId,
      type: BillableType.fixed,
      title: 'Dollar item',
      amountCents: 2500,
      currency: 'USD',
    );

    final totals = await billables
        .watchTotalsByCurrencyForContact(contactId)
        .first;
    expect(totals.keys, containsAll(<String>['EUR', 'USD']));
    expect(totals['EUR']?.unbilled, 1000);
    expect(totals['USD']?.unbilled, 2500);
  });
}
