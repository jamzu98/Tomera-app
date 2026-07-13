// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_dao.dart';

// ignore_for_file: type=lint
mixin _$EventDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ProjectsTable get projects => attachedDatabase.projects;
  $EventSeriesTableTable get eventSeriesTable =>
      attachedDatabase.eventSeriesTable;
  $EventsTable get events => attachedDatabase.events;
  $EventContactsTable get eventContacts => attachedDatabase.eventContacts;
  $EventSeriesContactsTable get eventSeriesContacts =>
      attachedDatabase.eventSeriesContacts;
  $RemindersTable get reminders => attachedDatabase.reminders;
  EventDaoManager get managers => EventDaoManager(this);
}

class EventDaoManager {
  final _$EventDaoMixin _db;
  EventDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$EventSeriesTableTableTableManager get eventSeriesTable =>
      $$EventSeriesTableTableTableManager(
        _db.attachedDatabase,
        _db.eventSeriesTable,
      );
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$EventContactsTableTableManager get eventContacts =>
      $$EventContactsTableTableManager(_db.attachedDatabase, _db.eventContacts);
  $$EventSeriesContactsTableTableManager get eventSeriesContacts =>
      $$EventSeriesContactsTableTableManager(
        _db.attachedDatabase,
        _db.eventSeriesContacts,
      );
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
}
