import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'daos/billable_dao.dart';
import 'daos/contact_dao.dart';
import 'daos/event_dao.dart';
import 'daos/note_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/task_dao.dart';
import 'daos/workspace_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'converters.dart';
export 'enums.dart';

part 'database.g.dart';

@DriftDatabase(
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
