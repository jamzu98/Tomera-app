import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tomera/features/settings/backup/backup_database_validator.dart';

import 'generated_schema.dart/schema.dart';

void main() {
  test('real backup validator migrates a v5 database to v7', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tomera-backup-validator-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/restored.sqlite';

    final verifier = SchemaVerifier(GeneratedHelper());
    final oldSchema = await verifier.schemaAt(5);
    oldSchema.rawDatabase.execute('''
      INSERT INTO workspaces
        (id, created_at, updated_at, name, color, icon, enabled_modules)
      VALUES ('workspace', 1, 10, 'Migrated workspace', 0, 'work',
        'tasks,calendar')
    ''');
    oldSchema.rawDatabase.execute('''
      INSERT INTO tasks
        (id, created_at, updated_at, workspace_id, title, status, priority)
      VALUES ('task', 2, 20, 'workspace', 'Migrated task', 'done', 'normal')
    ''');

    final fileDatabase = sqlite.sqlite3.open(databasePath);
    await oldSchema.rawDatabase.backup(fileDatabase, nPage: -1).drain<void>();
    fileDatabase.close();
    oldSchema.close();

    await validateAndMigrateBackupDatabase(
      databasePath,
      currentSchemaVersion: 7,
    );

    final migrated = sqlite.sqlite3.open(
      databasePath,
      mode: sqlite.OpenMode.readOnly,
    );
    addTearDown(migrated.close);
    expect(migrated.select('PRAGMA user_version').single.values.single, 7);
    final task = migrated.select('''
      SELECT title, completed_at, task_series_id
      FROM tasks WHERE id = 'task'
    ''').single;
    expect(task['title'], 'Migrated task');
    expect(task['completed_at'], 20);
    expect(task['task_series_id'], isNull);
    expect(
      migrated
          .select(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name IN ('event_series', 'task_series', 'note_links')",
          )
          .map((row) => row['name']),
      containsAll(<String>['event_series', 'task_series', 'note_links']),
    );
    expect(
      migrated.select('PRAGMA integrity_check').single.values.single,
      'ok',
    );
    expect(migrated.select('PRAGMA foreign_key_check'), isEmpty);
  });
}
