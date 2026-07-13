import 'package:drift/drift.dart';

import 'converters.dart';
import 'enums.dart';

/// Sync-readiness columns shared by every table (spec §4/§5).
///
/// - UUID v4 primary keys, generated on device.
/// - Soft deletes only: queries must filter `deletedAt IS NULL`.
/// - `updatedAt` bumped and `isDirty` set true on every local write.
/// - `ownerId` unused until the Supabase sync phase.
/// - All timestamps are UTC epoch milliseconds.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE INDEX workspaces_active_sort '
  'ON workspaces (sort_order) WHERE deleted_at IS NULL',
)
class Workspaces extends Table with SyncColumns {
  TextColumn get name => text()();

  /// ARGB color value.
  IntColumn get color => integer()();

  /// Material icon name (looked up from a curated map in the UI).
  TextColumn get icon => text()();
  TextColumn get enabledModules => text().map(const ModuleSetConverter())();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Last-resort hourly rate for work in this workspace. Integer cents.
  IntColumn get defaultHourlyRateCents => integer().nullable()();
}

class Contacts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get organization => text().nullable()();
  TextColumn get notesText => text().nullable()();

  /// Pre-fills new hourly billable items (spec §6.6). Integer cents.
  IntColumn get defaultHourlyRateCents => integer().nullable()();
}

/// Many-to-many between workspaces and contacts, with a per-workspace role
/// (e.g. "student" in Teaching, "client" in DEV).
@TableIndex.sql(
  'CREATE UNIQUE INDEX workspace_contacts_active_unique '
  'ON workspace_contacts (workspace_id, contact_id) '
  'WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX workspace_contacts_active_contact '
  'ON workspace_contacts (contact_id) WHERE deleted_at IS NULL',
)
class WorkspaceContacts extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
  TextColumn get roleLabel => text().nullable()();

  /// Overrides both the contact and workspace defaults for this pairing.
  IntColumn get hourlyRateCents => integer().nullable()();
}

/// Groups related work — a lecture course, a client gig, a maintenance
/// contract. Events/tasks/billables link via nullable projectId columns;
/// notes via ParentType.project. Added in schema v3.
@TableIndex.sql(
  'CREATE INDEX projects_active_workspace '
  'ON projects (workspace_id, archived, name) WHERE deleted_at IS NULL',
)
class Projects extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// ARGB; null inherits the workspace color.
  IntColumn get color => integer().nullable()();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Highest-precedence hourly rate for work assigned to this project.
  IntColumn get hourlyRateCents => integer().nullable()();
}

/// Template and calendar rule for a recurring event series. Occurrences are
/// materialized into [Events] and retain ordinary event ids.
@DataClassName('EventSeriesRecord')
@TableIndex.sql(
  'CREATE INDEX event_series_active_workspace '
  'ON event_series (workspace_id, updated_at DESC) WHERE deleted_at IS NULL',
)
class EventSeriesTable extends Table with SyncColumns {
  @override
  String get tableName => 'event_series';

  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get localStartsAt => text()();
  IntColumn get durationMs => integer()();
  TextColumn get timezoneId => text()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  TextColumn get ruleJson => text()();

  /// Exclusive local occurrence key used when a series is split/deleted.
  TextColumn get endsBeforeLocal => text().nullable()();
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX event_series_contacts_active_unique '
  'ON event_series_contacts (series_id, contact_id) WHERE deleted_at IS NULL',
)
class EventSeriesContacts extends Table with SyncColumns {
  TextColumn get seriesId => text().references(EventSeriesTable, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
}

@TableIndex.sql(
  'CREATE INDEX events_active_workspace_range '
  'ON events (workspace_id, starts_at, ends_at) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX events_active_project '
  'ON events (project_id, starts_at) '
  'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE INDEX events_active_series_start '
  'ON events (series_id, starts_at) '
  'WHERE deleted_at IS NULL AND series_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX events_series_occurrence_unique '
  'ON events (series_id, occurrence_key) '
  'WHERE series_id IS NOT NULL AND occurrence_key IS NOT NULL',
)
class Events extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  IntColumn get startsAt => integer()();
  IntColumn get endsAt => integer()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();

  /// RRULE string; column reserved now, recurrence UI comes later.
  TextColumn get rrule => text().nullable()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get seriesId =>
      text().nullable().references(EventSeriesTable, #id)();
  TextColumn get occurrenceKey => text().nullable()();
  IntColumn get originalStartsAt => integer().nullable()();
  BoolColumn get recurrenceException =>
      boolean().nullable().withDefault(const Constant(false))();
  BoolColumn get recurrenceSuppressed =>
      boolean().nullable().withDefault(const Constant(false))();
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX event_contacts_active_unique '
  'ON event_contacts (event_id, contact_id) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX event_contacts_active_contact '
  'ON event_contacts (contact_id, event_id) WHERE deleted_at IS NULL',
)
class EventContacts extends Table with SyncColumns {
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
}

/// Template and recurrence rule for a repeating task chain. Only one open
/// successor is materialized at a time.
@DataClassName('TaskSeriesRecord')
@TableIndex.sql(
  'CREATE INDEX task_series_active_workspace '
  'ON task_series (workspace_id, updated_at DESC) WHERE deleted_at IS NULL',
)
class TaskSeriesTable extends Table with SyncColumns {
  @override
  String get tableName => 'task_series';

  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text()
      .map(const DbEnumConverter(TaskPriority.values))
      .withDefault(const Constant('normal'))();
  TextColumn get firstDueLocal => text()();
  TextColumn get timezoneId => text()();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  TextColumn get ruleJson => text()();
  TextColumn get repeatAnchor => text()
      .map(const DbEnumConverter(TaskRepeatAnchor.values))
      .withDefault(const Constant('schedule'))();
}

@TableIndex.sql(
  'CREATE INDEX tasks_active_workspace_status_due '
  'ON tasks (workspace_id, status, due_at) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX tasks_active_project '
  'ON tasks (project_id, due_at) '
  'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE INDEX tasks_active_contact '
  'ON tasks (contact_id, due_at) '
  'WHERE deleted_at IS NULL AND contact_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX tasks_series_occurrence_unique '
  'ON tasks (task_series_id, task_occurrence_number) '
  'WHERE task_series_id IS NOT NULL AND task_occurrence_number IS NOT NULL',
)
class Tasks extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()
      .map(const DbEnumConverter(TaskStatus.values))
      .withDefault(const Constant('open'))();
  IntColumn get dueAt => integer().nullable()();
  IntColumn get reminderAt => integer().nullable()();
  TextColumn get eventId => text().nullable().references(Events, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get priority => text()
      .map(const DbEnumConverter(TaskPriority.values))
      .withDefault(const Constant('normal'))();
  TextColumn get projectId => text().nullable().references(Projects, #id)();

  /// Set on the transition to done and cleared if the task is reopened.
  IntColumn get completedAt => integer().nullable()();
  TextColumn get taskSeriesId =>
      text().nullable().references(TaskSeriesTable, #id)();
  IntColumn get taskOccurrenceNumber => integer().nullable()();
  TextColumn get predecessorTaskId =>
      text().nullable().references(Tasks, #id)();
  TextColumn get recurrenceScheduledLocal => text().nullable()();
}

@TableIndex.sql(
  'CREATE INDEX notes_active_workspace_updated '
  'ON notes (workspace_id, updated_at DESC) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX notes_active_parent_updated '
  'ON notes (parent_type, parent_id, updated_at DESC) '
  'WHERE deleted_at IS NULL AND parent_id IS NOT NULL',
)
class Notes extends Table with SyncColumns {
  /// Nullable so a note can exist standalone, outside any workspace.
  TextColumn get workspaceId => text().nullable().references(Workspaces, #id)();
  TextColumn get title => text()();

  /// Markdown source.
  TextColumn get body => text()();
  TextColumn get parentType =>
      text().map(const DbEnumConverter(ParentType.values)).nullable()();
  TextColumn get parentId => text().nullable()();
}

/// Additional typed references from a note to workspace records. The original
/// parent columns remain the note's primary context; these links provide
/// backlinks and allow one note to reference multiple records.
@TableIndex.sql(
  'CREATE UNIQUE INDEX note_links_active_unique '
  'ON note_links (note_id, target_type, target_id) WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX note_links_active_target '
  'ON note_links (target_type, target_id, updated_at DESC) '
  'WHERE deleted_at IS NULL',
)
class NoteLinks extends Table with SyncColumns {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get targetType =>
      text().map(const DbEnumConverter(ParentType.values))();
  TextColumn get targetId => text()();
}

/// All money is stored as integer cents. Never floats (spec §4).
@TableIndex.sql(
  'CREATE INDEX billable_items_active_workspace_status '
  'ON billable_items (workspace_id, status, created_at DESC) '
  'WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX billable_items_active_contact '
  'ON billable_items (contact_id, created_at DESC) '
  'WHERE deleted_at IS NULL AND contact_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE INDEX billable_items_active_project '
  'ON billable_items (project_id, created_at DESC) '
  'WHERE deleted_at IS NULL AND project_id IS NOT NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX billable_items_active_timer_session '
  'ON billable_items (timer_session_id) '
  'WHERE deleted_at IS NULL AND timer_session_id IS NOT NULL',
)
class BillableItems extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get eventId => text().nullable().references(Events, #id)();
  TextColumn get taskId => text().nullable().references(Tasks, #id)();
  TextColumn get timerSessionId =>
      text().nullable().references(TimerSessions, #id)();
  TextColumn get type =>
      text().map(const DbEnumConverter(BillableType.values))();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// Hourly rate in cents; used when [type] is hourly.
  IntColumn get rateCents => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();

  /// Fixed amount in cents; used when [type] is fixed.
  IntColumn get amountCents => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('EUR'))();
  TextColumn get status => text()
      .map(const DbEnumConverter(BillableStatus.values))
      .withDefault(const Constant('unbilled'))();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX timer_sessions_single_running '
  'ON timer_sessions ((1)) '
  'WHERE deleted_at IS NULL AND stopped_at IS NULL',
)
class TimerSessions extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get description => text().nullable()();
  IntColumn get startedAt => integer()();

  /// Null while the timer is running.
  IntColumn get stoppedAt => integer().nullable()();
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX reminders_active_parent '
  'ON reminders (parent_type, parent_id) WHERE deleted_at IS NULL',
)
class Reminders extends Table with SyncColumns {
  TextColumn get parentType =>
      text().map(const DbEnumConverter(ParentType.values))();
  TextColumn get parentId => text()();
  IntColumn get fireAt => integer()();
  BoolColumn get delivered => boolean().withDefault(const Constant(false))();
}
