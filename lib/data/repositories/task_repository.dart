import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/task_dao.dart';
import '../db/database.dart';

/// The only layer task widgets talk to (via providers).
class TaskRepository {
  TaskRepository(this._dao);

  final TaskDao _dao;

  Stream<List<Task>> watchAll({String? workspaceId}) =>
      _dao.watchAll(workspaceId: workspaceId);

  Stream<List<Task>> watchDueInRange(int startMs, int endMs,
          {String? workspaceId}) =>
      _dao.watchDueInRange(startMs, endMs, workspaceId: workspaceId);

  Stream<Task?> watchById(String id) => _dao.watchById(id);

  Future<String> create({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.normal,
    int? dueAt,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertTask(TasksCompanion.insert(
      id: id,
      workspaceId: workspaceId,
      title: title,
      description: Value.absentIfNull(description),
      priority: Value(priority),
      dueAt: Value.absentIfNull(dueAt),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Nullable columns take a [Value] so callers can distinguish "leave
  /// unchanged" (absent) from "clear" (Value(null)).
  Future<void> update(
    String id, {
    String? workspaceId,
    String? title,
    TaskStatus? status,
    TaskPriority? priority,
    Value<String?> description = const Value.absent(),
    Value<int?> dueAt = const Value.absent(),
  }) =>
      _dao.updateTask(
        id,
        TasksCompanion(
          workspaceId: Value.absentIfNull(workspaceId),
          title: Value.absentIfNull(title),
          status: Value.absentIfNull(status),
          priority: Value.absentIfNull(priority),
          description: description,
          dueAt: dueAt,
        ),
      );

  /// One-tap status progression: open → in progress → done → open.
  Future<void> cycleStatus(Task task) {
    final next = switch (task.status) {
      TaskStatus.open => TaskStatus.inProgress,
      TaskStatus.inProgress => TaskStatus.done,
      TaskStatus.done => TaskStatus.open,
    };
    return update(task.id, status: next);
  }

  Future<void> delete(String id) => _dao.softDelete(id);
}
