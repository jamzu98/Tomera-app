import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/project_dao.dart';
import '../db/database.dart';

/// The only layer project widgets talk to (via providers).
class ProjectRepository {
  ProjectRepository(this._dao);

  final ProjectDao _dao;

  Stream<List<Project>> watchAll({
    String? workspaceId,
    bool includeArchived = false,
  }) =>
      _dao.watchAll(workspaceId: workspaceId, includeArchived: includeArchived);

  Stream<Project?> watchById(String id) => _dao.watchById(id);

  Future<Project?> getById(String id) => _dao.getById(id);

  Future<String> create({
    required String workspaceId,
    required String name,
    String? description,
    int? color,
    String? contactId,
    int? hourlyRateCents,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertProject(
      ProjectsCompanion.insert(
        id: id,
        workspaceId: workspaceId,
        name: name,
        description: Value.absentIfNull(description),
        color: Value.absentIfNull(color),
        contactId: Value.absentIfNull(contactId),
        hourlyRateCents: Value.absentIfNull(hourlyRateCents),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Nullable columns take a [Value] so callers can distinguish "leave
  /// unchanged" (absent) from "clear" (Value(null)).
  Future<void> update(
    String id, {
    String? workspaceId,
    String? name,
    bool? archived,
    Value<String?> description = const Value.absent(),
    Value<int?> color = const Value.absent(),
    Value<String?> contactId = const Value.absent(),
    Value<int?> hourlyRateCents = const Value.absent(),
  }) => _dao.updateProject(
    id,
    ProjectsCompanion(
      workspaceId: Value.absentIfNull(workspaceId),
      name: Value.absentIfNull(name),
      archived: Value.absentIfNull(archived),
      description: description,
      color: color,
      contactId: contactId,
      hourlyRateCents: hourlyRateCents,
    ),
  );

  Future<void> delete(String id) => _dao.softDelete(id);
}
