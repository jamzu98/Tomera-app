import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'contact_dao.g.dart';

@DriftAccessor(tables: [Contacts, WorkspaceContacts])
class ContactDao extends DatabaseAccessor<AppDatabase> with _$ContactDaoMixin {
  ContactDao(super.db);

  SimpleSelectStatement<$ContactsTable, Contact> get _active =>
      select(contacts)..where((c) => c.deletedAt.isNull());

  Stream<List<Contact>> watchAll() =>
      (_active..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();

  /// Contacts linked to [workspaceId] via an active WorkspaceContacts row.
  Stream<List<Contact>> watchInWorkspace(String workspaceId) {
    final query =
        select(contacts).join([
            innerJoin(
              workspaceContacts,
              workspaceContacts.contactId.equalsExp(contacts.id) &
                  workspaceContacts.workspaceId.equals(workspaceId) &
                  workspaceContacts.deletedAt.isNull(),
            ),
          ])
          ..where(contacts.deletedAt.isNull())
          ..where(
            existsQuery(
              select(attachedDatabase.workspaces)
                ..where((w) => w.id.equals(workspaceId) & w.deletedAt.isNull()),
            ),
          )
          ..orderBy([OrderingTerm.asc(contacts.name)]);
    return query.map((row) => row.readTable(contacts)).watch();
  }

  Stream<Contact?> watchById(String id) =>
      (_active..where((c) => c.id.equals(id))).watchSingleOrNull();

  Future<Contact?> getById(String id) =>
      (_active..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> insertContact(ContactsCompanion entry) =>
      into(contacts).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateContact(String id, ContactsCompanion entry) =>
      (update(contacts)..where((c) => c.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateContact(id, ContactsCompanion(deletedAt: Value(utcNowMs())));

  /// Active workspace-role rows for one contact.
  Stream<List<WorkspaceContact>> watchRoles(String contactId) =>
      (select(workspaceContacts)..where(
            (r) =>
                r.contactId.equals(contactId) &
                r.deletedAt.isNull() &
                _roleParentsAreActive(r),
          ))
          .watch();

  Future<List<WorkspaceContact>> getRoles(String contactId) =>
      (select(workspaceContacts)..where(
            (r) =>
                r.contactId.equals(contactId) &
                r.deletedAt.isNull() &
                _roleParentsAreActive(r),
          ))
          .get();

  Expression<bool> _roleParentsAreActive($WorkspaceContactsTable role) =>
      existsQuery(
        select(attachedDatabase.workspaces)..where(
          (w) => w.id.equalsExp(role.workspaceId) & w.deletedAt.isNull(),
        ),
      ) &
      existsQuery(
        select(attachedDatabase.contacts)
          ..where((c) => c.id.equalsExp(role.contactId) & c.deletedAt.isNull()),
      );

  /// Creates or updates the role row linking [contactId] to [workspaceId].
  Future<void> upsertRole(
    String contactId,
    String workspaceId,
    String? roleLabel, {
    Value<int?> hourlyRateCents = const Value.absent(),
  }) async {
    final now = utcNowMs();
    final existing =
        await (select(workspaceContacts)..where(
              (r) =>
                  r.contactId.equals(contactId) &
                  r.workspaceId.equals(workspaceId) &
                  r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (update(
        workspaceContacts,
      )..where((r) => r.id.equals(existing.id))).write(
        WorkspaceContactsCompanion(
          roleLabel: Value(roleLabel),
          hourlyRateCents: hourlyRateCents,
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
    } else {
      await into(workspaceContacts).insert(
        WorkspaceContactsCompanion.insert(
          id: newId(),
          contactId: contactId,
          workspaceId: workspaceId,
          roleLabel: Value(roleLabel),
          hourlyRateCents: hourlyRateCents,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  /// Sets the per-workspace contact rate without changing the role label.
  /// Creates the active pairing when needed.
  Future<void> setRoleHourlyRate(
    String contactId,
    String workspaceId,
    int? hourlyRateCents,
  ) async {
    final now = utcNowMs();
    final existing =
        await (select(workspaceContacts)..where(
              (r) =>
                  r.contactId.equals(contactId) &
                  r.workspaceId.equals(workspaceId) &
                  r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (update(
        workspaceContacts,
      )..where((r) => r.id.equals(existing.id))).write(
        WorkspaceContactsCompanion(
          hourlyRateCents: Value(hourlyRateCents),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      return;
    }
    await into(workspaceContacts).insert(
      WorkspaceContactsCompanion.insert(
        id: newId(),
        contactId: contactId,
        workspaceId: workspaceId,
        hourlyRateCents: Value(hourlyRateCents),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Soft-deletes the role row linking [contactId] to [workspaceId].
  Future<void> removeRole(String contactId, String workspaceId) async {
    final now = utcNowMs();
    await (update(workspaceContacts)..where(
          (r) =>
              r.contactId.equals(contactId) &
              r.workspaceId.equals(workspaceId) &
              r.deletedAt.isNull(),
        ))
        .write(
          WorkspaceContactsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
  }
}
