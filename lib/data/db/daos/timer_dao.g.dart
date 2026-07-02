// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_dao.dart';

// ignore_for_file: type=lint
mixin _$TimerDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $ContactsTable get contacts => attachedDatabase.contacts;
  $TimerSessionsTable get timerSessions => attachedDatabase.timerSessions;
  TimerDaoManager get managers => TimerDaoManager(this);
}

class TimerDaoManager {
  final _$TimerDaoMixin _db;
  TimerDaoManager(this._db);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$TimerSessionsTableTableManager get timerSessions =>
      $$TimerSessionsTableTableManager(_db.attachedDatabase, _db.timerSessions);
}
