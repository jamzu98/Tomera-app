import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'daos/billable_dao.dart';
import 'daos/contact_dao.dart';
import 'daos/event_dao.dart';
import 'daos/note_dao.dart';
import 'daos/project_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/task_dao.dart';
import 'daos/timer_dao.dart';
import 'daos/workspace_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'converters.dart';
export 'enums.dart';

part 'database.g.dart';

/// Legacy preset workspace colors remapped onto the nearest accent of the
/// warm-redesign palette (see `workspace_style.dart`). Used by migration v4.
const _legacyColorRemap = <int, int>{
  0xFF00696B: 0xFF23A896, // teal -> teal
  0xFF1565C0: 0xFF5B9BD6, // blue -> sky
  0xFF3949AB: 0xFF7C7FF2, // indigo -> indigo
  0xFF6A1B9A: 0xFFC169B4, // purple -> plum
  0xFFAD1457: 0xFFD46BB0, // pink -> pink
  0xFFC62828: 0xFFEE6A4E, // red -> coral
  0xFFE65100: 0xFFE4AB3C, // orange -> amber
  0xFF795548: 0xFFB7AD9C, // brown -> stone
  0xFF2E7D32: 0xFF7BB03A, // green -> green
  0xFF546E7A: 0xFFB7AD9C, // blue grey -> stone
};

@DriftDatabase(
  include: {'notes_fts.drift'},
  tables: [
    Workspaces,
    Contacts,
    WorkspaceContacts,
    Projects,
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
    ProjectDao,
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
  int get schemaVersion => 4;

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
          if (from < 3) {
            // v3: projects and their links.
            await m.createTable(projects);
            await m.addColumn(events, events.projectId);
            await m.addColumn(tasks, tasks.projectId);
            await m.addColumn(billableItems, billableItems.projectId);
          }
          if (from < 4) {
            // v4: warm redesign — remap legacy preset workspace/project
            // colors onto the nearest new-palette accent.
            for (final entry in _legacyColorRemap.entries) {
              await customStatement(
                  'UPDATE workspaces SET color = ${entry.value} '
                  'WHERE color = ${entry.key}');
              await customStatement(
                  'UPDATE projects SET color = ${entry.value} '
                  'WHERE color = ${entry.key}');
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
