// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billable_dao.dart';

// ignore_for_file: type=lint
mixin _$BillableDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ProjectsTable get projects => attachedDatabase.projects;
  $EventsTable get events => attachedDatabase.events;
  $BillableItemsTable get billableItems => attachedDatabase.billableItems;
  BillableDaoManager get managers => BillableDaoManager(this);
}

class BillableDaoManager {
  final _$BillableDaoMixin _db;
  BillableDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$BillableItemsTableTableManager get billableItems =>
      $$BillableItemsTableTableManager(_db.attachedDatabase, _db.billableItems);
}
