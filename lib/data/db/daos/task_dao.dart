import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  SimpleSelectStatement<$TasksTable, Task> get _active =>
      select(tasks)..where((t) => t.deletedAt.isNull());

  /// All live tasks, optionally restricted to one workspace.
  Stream<List<Task>> watchAll({String? workspaceId}) {
    final query = _active;
    if (workspaceId != null) {
      query.where((t) => t.workspaceId.equals(workspaceId));
    }
    query.orderBy([
      (t) => OrderingTerm.asc(t.dueAt, nulls: NullsOrder.last),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
    return query.watch();
  }

  /// Tasks with a due date inside [startMs, endMs) — agenda view deadlines.
  Stream<List<Task>> watchDueInRange(int startMs, int endMs,
      {String? workspaceId}) {
    final query = _active
      ..where((t) => t.dueAt.isBetweenValues(startMs, endMs - 1));
    if (workspaceId != null) {
      query.where((t) => t.workspaceId.equals(workspaceId));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
    return query.watch();
  }

  Future<Task?> getById(String id) =>
      (_active..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Task?> watchById(String id) =>
      (_active..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<void> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateTask(String id, TasksCompanion entry) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateTask(id, TasksCompanion(deletedAt: Value(utcNowMs())));

  /// Live tasks linked to [contactId], soonest due first.
  Stream<List<Task>> watchForContact(String contactId) {
    final query = _active
      ..where((t) => t.contactId.equals(contactId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.dueAt, nulls: NullsOrder.last),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }
}
