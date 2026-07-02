// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $EventsTable get events => attachedDatabase.events;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $TasksTable get tasks => attachedDatabase.tasks;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
}
