// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_dao.dart';

// ignore_for_file: type=lint
mixin _$ProjectDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $ProjectsTable get projects => attachedDatabase.projects;
  ProjectDaoManager get managers => ProjectDaoManager(this);
}

class ProjectDaoManager {
  final _$ProjectDaoMixin _db;
  ProjectDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
}
