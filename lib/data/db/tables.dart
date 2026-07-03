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

class Workspaces extends Table with SyncColumns {
  TextColumn get name => text()();

  /// ARGB color value.
  IntColumn get color => integer()();

  /// Material icon name (looked up from a curated map in the UI).
  TextColumn get icon => text()();
  TextColumn get enabledModules => text().map(const ModuleSetConverter())();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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
class WorkspaceContacts extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
  TextColumn get roleLabel => text().nullable()();
}

/// Groups related work — a lecture course, a client gig, a maintenance
/// contract. Events/tasks/billables link via nullable projectId columns;
/// notes via ParentType.project. Added in schema v3.
class Projects extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// ARGB; null inherits the workspace color.
  IntColumn get color => integer().nullable()();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

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
}

class EventContacts extends Table with SyncColumns {
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
}

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
}

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

/// All money is stored as integer cents. Never floats (spec §4).
class BillableItems extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get eventId => text().nullable().references(Events, #id)();
  TextColumn get type => text().map(const DbEnumConverter(BillableType.values))();
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

class TimerSessions extends Table with SyncColumns {
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get description => text().nullable()();
  IntColumn get startedAt => integer()();

  /// Null while the timer is running.
  IntColumn get stoppedAt => integer().nullable()();
}

class Reminders extends Table with SyncColumns {
  TextColumn get parentType =>
      text().map(const DbEnumConverter(ParentType.values))();
  TextColumn get parentId => text()();
  IntColumn get fireAt => integer()();
  BoolColumn get delivered => boolean().withDefault(const Constant(false))();
}
