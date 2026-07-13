// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ProjectsTable get projects => attachedDatabase.projects;
  $EventSeriesTableTable get eventSeriesTable =>
      attachedDatabase.eventSeriesTable;
  $EventsTable get events => attachedDatabase.events;
  $TaskSeriesTableTable get taskSeriesTable => attachedDatabase.taskSeriesTable;
  $TasksTable get tasks => attachedDatabase.tasks;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
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
  $$TaskSeriesTableTableTableManager get taskSeriesTable =>
      $$TaskSeriesTableTableTableManager(
        _db.attachedDatabase,
        _db.taskSeriesTable,
      );
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
}
