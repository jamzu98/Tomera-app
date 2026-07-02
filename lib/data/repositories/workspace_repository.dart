import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/workspace_dao.dart';
import '../db/database.dart';

/// The only layer workspace widgets talk to (via providers).
class WorkspaceRepository {
  WorkspaceRepository(this._dao);

  final WorkspaceDao _dao;

  Stream<List<Workspace>> watchAll() => _dao.watchAll();

  Stream<Workspace?> watchById(String id) => _dao.watchById(id);

  Future<String> create({
    required String name,
    required int color,
    required String icon,
    required Set<ModuleKey> enabledModules,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertWorkspace(WorkspacesCompanion.insert(
      id: id,
      name: name,
      color: color,
      icon: icon,
      enabledModules: enabledModules,
      sortOrder: Value(await _dao.nextSortOrder()),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    int? color,
    String? icon,
    Set<ModuleKey>? enabledModules,
  }) =>
      _dao.updateWorkspace(
        id,
        WorkspacesCompanion(
          name: Value.absentIfNull(name),
          color: Value.absentIfNull(color),
          icon: Value.absentIfNull(icon),
          enabledModules: Value.absentIfNull(enabledModules),
        ),
      );

  /// Soft delete: hides the workspace but never deletes its data (spec §5).
  Future<void> delete(String id) => _dao.softDelete(id);

  Future<void> reorder(List<String> orderedIds) => _dao.reorder(orderedIds);
}
