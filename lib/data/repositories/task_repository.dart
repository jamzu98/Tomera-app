import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/task_dao.dart';
import '../db/database.dart';
import '../recurrence/recurrence_models.dart';
import '../recurrence/recurrence_rule.dart';

/// The only layer task widgets talk to (via providers).
class TaskRepository {
  TaskRepository(this._dao);

  final TaskDao _dao;

  Stream<List<Task>> watchAll({String? workspaceId}) =>
      _dao.watchAll(workspaceId: workspaceId);

  Stream<List<Task>> watchDueInRange(
    int startMs,
    int endMs, {
    String? workspaceId,
  }) => _dao.watchDueInRange(startMs, endMs, workspaceId: workspaceId);

  Stream<Task?> watchById(String id) => _dao.watchById(id);

  Future<Task?> getById(String id) => _dao.getById(id);

  Stream<TaskSeriesRecord?> watchSeries(String seriesId) =>
      _dao.watchSeries(seriesId);

  Stream<List<Task>> watchForContact(String contactId) =>
      _dao.watchForContact(contactId);

  Stream<List<Task>> watchForProject(String projectId) =>
      _dao.watchForProject(projectId);

  Future<String> create({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.normal,
    int? dueAt,
    int? reminderAt,
    String? contactId,
    String? projectId,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertTask(
      TasksCompanion.insert(
        id: id,
        workspaceId: workspaceId,
        title: title,
        description: Value.absentIfNull(description),
        priority: Value(priority),
        dueAt: Value.absentIfNull(dueAt),
        reminderAt: Value.absentIfNull(reminderAt),
        contactId: Value.absentIfNull(contactId),
        projectId: Value.absentIfNull(projectId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<RepeatingTaskCreation> createRepeating({
    required TaskSeriesTemplate template,
    required RecurrenceRule rule,
    TaskRepeatAnchor anchor = TaskRepeatAnchor.schedule,
  }) => _dao.createRepeating(template: template, rule: rule, anchor: anchor);

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
    Value<int?> reminderAt = const Value.absent(),
    Value<String?> contactId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
  }) async {
    final current = status == null ? null : await _dao.getById(id);
    final entry = TasksCompanion(
      workspaceId: Value.absentIfNull(workspaceId),
      title: Value.absentIfNull(title),
      status: Value.absentIfNull(status),
      priority: Value.absentIfNull(priority),
      description: description,
      dueAt: dueAt,
      reminderAt: reminderAt,
      contactId: contactId,
      projectId: projectId,
      completedAt:
          status != null &&
              status != TaskStatus.done &&
              current?.completedAt != null
          ? const Value(null)
          : const Value.absent(),
    );
    if (status == TaskStatus.done) {
      await _dao.completeTask(
        id,
        entry,
        completedAtMs: current?.completedAt ?? utcNowMs(),
      );
      return;
    }
    await _dao.updateTask(id, entry);
  }

  /// Explicit completion API for callers that need the generated successor id
  /// or inject a deterministic completion instant.
  Future<TaskCompletionResult> complete(String id, {int? completedAtMs}) =>
      _dao.completeTask(
        id,
        const TasksCompanion(),
        completedAtMs: completedAtMs ?? utcNowMs(),
      );

  Future<String?> undoCompletion(String taskId, TaskStatus restoredStatus) =>
      _dao.undoCompletion(taskId, restoredStatus);

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

  /// Clears a prior soft-delete, for snackbar undo.
  Future<void> restore(String id) => _dao.restore(id);
}
