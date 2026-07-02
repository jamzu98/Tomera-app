// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_dao.dart';

// ignore_for_file: type=lint
mixin _$ContactDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $WorkspacesTable get workspaces => attachedDatabase.workspaces;
  $WorkspaceContactsTable get workspaceContacts =>
      attachedDatabase.workspaceContacts;
  ContactDaoManager get managers => ContactDaoManager(this);
}

class ContactDaoManager {
  final _$ContactDaoMixin _db;
  ContactDaoManager(this._db);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db.attachedDatabase, _db.workspaces);
  $$WorkspaceContactsTableTableManager get workspaceContacts =>
      $$WorkspaceContactsTableTableManager(
        _db.attachedDatabase,
        _db.workspaceContacts,
      );
}
