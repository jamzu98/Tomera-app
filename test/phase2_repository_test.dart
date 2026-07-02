import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/billable_repository.dart';
import 'package:tomera/data/repositories/contact_repository.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late ContactRepository contacts;
  late BillableRepository billables;
  late EventRepository events;
  late TaskRepository tasks;
  late NoteRepository notes;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    contacts = ContactRepository(db.contactDao);
    billables = BillableRepository(db.billableDao);
    events = EventRepository(db.eventDao);
    tasks = TaskRepository(db.taskDao);
    notes = NoteRepository(db.noteDao);
  });

  tearDown(() => db.close());

  Future<String> createWorkspace({String name = 'DEV'}) => workspaces.create(
        name: name,
        color: 0xFF000000,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );

  group('ContactRepository', () {
    test('create with default rate and watch ordered by name', () async {
      await contacts.create(name: 'Bob');
      await contacts.create(name: 'Alice', defaultHourlyRateCents: 6500);
      final all = await contacts.watchAll().first;
      expect(all.map((c) => c.name), ['Alice', 'Bob']);
      expect(all.first.defaultHourlyRateCents, 6500);
    });

    test('role labels: upsert updates, remove soft-deletes', () async {
      final workspaceId = await createWorkspace();
      final contactId = await contacts.create(name: 'Alice');

      await contacts.setRole(contactId, workspaceId, 'client');
      var roles = await contacts.getRoles(contactId);
      expect(roles.single.roleLabel, 'client');

      await contacts.setRole(contactId, workspaceId, 'partner');
      roles = await contacts.getRoles(contactId);
      expect(roles.single.roleLabel, 'partner');

      await contacts.removeRole(contactId, workspaceId);
      expect(await contacts.getRoles(contactId), isEmpty);
      // The row is kept, only soft-deleted (spec §5).
      expect((await db.select(db.workspaceContacts).get()).single.deletedAt,
          isNotNull);
    });

    test('watchAll with workspaceId returns only linked contacts', () async {
      final w1 = await createWorkspace(name: 'A');
      final linked = await contacts.create(name: 'Linked');
      await contacts.create(name: 'Unlinked');
      await contacts.setRole(linked, w1, null);

      final inWorkspace = await contacts.watchAll(workspaceId: w1).first;
      expect(inWorkspace.map((c) => c.name), ['Linked']);
      expect(await contacts.watchAll().first, hasLength(2));
    });
  });

  group('BillableRepository', () {
    test('per-contact totals aggregate by status', () async {
      final workspaceId = await createWorkspace();
      final contactId = await contacts.create(name: 'Alice');

      await billables.create(
        workspaceId: workspaceId,
        contactId: contactId,
        type: BillableType.hourly,
        title: 'unbilled hourly',
        rateCents: 6000,
        durationMinutes: 90,
      );
      await billables.create(
        workspaceId: workspaceId,
        contactId: contactId,
        type: BillableType.fixed,
        title: 'invoiced fixed',
        amountCents: 2500,
        status: BillableStatus.invoiced,
      );
      await billables.create(
        workspaceId: workspaceId,
        type: BillableType.fixed,
        title: 'other contact',
        amountCents: 99999,
      );

      final totals = await billables.watchTotalsForContact(contactId).first;
      expect(totals.unbilled, 9000);
      expect(totals.invoiced, 2500);
      expect(totals.paid, 0);
    });

    test('cycleStatus progresses unbilled → invoiced → paid → unbilled',
        () async {
      final workspaceId = await createWorkspace();
      final id = await billables.create(
        workspaceId: workspaceId,
        type: BillableType.fixed,
        title: 'B',
        amountCents: 100,
      );

      Future<BillableItem> current() async =>
          (await billables.watchById(id).first)!;
      expect((await current()).status, BillableStatus.unbilled);
      await billables.cycleStatus(await current());
      expect((await current()).status, BillableStatus.invoiced);
      await billables.cycleStatus(await current());
      expect((await current()).status, BillableStatus.paid);
      await billables.cycleStatus(await current());
      expect((await current()).status, BillableStatus.unbilled);
    });
  });

  group('event contacts', () {
    test('setContacts diffs links and soft-deletes removals', () async {
      final workspaceId = await createWorkspace();
      final alice = await contacts.create(name: 'Alice');
      final bob = await contacts.create(name: 'Bob');
      final eventId = await events.create(
          workspaceId: workspaceId, title: 'E', startsAt: 0, endsAt: 1);

      await events.setContacts(eventId, {alice, bob});
      expect(await events.watchContactIds(eventId).first, {alice, bob});

      await events.setContacts(eventId, {bob});
      expect(await events.watchContactIds(eventId).first, {bob});

      final aliceEvents = await events.watchForContact(alice).first;
      expect(aliceEvents, isEmpty);
      final bobEvents = await events.watchForContact(bob).first;
      expect(bobEvents.single.id, eventId);
    });
  });

  group('reminders', () {
    test('upsert replaces the active reminder, remove soft-deletes it',
        () async {
      final dao = db.reminderDao;
      await dao.upsertForParent(ParentType.event, 'e1', 1000);
      var reminder = await dao.getActiveByParent(ParentType.event, 'e1');
      expect(reminder!.fireAt, 1000);

      await dao.upsertForParent(ParentType.event, 'e1', 2000);
      reminder = await dao.getActiveByParent(ParentType.event, 'e1');
      expect(reminder!.fireAt, 2000);
      // Still a single row: the upsert updated in place.
      expect(await db.select(db.reminders).get(), hasLength(1));

      await dao.removeForParent(ParentType.event, 'e1');
      expect(await dao.getActiveByParent(ParentType.event, 'e1'), isNull);
      expect((await db.select(db.reminders).get()).single.deletedAt,
          isNotNull);
    });
  });

  group('contact links on tasks and notes', () {
    test('tasks watchForContact and notes watchByParent', () async {
      final workspaceId = await createWorkspace();
      final contactId = await contacts.create(name: 'Alice');

      await tasks.create(
          workspaceId: workspaceId, title: 'for alice', contactId: contactId);
      await tasks.create(workspaceId: workspaceId, title: 'unlinked');
      final linkedTasks = await tasks.watchForContact(contactId).first;
      expect(linkedTasks.single.title, 'for alice');

      await notes.create(
        title: 'about alice',
        body: '',
        parentType: ParentType.contact,
        parentId: contactId,
      );
      await notes.create(title: 'standalone', body: '');
      final linkedNotes =
          await notes.watchByParent(ParentType.contact, contactId).first;
      expect(linkedNotes.single.title, 'about alice');
    });
  });
}
