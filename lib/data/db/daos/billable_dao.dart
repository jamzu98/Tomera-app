import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'billable_dao.g.dart';

@DriftAccessor(tables: [BillableItems])
class BillableDao extends DatabaseAccessor<AppDatabase>
    with _$BillableDaoMixin {
  BillableDao(super.db);

  SimpleSelectStatement<$BillableItemsTable, BillableItem> get _active =>
      select(billableItems)
        ..where((b) => b.deletedAt.isNull() & _workspaceIsActive(b));

  Expression<bool> _workspaceIsActive($BillableItemsTable item) {
    final parent = attachedDatabase.workspaces;
    return existsQuery(
      select(parent)
        ..where((w) => w.id.equalsExp(item.workspaceId) & w.deletedAt.isNull()),
    );
  }

  /// Live billables, newest first, optionally narrowed by workspace,
  /// contact, or project.
  Stream<List<BillableItem>> watchAll({
    String? workspaceId,
    String? contactId,
    String? projectId,
    String? eventId,
    String? taskId,
    String? timerSessionId,
  }) {
    final query = _active;
    if (workspaceId != null) {
      query.where((b) => b.workspaceId.equals(workspaceId));
    }
    if (contactId != null) {
      query.where((b) => b.contactId.equals(contactId));
      query.where(
        (_) => existsQuery(
          select(attachedDatabase.contacts)
            ..where((c) => c.id.equals(contactId) & c.deletedAt.isNull()),
        ),
      );
    }
    if (projectId != null) {
      query.where((b) => b.projectId.equals(projectId));
      query.where(
        (_) => existsQuery(
          select(attachedDatabase.projects)
            ..where((p) => p.id.equals(projectId) & p.deletedAt.isNull()),
        ),
      );
    }
    if (eventId != null) {
      query.where((b) => b.eventId.equals(eventId));
      query.where(
        (_) => existsQuery(
          select(attachedDatabase.events)
            ..where((e) => e.id.equals(eventId) & e.deletedAt.isNull()),
        ),
      );
    }
    if (taskId != null) {
      query.where((b) => b.taskId.equals(taskId));
      query.where(
        (_) => existsQuery(
          select(attachedDatabase.tasks)
            ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()),
        ),
      );
    }
    if (timerSessionId != null) {
      query.where((b) => b.timerSessionId.equals(timerSessionId));
      query.where(
        (_) => existsQuery(
          select(attachedDatabase.timerSessions)
            ..where((t) => t.id.equals(timerSessionId) & t.deletedAt.isNull()),
        ),
      );
    }
    query.orderBy([(b) => OrderingTerm.desc(b.createdAt)]);
    return query.watch();
  }

  Stream<BillableItem?> watchById(String id) =>
      (_active..where((b) => b.id.equals(id))).watchSingleOrNull();

  Future<BillableItem?> getByTimerSessionId(String timerSessionId) =>
      (_active..where((b) => b.timerSessionId.equals(timerSessionId)))
          .getSingleOrNull();

  Future<void> insertBillable(BillableItemsCompanion entry) =>
      into(billableItems).insert(entry);

  /// Inserts one active billable for a stopped timer. Concurrent/retried calls
  /// converge on the existing row through the partial unique index.
  Future<String> insertFromTimer(
    String timerSessionId,
    BillableItemsCompanion entry,
  ) => transaction(() async {
    final session =
        await (select(attachedDatabase.timerSessions)..where(
              (t) =>
                  t.id.equals(timerSessionId) &
                  t.deletedAt.isNull() &
                  t.stoppedAt.isNotNull() &
                  existsQuery(
                    select(attachedDatabase.workspaces)..where(
                      (w) =>
                          w.id.equalsExp(t.workspaceId) & w.deletedAt.isNull(),
                    ),
                  ),
            ))
            .getSingleOrNull();
    if (session == null) {
      throw StateError('Only an active stopped timer can be converted');
    }
    if (!entry.workspaceId.present ||
        entry.workspaceId.value != session.workspaceId) {
      throw StateError('Timer conversion workspace does not match the timer');
    }

    final existing = await getByTimerSessionId(timerSessionId);
    if (existing != null) return existing.id;

    await into(billableItems).insert(entry, mode: InsertMode.insertOrIgnore);
    final inserted = await getByTimerSessionId(timerSessionId);
    if (inserted == null) {
      throw StateError('Timer conversion could not be persisted');
    }
    return inserted.id;
  });

  /// Resolves the effective hourly rate using the single app-wide precedence:
  /// project > workspace-contact > contact > workspace.
  Future<int?> resolveHourlyRateCents({
    required String workspaceId,
    String? contactId,
    String? projectId,
  }) async {
    final workspace =
        await (select(attachedDatabase.workspaces)
              ..where((w) => w.id.equals(workspaceId) & w.deletedAt.isNull()))
            .getSingleOrNull();
    if (workspace == null) return null;

    Project? project;
    if (projectId != null) {
      project =
          await (select(attachedDatabase.projects)..where(
                (p) =>
                    p.id.equals(projectId) &
                    p.workspaceId.equals(workspaceId) &
                    p.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (project?.hourlyRateCents != null) return project!.hourlyRateCents;
    }

    final effectiveContactId = contactId ?? project?.contactId;
    if (effectiveContactId != null) {
      final contact =
          await (select(attachedDatabase.contacts)..where(
                (c) => c.id.equals(effectiveContactId) & c.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (contact != null) {
        final pairing =
            await (select(attachedDatabase.workspaceContacts)..where(
                  (r) =>
                      r.workspaceId.equals(workspaceId) &
                      r.contactId.equals(effectiveContactId) &
                      r.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (pairing?.hourlyRateCents != null) {
          return pairing!.hourlyRateCents;
        }
        if (contact.defaultHourlyRateCents != null) {
          return contact.defaultHourlyRateCents;
        }
      }
    }
    return workspace.defaultHourlyRateCents;
  }

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateBillable(String id, BillableItemsCompanion entry) =>
      (update(billableItems)..where((b) => b.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateBillable(id, BillableItemsCompanion(deletedAt: Value(utcNowMs())));

  Future<void> restore(String id) =>
      updateBillable(id, const BillableItemsCompanion(deletedAt: Value(null)));
}
