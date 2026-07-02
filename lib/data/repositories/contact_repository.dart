import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/contact_dao.dart';
import '../db/database.dart';

/// The only layer contact widgets talk to (via providers).
class ContactRepository {
  ContactRepository(this._dao);

  final ContactDao _dao;

  Stream<List<Contact>> watchAll({String? workspaceId}) => workspaceId == null
      ? _dao.watchAll()
      : _dao.watchInWorkspace(workspaceId);

  Stream<Contact?> watchById(String id) => _dao.watchById(id);

  Future<Contact?> getById(String id) => _dao.getById(id);

  Future<String> create({
    required String name,
    String? email,
    String? phone,
    String? organization,
    String? notesText,
    int? defaultHourlyRateCents,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertContact(ContactsCompanion.insert(
      id: id,
      name: name,
      email: Value.absentIfNull(email),
      phone: Value.absentIfNull(phone),
      organization: Value.absentIfNull(organization),
      notesText: Value.absentIfNull(notesText),
      defaultHourlyRateCents: Value.absentIfNull(defaultHourlyRateCents),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Nullable columns take a [Value] so callers can distinguish "leave
  /// unchanged" (absent) from "clear" (Value(null)).
  Future<void> update(
    String id, {
    String? name,
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> organization = const Value.absent(),
    Value<String?> notesText = const Value.absent(),
    Value<int?> defaultHourlyRateCents = const Value.absent(),
  }) =>
      _dao.updateContact(
        id,
        ContactsCompanion(
          name: Value.absentIfNull(name),
          email: email,
          phone: phone,
          organization: organization,
          notesText: notesText,
          defaultHourlyRateCents: defaultHourlyRateCents,
        ),
      );

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Per-workspace role labels (spec §6.5).
  Stream<List<WorkspaceContact>> watchRoles(String contactId) =>
      _dao.watchRoles(contactId);

  Future<List<WorkspaceContact>> getRoles(String contactId) =>
      _dao.getRoles(contactId);

  Future<void> setRole(String contactId, String workspaceId,
          String? roleLabel) =>
      _dao.upsertRole(contactId, workspaceId, roleLabel);

  Future<void> removeRole(String contactId, String workspaceId) =>
      _dao.removeRole(contactId, workspaceId);
}
