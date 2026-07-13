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
    EventSeriesTable,
    EventSeriesContacts,
    Events,
    EventContacts,
    TaskSeriesTable,
    Tasks,
    Notes,
    NoteLinks,
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

  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'tomera',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  /// Writes a transactionally consistent, standalone SQLite snapshot.
  ///
  /// SQLite performs the copy itself, so this remains safe if the live
  /// database uses a journal/WAL. [destinationPath] must not already exist.
  Future<void> createSnapshot(String destinationPath) =>
      customStatement('VACUUM INTO ?', [destinationPath]);

  @override
  int get schemaVersion => 7;

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
          'SELECT rowid, title, body FROM notes',
        );
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
            'WHERE color = ${entry.key}',
          );
          await customStatement(
            'UPDATE projects SET color = ${entry.value} '
            'WHERE color = ${entry.key}',
          );
        }
      }
      if (from < 5) {
        // v5: query indexes and database-level guardrails for invariants
        // that were previously enforced only by repositories. Clean up
        // any legacy duplicates before adding the partial unique indexes.
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;

        await customStatement(
          'UPDATE workspace_contacts '
          'SET deleted_at = $now, updated_at = $now, is_dirty = 1 '
          'WHERE deleted_at IS NULL AND rowid NOT IN ('
          'SELECT MAX(rowid) FROM workspace_contacts '
          'WHERE deleted_at IS NULL GROUP BY workspace_id, contact_id)',
        );
        await customStatement(
          'UPDATE event_contacts '
          'SET deleted_at = $now, updated_at = $now, is_dirty = 1 '
          'WHERE deleted_at IS NULL AND rowid NOT IN ('
          'SELECT MAX(rowid) FROM event_contacts '
          'WHERE deleted_at IS NULL GROUP BY event_id, contact_id)',
        );
        await customStatement(
          'UPDATE reminders '
          'SET deleted_at = $now, updated_at = $now, is_dirty = 1 '
          'WHERE deleted_at IS NULL AND rowid NOT IN ('
          'SELECT MAX(rowid) FROM reminders WHERE deleted_at IS NULL '
          'GROUP BY parent_type, parent_id)',
        );
        await customStatement(
          'UPDATE timer_sessions '
          'SET stopped_at = started_at, updated_at = $now, is_dirty = 1 '
          'WHERE deleted_at IS NULL AND stopped_at IS NULL AND id NOT IN ('
          'SELECT id FROM timer_sessions '
          'WHERE deleted_at IS NULL AND stopped_at IS NULL '
          'ORDER BY started_at DESC, created_at DESC, id DESC LIMIT 1)',
        );

        for (final statement in _schemaV5Indexes) {
          await customStatement(statement);
        }
      }
      if (from < 6) {
        // v6: connected-work provenance, note backlinks, completion times,
        // and rate overrides. All additions are nullable for a lossless
        // migration of existing local data.
        if (!await _columnExists('workspaces', 'default_hourly_rate_cents')) {
          await m.addColumn(workspaces, workspaces.defaultHourlyRateCents);
        }
        if (!await _columnExists('workspace_contacts', 'hourly_rate_cents')) {
          await m.addColumn(
            workspaceContacts,
            workspaceContacts.hourlyRateCents,
          );
        }
        // When migrating v1/v2 in one open, v3 creates Projects from the
        // current table definition. Avoid adding the v6 column twice.
        if (!await _columnExists('projects', 'hourly_rate_cents')) {
          await m.addColumn(projects, projects.hourlyRateCents);
        }
        if (!await _columnExists('tasks', 'completed_at')) {
          await m.addColumn(tasks, tasks.completedAt);
        }
        // The exact historical completion instant was not stored before v6;
        // updated_at is the closest durable timestamp for already-done rows.
        await customStatement(
          'UPDATE tasks SET completed_at = updated_at '
          "WHERE status = 'done' AND completed_at IS NULL",
        );
        if (!await _columnExists('timer_sessions', 'project_id')) {
          await m.addColumn(timerSessions, timerSessions.projectId);
        }
        if (!await _columnExists('billable_items', 'task_id')) {
          await m.addColumn(billableItems, billableItems.taskId);
        }
        if (!await _columnExists('billable_items', 'timer_session_id')) {
          await m.addColumn(billableItems, billableItems.timerSessionId);
        }
        await m.createTable(noteLinks);
        await customStatement(
          'CREATE UNIQUE INDEX note_links_active_unique '
          'ON note_links (note_id, target_type, target_id) '
          'WHERE deleted_at IS NULL',
        );
        await customStatement(
          'CREATE INDEX note_links_active_target '
          'ON note_links (target_type, target_id, updated_at DESC) '
          'WHERE deleted_at IS NULL',
        );
        await customStatement(
          'CREATE UNIQUE INDEX billable_items_active_timer_session '
          'ON billable_items (timer_session_id) '
          'WHERE deleted_at IS NULL AND timer_session_id IS NOT NULL',
        );
      }
      if (from < 7) {
        // v7: recurrence templates plus materialized occurrence identity.
        await m.createTable(eventSeriesTable);
        await m.createTable(eventSeriesContacts);
        await m.createTable(taskSeriesTable);

        if (!await _columnExists('events', 'series_id')) {
          await m.addColumn(events, events.seriesId);
        }
        if (!await _columnExists('events', 'occurrence_key')) {
          await m.addColumn(events, events.occurrenceKey);
        }
        if (!await _columnExists('events', 'original_starts_at')) {
          await m.addColumn(events, events.originalStartsAt);
        }
        if (!await _columnExists('events', 'recurrence_exception')) {
          await m.addColumn(events, events.recurrenceException);
        }
        if (!await _columnExists('events', 'recurrence_suppressed')) {
          await m.addColumn(events, events.recurrenceSuppressed);
        }
        if (!await _columnExists('tasks', 'task_series_id')) {
          await m.addColumn(tasks, tasks.taskSeriesId);
        }
        if (!await _columnExists('tasks', 'task_occurrence_number')) {
          await m.addColumn(tasks, tasks.taskOccurrenceNumber);
        }
        if (!await _columnExists('tasks', 'predecessor_task_id')) {
          await m.addColumn(tasks, tasks.predecessorTaskId);
        }
        if (!await _columnExists('tasks', 'recurrence_scheduled_local')) {
          await m.addColumn(tasks, tasks.recurrenceScheduledLocal);
        }

        for (final statement in _schemaV7Indexes) {
          await customStatement(statement);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<bool> _columnExists(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info("$tableName")').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }
}

const _schemaV5Indexes = <String>[
  'CREATE INDEX workspaces_active_sort '
      'ON workspaces (sort_order) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX workspace_contacts_active_unique '
      'ON workspace_contacts (workspace_id, contact_id) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX workspace_contacts_active_contact '
      'ON workspace_contacts (contact_id) WHERE deleted_at IS NULL',
  'CREATE INDEX projects_active_workspace '
      'ON projects (workspace_id, archived, name) WHERE deleted_at IS NULL',
  'CREATE INDEX events_active_workspace_range '
      'ON events (workspace_id, starts_at, ends_at) WHERE deleted_at IS NULL',
  'CREATE INDEX events_active_project '
      'ON events (project_id, starts_at) '
      'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
  'CREATE UNIQUE INDEX event_contacts_active_unique '
      'ON event_contacts (event_id, contact_id) WHERE deleted_at IS NULL',
  'CREATE INDEX event_contacts_active_contact '
      'ON event_contacts (contact_id, event_id) WHERE deleted_at IS NULL',
  'CREATE INDEX tasks_active_workspace_status_due '
      'ON tasks (workspace_id, status, due_at) WHERE deleted_at IS NULL',
  'CREATE INDEX tasks_active_project '
      'ON tasks (project_id, due_at) '
      'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
  'CREATE INDEX tasks_active_contact '
      'ON tasks (contact_id, due_at) '
      'WHERE deleted_at IS NULL AND contact_id IS NOT NULL',
  'CREATE INDEX notes_active_workspace_updated '
      'ON notes (workspace_id, updated_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX notes_active_parent_updated '
      'ON notes (parent_type, parent_id, updated_at DESC) '
      'WHERE deleted_at IS NULL AND parent_id IS NOT NULL',
  'CREATE INDEX billable_items_active_workspace_status '
      'ON billable_items (workspace_id, status, created_at DESC) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX billable_items_active_contact '
      'ON billable_items (contact_id, created_at DESC) '
      'WHERE deleted_at IS NULL AND contact_id IS NOT NULL',
  'CREATE INDEX billable_items_active_project '
      'ON billable_items (project_id, created_at DESC) '
      'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
  'CREATE UNIQUE INDEX timer_sessions_single_running '
      'ON timer_sessions ((1)) '
      'WHERE deleted_at IS NULL AND stopped_at IS NULL',
  'CREATE UNIQUE INDEX reminders_active_parent '
      'ON reminders (parent_type, parent_id) WHERE deleted_at IS NULL',
];

const _schemaV7Indexes = <String>[
  'CREATE INDEX event_series_active_workspace '
      'ON event_series (workspace_id, updated_at DESC) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX event_series_contacts_active_unique '
      'ON event_series_contacts (series_id, contact_id) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX task_series_active_workspace '
      'ON task_series (workspace_id, updated_at DESC) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX events_active_series_start '
      'ON events (series_id, starts_at) '
      'WHERE deleted_at IS NULL AND series_id IS NOT NULL',
  'CREATE UNIQUE INDEX events_series_occurrence_unique '
      'ON events (series_id, occurrence_key) '
      'WHERE series_id IS NOT NULL AND occurrence_key IS NOT NULL',
  'CREATE UNIQUE INDEX tasks_series_occurrence_unique '
      'ON tasks (task_series_id, task_occurrence_number) '
      'WHERE task_series_id IS NOT NULL AND task_occurrence_number IS NOT NULL',
];
