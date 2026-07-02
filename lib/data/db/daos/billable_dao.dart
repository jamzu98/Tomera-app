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
      select(billableItems)..where((b) => b.deletedAt.isNull());

  /// Live billables, newest first, optionally narrowed by workspace/contact.
  Stream<List<BillableItem>> watchAll({String? workspaceId, String? contactId}) {
    final query = _active;
    if (workspaceId != null) {
      query.where((b) => b.workspaceId.equals(workspaceId));
    }
    if (contactId != null) {
      query.where((b) => b.contactId.equals(contactId));
    }
    query.orderBy([(b) => OrderingTerm.desc(b.createdAt)]);
    return query.watch();
  }

  Stream<BillableItem?> watchById(String id) =>
      (_active..where((b) => b.id.equals(id))).watchSingleOrNull();

  Future<void> insertBillable(BillableItemsCompanion entry) =>
      into(billableItems).insert(entry);

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
}
