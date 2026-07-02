import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/timer_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';

void main() {
  late AppDatabase db;
  late WorkspaceRepository workspaces;
  late NoteRepository notes;
  late TimerRepository timers;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = WorkspaceRepository(db.workspaceDao);
    notes = NoteRepository(db.noteDao);
    timers = TimerRepository(db.timerDao, const NoopNotificationService());
  });

  tearDown(() => db.close());

  Future<String> createWorkspace() => workspaces.create(
        name: 'DEV',
        color: 0xFF000000,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );

  group('TimerRepository', () {
    test('start persists a running session; stop finalizes it', () async {
      final workspaceId = await createWorkspace();
      final id = await timers.start(
        workspaceId: workspaceId,
        description: 'work',
        notificationTitle: 'work',
      );

      final running = await timers.getRunning();
      expect(running!.id, id);
      expect(running.stoppedAt, isNull);

      final elapsed = await timers.stop(running);
      expect(elapsed, greaterThanOrEqualTo(0));
      expect(await timers.getRunning(), isNull);
      final row = (await db.select(db.timerSessions).get()).single;
      expect(row.stoppedAt, isNotNull);
      expect(row.isDirty, isTrue);
    });

    test('only one timer can run at a time (v1 constraint)', () async {
      final workspaceId = await createWorkspace();
      await timers.start(workspaceId: workspaceId, notificationTitle: 't');
      expect(
        () => timers.start(workspaceId: workspaceId, notificationTitle: 't'),
        throwsStateError,
      );
    });

    test('stopRunning is a safe no-op without a running timer', () async {
      await timers.stopRunning();
      expect(await timers.getRunning(), isNull);
    });
  });

  group('note FTS search', () {
    test('matches words in title and body, prefix included', () async {
      await notes.create(title: 'Meeting notes', body: 'discussed invoicing');
      await notes.create(title: 'Groceries', body: 'milk and bread');

      expect(
        (await notes.search('invoic').first).single.title,
        'Meeting notes',
      );
      expect((await notes.search('meeting').first), hasLength(1));
      expect(await notes.search('nonexistent').first, isEmpty);
      expect(await notes.search('   ').first, isEmpty);
    });

    test('reflects edits and excludes soft-deleted notes', () async {
      final id = await notes.create(title: 'Draft', body: 'alpha');
      expect(await notes.search('alpha').first, hasLength(1));

      await notes.update(id, body: 'bravo');
      expect(await notes.search('alpha').first, isEmpty);
      expect(await notes.search('bravo').first, hasLength(1));

      await notes.delete(id);
      expect(await notes.search('bravo').first, isEmpty);
    });

    test('quotes in input cannot break the MATCH query', () async {
      await notes.create(title: 'Plain', body: 'text');
      expect(await notes.search('"malformed').first, isEmpty);
    });
  });
}
