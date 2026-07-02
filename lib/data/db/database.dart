import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'daos/billable_dao.dart';
import 'daos/contact_dao.dart';
import 'daos/event_dao.dart';
import 'daos/note_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/task_dao.dart';
import 'daos/timer_dao.dart';
import 'daos/workspace_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'converters.dart';
export 'enums.dart';

part 'database.g.dart';

@DriftDatabase(
  include: {'notes_fts.drift'},
  tables: [
    Workspaces,
    Contacts,
    WorkspaceContacts,
    Events,
    EventContacts,
    Tasks,
    Notes,
    BillableItems,
    TimerSessions,
    Reminders,
  ],
  daos: [
    WorkspaceDao,
    TaskDao,
    NoteDao,
    EventDao,
    ContactDao,
    BillableDao,
    ReminderDao,
    TimerDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Takes an explicit executor so tests can pass an in-memory database.
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(
        name: 'tomera',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: FTS5 index over notes (spec §6.4), backfilled from
            // existing rows.
            await m.createTable(notesFts);
            await m.createTrigger(notesFtsInsert);
            await m.createTrigger(notesFtsDelete);
            await m.createTrigger(notesFtsUpdate);
            await customStatement(
                'INSERT INTO notes_fts(rowid, title, body) '
                'SELECT rowid, title, body FROM notes');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
