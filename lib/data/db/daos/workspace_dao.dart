import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'workspace_dao.g.dart';

@DriftAccessor(tables: [Workspaces])
class WorkspaceDao extends DatabaseAccessor<AppDatabase>
    with _$WorkspaceDaoMixin {
  WorkspaceDao(super.db);

  SimpleSelectStatement<$WorkspacesTable, Workspace> get _active =>
      select(workspaces)..where((w) => w.deletedAt.isNull());

  Stream<List<Workspace>> watchAll() =>
      (_active..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).watch();

  Stream<Workspace?> watchById(String id) =>
      (_active..where((w) => w.id.equals(id))).watchSingleOrNull();

  Future<Workspace?> getById(String id) =>
      (_active..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<int> nextSortOrder() async {
    final maxOrder = workspaces.sortOrder.max();
    final query = selectOnly(workspaces)
      ..addColumns([maxOrder])
      ..where(workspaces.deletedAt.isNull());
    final row = await query.getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  Future<void> insertWorkspace(WorkspacesCompanion entry) =>
      into(workspaces).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateWorkspace(String id, WorkspacesCompanion entry) =>
      (update(workspaces)..where((w) => w.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) => updateWorkspace(
        id,
        WorkspacesCompanion(deletedAt: Value(utcNowMs())),
      );

  /// Rewrites `sortOrder` to match the position in [orderedIds].
  Future<void> reorder(List<String> orderedIds) async {
    final now = utcNowMs();
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          workspaces,
          WorkspacesCompanion(
            sortOrder: Value(i),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
          where: (w) => w.id.equals(orderedIds[i]),
        );
      }
    });
  }
}
