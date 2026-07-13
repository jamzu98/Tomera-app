import 'dart:io';

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

  group('schema v1 → current migration', () {
    test(
      'recreates the FTS index, backfills notes, and adds project links',
      () async {
        final dir = await Directory.systemTemp.createTemp('tomera_migration');
        final file = File('${dir.path}/db.sqlite');
        addTearDown(() => dir.delete(recursive: true));

        // Build a database, then strip it back to a v1 shape (no FTS
        // artifacts, no v3 projects table or link columns), user_version 1 —
        // as a Phase 1/2 install would look.
        final v1 = AppDatabase(DatabaseConnection(NativeDatabase(file)));
        final v1Notes = NoteRepository(v1.noteDao);
        await v1Notes.create(title: 'Old note', body: 'legacy content');
        // The database is initially created at the current version, so remove
        // current managed indexes before stripping tables/columns back to v1.
        final managedIndexes = await v1
            .customSelect(
              "SELECT name FROM sqlite_schema WHERE type = 'index' "
              "AND name NOT LIKE 'sqlite_autoindex_%'",
            )
            .get();
        for (final row in managedIndexes) {
          await v1.customStatement('DROP INDEX "${row.read<String>('name')}"');
        }
        await v1.customStatement('DROP TRIGGER notes_fts_insert');
        await v1.customStatement('DROP TRIGGER notes_fts_delete');
        await v1.customStatement('DROP TRIGGER notes_fts_update');
        await v1.customStatement('DROP TABLE notes_fts');
        await v1.customStatement('DROP TABLE projects');
        await v1.customStatement('ALTER TABLE events DROP COLUMN project_id');
        await v1.customStatement('ALTER TABLE tasks DROP COLUMN project_id');
        await v1.customStatement(
          'ALTER TABLE billable_items DROP COLUMN project_id',
        );
        await v1.customStatement('PRAGMA user_version = 1');
        await v1.close();

        // Reopening at the current schemaVersion must run every step.
        final current = AppDatabase(DatabaseConnection(NativeDatabase(file)));
        addTearDown(current.close);
        final currentNotes = NoteRepository(current.noteDao);

        expect(
          (await currentNotes.search('legacy').first).single.title,
          'Old note',
          reason: 'existing rows must be backfilled into the index',
        );
        await currentNotes.create(title: 'New note', body: 'fresh content');
        expect(
          await currentNotes.search('fresh').first,
          hasLength(1),
          reason: 'recreated triggers must index new rows',
        );
        // v3 additions are usable after the migration.
        expect(await current.projectDao.watchAll().first, isEmpty);
        expect(
          await current.customSelect('SELECT project_id FROM events').get(),
          isEmpty,
        );
      },
    );
  });
}
