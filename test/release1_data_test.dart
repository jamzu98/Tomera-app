import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/billable_repository.dart';
import 'package:tomera/data/repositories/contact_repository.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/project_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';
import 'package:tomera/features/settings/settings_providers.dart';

void main() {
  group('v5 data guardrails', () {
    late AppDatabase db;
    late WorkspaceRepository workspaces;
    late ContactRepository contacts;
    late ProjectRepository projects;
    late TaskRepository tasks;
    late NoteRepository notes;
    late EventRepository events;
    late BillableRepository billables;

    setUp(() {
      db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      workspaces = WorkspaceRepository(db.workspaceDao);
      contacts = ContactRepository(db.contactDao);
      projects = ProjectRepository(db.projectDao);
      tasks = TaskRepository(db.taskDao);
      notes = NoteRepository(db.noteDao);
      events = EventRepository(db.eventDao);
      billables = BillableRepository(db.billableDao);
    });

    tearDown(() => db.close());

    Future<String> createWorkspace() => workspaces.create(
      name: 'Workspace',
      color: 0,
      icon: 'work',
      enabledModules: {...ModuleKey.values},
    );

    test(
      'task, note, event, and billable soft-deletes can be restored',
      () async {
        final workspaceId = await createWorkspace();
        final taskId = await tasks.create(
          workspaceId: workspaceId,
          title: 'Task',
        );
        final noteId = await notes.create(
          workspaceId: workspaceId,
          title: 'Note',
          body: '',
        );
        final eventId = await events.create(
          workspaceId: workspaceId,
          title: 'Event',
          startsAt: 1,
          endsAt: 2,
        );
        final billableId = await billables.create(
          workspaceId: workspaceId,
          type: BillableType.fixed,
          title: 'Billable',
          amountCents: 100,
        );

        await tasks.delete(taskId);
        await notes.delete(noteId);
        await events.delete(eventId);
        await billables.delete(billableId);
        expect(await tasks.watchById(taskId).first, isNull);
        expect(await notes.watchById(noteId).first, isNull);
        expect(await events.watchById(eventId).first, isNull);
        expect(await billables.watchById(billableId).first, isNull);

        await tasks.restore(taskId);
        await notes.restore(noteId);
        await events.restore(eventId);
        await billables.restore(billableId);
        expect(await tasks.watchById(taskId).first, isNotNull);
        expect(await notes.watchById(noteId).first, isNotNull);
        expect(await events.watchById(eventId).first, isNotNull);
        expect(await billables.watchById(billableId).first, isNotNull);
      },
    );

    test('soft-deleted owning workspace hides its records', () async {
      final workspaceId = await createWorkspace();
      await tasks.create(workspaceId: workspaceId, title: 'Task');
      await notes.create(
        workspaceId: workspaceId,
        title: 'Note',
        body: 'searchable',
      );
      await events.create(
        workspaceId: workspaceId,
        title: 'Event',
        startsAt: 1,
        endsAt: 2,
      );
      await billables.create(
        workspaceId: workspaceId,
        type: BillableType.fixed,
        title: 'Billable',
        amountCents: 100,
      );

      await workspaces.delete(workspaceId);

      expect(await tasks.watchAll().first, isEmpty);
      expect(await notes.watchAll().first, isEmpty);
      expect(await notes.search('searchable').first, isEmpty);
      expect(await events.watchInRange(0, 10).first, isEmpty);
      expect(await billables.watchAll().first, isEmpty);
    });

    test(
      'deleted optional links do not hide work from general lists',
      () async {
        final workspaceId = await createWorkspace();
        final contactId = await contacts.create(name: 'Contact');
        final projectId = await projects.create(
          workspaceId: workspaceId,
          name: 'Project',
          contactId: contactId,
        );
        await tasks.create(
          workspaceId: workspaceId,
          title: 'Task',
          contactId: contactId,
          projectId: projectId,
        );
        await notes.create(
          workspaceId: workspaceId,
          title: 'Note',
          body: '',
          parentType: ParentType.project,
          parentId: projectId,
        );
        await events.create(
          workspaceId: workspaceId,
          title: 'Event',
          startsAt: 1,
          endsAt: 2,
          projectId: projectId,
        );
        await billables.create(
          workspaceId: workspaceId,
          contactId: contactId,
          projectId: projectId,
          type: BillableType.fixed,
          title: 'Billable',
          amountCents: 100,
        );

        await projects.delete(projectId);
        await contacts.delete(contactId);

        expect(await tasks.watchAll().first, hasLength(1));
        expect(await notes.watchAll().first, hasLength(1));
        expect(await events.watchInRange(0, 10).first, hasLength(1));
        expect(await billables.watchAll().first, hasLength(1));
        expect(await tasks.watchForProject(projectId).first, isEmpty);
        expect(
          await notes.watchByParent(ParentType.project, projectId).first,
          isEmpty,
        );
        expect(await events.watchForProject(projectId).first, isEmpty);
        expect(await billables.watchAll(projectId: projectId).first, isEmpty);
        expect(await tasks.watchForContact(contactId).first, isEmpty);
        expect(await billables.watchAll(contactId: contactId).first, isEmpty);
      },
    );

    test(
      'partial unique indexes enforce active links and one running timer',
      () async {
        final workspaceId = await createWorkspace();
        final contactId = await contacts.create(name: 'Contact');
        final now = DateTime.now().millisecondsSinceEpoch;

        await db
            .into(db.workspaceContacts)
            .insert(
              WorkspaceContactsCompanion.insert(
                id: 'role-1',
                workspaceId: workspaceId,
                contactId: contactId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        expect(
          () => db
              .into(db.workspaceContacts)
              .insert(
                WorkspaceContactsCompanion.insert(
                  id: 'role-2',
                  workspaceId: workspaceId,
                  contactId: contactId,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<Exception>()),
        );

        await db
            .into(db.timerSessions)
            .insert(
              TimerSessionsCompanion.insert(
                id: 'timer-1',
                workspaceId: workspaceId,
                startedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        expect(
          () => db
              .into(db.timerSessions)
              .insert(
                TimerSessionsCompanion.insert(
                  id: 'timer-2',
                  workspaceId: workspaceId,
                  startedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('calendar preferences', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('stored values load with safe defaults for invalid data', () async {
      expect(await WeekStartSetting.loadStored(), WeekStart.monday);
      expect(await TimeFormatSetting.loadStored(), TimeFormat.system);

      SharedPreferences.setMockInitialValues({
        'settings.weekStart': 'sunday',
        'settings.timeFormat': 'hour24',
      });
      expect(await WeekStartSetting.loadStored(), WeekStart.sunday);
      expect(await TimeFormatSetting.loadStored(), TimeFormat.hour24);

      SharedPreferences.setMockInitialValues({
        'settings.weekStart': 'invalid',
        'settings.timeFormat': 'invalid',
      });
      expect(await WeekStartSetting.loadStored(), WeekStart.monday);
      expect(await TimeFormatSetting.loadStored(), TimeFormat.system);
    });

    test('notifiers persist changes without a cold-load race', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(weekStartSettingProvider.notifier)
          .set(WeekStart.sunday);
      await container
          .read(timeFormatSettingProvider.notifier)
          .set(TimeFormat.hour12);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(weekStartSettingProvider), WeekStart.sunday);
      expect(container.read(timeFormatSettingProvider), TimeFormat.hour12);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.weekStart'), 'sunday');
      expect(prefs.getString('settings.timeFormat'), 'hour12');
    });

    test('time format resolves system and explicit overrides', () {
      expect(
        TimeFormat.system.resolveUses24Hour(systemUses24Hour: true),
        isTrue,
      );
      expect(
        TimeFormat.system.resolveUses24Hour(systemUses24Hour: false),
        isFalse,
      );
      expect(
        TimeFormat.hour12.resolveUses24Hour(systemUses24Hour: true),
        isFalse,
      );
      expect(
        TimeFormat.hour24.resolveUses24Hour(systemUses24Hour: false),
        isTrue,
      );
      expect(WeekStart.monday.calendarDay, 1);
      expect(WeekStart.sunday.calendarDay, 7);
    });
  });
}
