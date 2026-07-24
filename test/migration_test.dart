import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';

import 'generated_schema.dart/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('historical schema migrations', () {
    for (final fromVersion in GeneratedHelper.versions.where((v) => v < 8)) {
      test('v$fromVersion migrates to v8', () async {
        final schema = await verifier.schemaAt(fromVersion);
        addTearDown(schema.close);
        final db = AppDatabase(schema.newConnection());

        await verifier.migrateAndValidate(db, 8);
        await db.close();
      });
    }

    test(
      'v4 duplicate active rows are normalized before unique indexes',
      () async {
        final schema = await verifier.schemaAt(4);
        addTearDown(schema.close);
        final raw = schema.rawDatabase;

        raw.execute('''
        INSERT INTO workspaces
          (id, created_at, updated_at, name, color, icon, enabled_modules)
        VALUES ('w', 1, 1, 'Workspace', 0, 'work', 'calendar')
      ''');
        raw.execute('''
        INSERT INTO contacts (id, created_at, updated_at, name)
        VALUES ('c', 1, 1, 'Contact')
      ''');
        for (final id in ['wc1', 'wc2']) {
          raw.execute(
            '''
          INSERT INTO workspace_contacts
            (id, created_at, updated_at, workspace_id, contact_id)
          VALUES (?, 1, 1, 'w', 'c')
        ''',
            [id],
          );
        }
        for (final id in ['r1', 'r2']) {
          raw.execute(
            '''
          INSERT INTO reminders
            (id, created_at, updated_at, parent_type, parent_id, fire_at)
          VALUES (?, 1, 1, 'workspace', 'w', 10)
        ''',
            [id],
          );
        }
        raw.execute('''
        INSERT INTO timer_sessions
          (id, created_at, updated_at, workspace_id, started_at)
        VALUES ('old', 1, 1, 'w', 100)
      ''');
        raw.execute('''
        INSERT INTO timer_sessions
          (id, created_at, updated_at, workspace_id, started_at)
        VALUES ('new', 2, 2, 'w', 200)
      ''');

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 8);

        final activeRoles = await db.customSelect('''
        SELECT id FROM workspace_contacts WHERE deleted_at IS NULL
      ''').get();
        final activeReminders = await db.customSelect('''
        SELECT id FROM reminders WHERE deleted_at IS NULL
      ''').get();
        final running = await db.customSelect('''
        SELECT id FROM timer_sessions WHERE deleted_at IS NULL
          AND stopped_at IS NULL
      ''').get();

        expect(activeRoles, hasLength(1));
        expect(activeReminders, hasLength(1));
        expect(running.single.read<String>('id'), 'new');
        expect(
          (await db
                  .customSelect(
                    "SELECT stopped_at FROM timer_sessions WHERE id = 'old'",
                  )
                  .getSingle())
              .read<int>('stopped_at'),
          100,
        );

        await db.close();
      },
    );

    test('v5 data survives v8 and done tasks receive a timestamp', () async {
      final schema = await verifier.schemaAt(5);
      addTearDown(schema.close);
      final raw = schema.rawDatabase;
      raw.execute('''
        INSERT INTO workspaces
          (id, created_at, updated_at, name, color, icon, enabled_modules)
        VALUES ('w', 1, 10, 'Workspace', 0, 'work', 'tasks,finance')
      ''');
      raw.execute('''
        INSERT INTO tasks
          (id, created_at, updated_at, workspace_id, title, status, priority)
        VALUES ('t', 2, 20, 'w', 'Done task', 'done', 'normal')
      ''');
      raw.execute('''
        INSERT INTO timer_sessions
          (id, created_at, updated_at, workspace_id, started_at, stopped_at)
        VALUES ('timer', 3, 30, 'w', 100, 200)
      ''');

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);

      final task = await db
          .customSelect("SELECT title, completed_at FROM tasks WHERE id = 't'")
          .getSingle();
      expect(task.read<String>('title'), 'Done task');
      expect(task.read<int>('completed_at'), 20);
      final timer = await db
          .customSelect(
            "SELECT project_id FROM timer_sessions WHERE id = 'timer'",
          )
          .getSingle();
      expect(timer.readNullable<String>('project_id'), isNull);
      final indexes = await db
          .customSelect("SELECT name FROM sqlite_schema WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'note_links_active_unique',
          'note_links_active_target',
          'billable_items_active_timer_session',
        ]),
      );

      await db.close();
    });

    test('v6 event and task rows survive recurrence migration', () async {
      final schema = await verifier.schemaAt(6);
      addTearDown(schema.close);
      final raw = schema.rawDatabase;
      raw.execute('''
        INSERT INTO workspaces
          (id, created_at, updated_at, name, color, icon, enabled_modules)
        VALUES ('w', 1, 1, 'Workspace', 0, 'work', 'calendar,tasks')
      ''');
      raw.execute('''
        INSERT INTO events
          (id, created_at, updated_at, workspace_id, title, starts_at, ends_at)
        VALUES ('event', 2, 2, 'w', 'Existing event', 100, 200)
      ''');
      raw.execute('''
        INSERT INTO tasks
          (id, created_at, updated_at, workspace_id, title)
        VALUES ('task', 3, 3, 'w', 'Existing task')
      ''');

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);

      final event = await db.customSelect('''
        SELECT title, series_id, occurrence_key, recurrence_suppressed
        FROM events WHERE id = 'event'
      ''').getSingle();
      expect(event.read<String>('title'), 'Existing event');
      expect(event.readNullable<String>('series_id'), isNull);
      expect(event.readNullable<String>('occurrence_key'), isNull);
      expect(event.read<bool>('recurrence_suppressed'), isFalse);
      final task = await db.customSelect('''
        SELECT title, task_series_id, task_occurrence_number
        FROM tasks WHERE id = 'task'
      ''').getSingle();
      expect(task.read<String>('title'), 'Existing task');
      expect(task.readNullable<String>('task_series_id'), isNull);
      expect(task.readNullable<int>('task_occurrence_number'), isNull);

      final objects = await db.customSelect('''
        SELECT name FROM sqlite_schema
        WHERE type IN ('table', 'index')
      ''').get();
      expect(
        objects.map((row) => row.read<String>('name')),
        containsAll(<String>[
          'event_series',
          'task_series',
          'events_series_occurrence_unique',
          'tasks_series_occurrence_unique',
        ]),
      );
      await db.close();
    });
  });
}
