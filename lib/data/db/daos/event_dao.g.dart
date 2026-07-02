// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_dao.dart';

// ignore_for_file: type=lint
mixin _$EventDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $EventsTable get events => attachedDatabase.events;
  EventDaoManager get managers => EventDaoManager(this);
}

class EventDaoManager {
  final _$EventDaoMixin _db;
  EventDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
}
