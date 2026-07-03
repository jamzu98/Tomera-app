import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'project_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase> with _$ProjectDaoMixin {
  ProjectDao(super.db);

  SimpleSelectStatement<$ProjectsTable, Project> get _active =>
      select(projects)..where((p) => p.deletedAt.isNull());

  /// Live projects ordered by name; optionally one workspace, optionally
  /// including archived ones.
  Stream<List<Project>> watchAll(
      {String? workspaceId, bool includeArchived = false}) {
    final query = _active;
    if (workspaceId != null) {
      query.where((p) => p.workspaceId.equals(workspaceId));
    }
    if (!includeArchived) {
      query.where((p) => p.archived.equals(false));
    }
    query.orderBy([(p) => OrderingTerm.asc(p.name)]);
    return query.watch();
  }

  Stream<Project?> watchById(String id) =>
      (_active..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<Project?> getById(String id) =>
      (_active..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateProject(String id, ProjectsCompanion entry) =>
      (update(projects)..where((p) => p.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateProject(id, ProjectsCompanion(deletedAt: Value(utcNowMs())));
}
