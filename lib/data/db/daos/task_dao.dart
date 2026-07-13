import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../../recurrence/recurrence_models.dart';
import '../../recurrence/recurrence_rule.dart';
import '../database.dart';
import '../tables.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks, TaskSeriesTable])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  SimpleSelectStatement<$TasksTable, Task> get _active =>
      select(tasks)..where((t) => t.deletedAt.isNull() & _workspaceIsActive(t));

  Expression<bool> _workspaceIsActive($TasksTable task) {
    final parent = attachedDatabase.workspaces;
    return existsQuery(
      select(parent)
        ..where((w) => w.id.equalsExp(task.workspaceId) & w.deletedAt.isNull()),
    );
  }

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
  Stream<List<Task>> watchDueInRange(
    int startMs,
    int endMs, {
    String? workspaceId,
  }) {
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

  Future<void> restore(String id) =>
      updateTask(id, const TasksCompanion(deletedAt: Value(null)));

  Stream<TaskSeriesRecord?> watchSeries(String seriesId) =>
      (select(taskSeriesTable)..where(
            (series) => series.id.equals(seriesId) & series.deletedAt.isNull(),
          ))
          .watchSingleOrNull();

  Future<RepeatingTaskCreation> createRepeating({
    required TaskSeriesTemplate template,
    required RecurrenceRule rule,
    required TaskRepeatAnchor anchor,
  }) => transaction(() async {
    if (template.reminderOffsetMinutes != null &&
        template.reminderOffsetMinutes! < 0) {
      throw ArgumentError.value(
        template.reminderOffsetMinutes,
        'reminderOffsetMinutes',
      );
    }
    final engine = RecurrenceEngine();
    final firstUtc = engine.toUtcMs(
      template.firstDueLocal,
      template.timezoneId,
    );
    final first = engine
        .generate(
          startLocal: template.firstDueLocal,
          timezoneId: template.timezoneId,
          rule: rule.copyWith(count: 1),
          horizonUtcMs: firstUtc + const Duration(days: 370).inMilliseconds,
        )
        .firstOrNull;
    if (first == null) {
      throw ArgumentError('The recurrence rule excludes its first due date');
    }

    final now = utcNowMs();
    final seriesId = newId();
    await into(taskSeriesTable).insert(
      TaskSeriesTableCompanion.insert(
        id: seriesId,
        workspaceId: template.workspaceId,
        title: template.title,
        description: Value.absentIfNull(template.description),
        priority: Value(template.priority),
        firstDueLocal: formatLocalDateTime(template.firstDueLocal),
        timezoneId: template.timezoneId,
        contactId: Value.absentIfNull(template.contactId),
        projectId: Value.absentIfNull(template.projectId),
        reminderOffsetMinutes: Value.absentIfNull(
          template.reminderOffsetMinutes,
        ),
        ruleJson: rule.encode(),
        repeatAnchor: Value(anchor),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final taskId = newId();
    await into(tasks).insert(
      TasksCompanion.insert(
        id: taskId,
        workspaceId: template.workspaceId,
        title: template.title,
        description: Value.absentIfNull(template.description),
        priority: Value(template.priority),
        dueAt: Value(first.startsAtMs),
        reminderAt: Value.absentIfNull(
          template.reminderOffsetMinutes == null
              ? null
              : first.startsAtMs - template.reminderOffsetMinutes! * 60000,
        ),
        contactId: Value.absentIfNull(template.contactId),
        projectId: Value.absentIfNull(template.projectId),
        taskSeriesId: Value(seriesId),
        taskOccurrenceNumber: const Value(1),
        recurrenceScheduledLocal: Value(first.key),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return RepeatingTaskCreation(seriesId: seriesId, firstTaskId: taskId);
  });

  /// Completes a task and creates at most one successor in the same
  /// transaction. A retried completion returns the previously created id.
  Future<TaskCompletionResult> completeTask(
    String id,
    TasksCompanion changes, {
    required int completedAtMs,
  }) => transaction(() async {
    final task = await getById(id);
    if (task == null) throw StateError('The task no longer exists');

    final effectiveCompletedAt = task.completedAt ?? completedAtMs;
    await (update(tasks)..where((row) => row.id.equals(id))).write(
      changes.copyWith(
        status: const Value(TaskStatus.done),
        completedAt: Value(effectiveCompletedAt),
        updatedAt: Value(utcNowMs()),
        isDirty: const Value(true),
      ),
    );

    final seriesId = task.taskSeriesId;
    final occurrenceNumber = task.taskOccurrenceNumber;
    if (seriesId == null || occurrenceNumber == null) {
      return TaskCompletionResult(taskId: id);
    }
    final nextNumber = occurrenceNumber + 1;
    final priorSuccessor =
        await (select(tasks)..where(
              (row) =>
                  row.taskSeriesId.equals(seriesId) &
                  row.taskOccurrenceNumber.equals(nextNumber),
            ))
            .getSingleOrNull();
    if (priorSuccessor != null) {
      if (priorSuccessor.deletedAt != null) {
        await (update(
          tasks,
        )..where((row) => row.id.equals(priorSuccessor.id))).write(
          TasksCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(utcNowMs()),
            isDirty: const Value(true),
          ),
        );
      }
      return TaskCompletionResult(
        taskId: id,
        successorTaskId: priorSuccessor.id,
      );
    }

    final series =
        await (select(taskSeriesTable)..where(
              (row) =>
                  row.id.equals(seriesId) &
                  row.deletedAt.isNull() &
                  existsQuery(
                    select(attachedDatabase.workspaces)..where(
                      (workspace) =>
                          workspace.id.equalsExp(row.workspaceId) &
                          workspace.deletedAt.isNull(),
                    ),
                  ),
            ))
            .getSingleOrNull();
    if (series == null) return TaskCompletionResult(taskId: id);

    final rule = RecurrenceRule.decode(series.ruleJson);
    if (rule.count != null && nextNumber > rule.count!) {
      return TaskCompletionResult(taskId: id);
    }
    final engine = RecurrenceEngine();
    final next = switch (series.repeatAnchor) {
      TaskRepeatAnchor.schedule => engine.nextAfter(
        seriesStartLocal: parseLocalDateTime(series.firstDueLocal),
        afterScheduledLocal: parseLocalDateTime(
          task.recurrenceScheduledLocal ?? series.firstDueLocal,
        ),
        timezoneId: series.timezoneId,
        rule: rule,
      ),
      TaskRepeatAnchor.completion => engine.nextAfter(
        seriesStartLocal: engine.toLocalComponents(
          effectiveCompletedAt,
          series.timezoneId,
        ),
        afterScheduledLocal: engine.toLocalComponents(
          effectiveCompletedAt,
          series.timezoneId,
        ),
        timezoneId: series.timezoneId,
        rule: rule.copyWith(clearCount: true),
      ),
    };
    if (next == null) return TaskCompletionResult(taskId: id);

    final now = utcNowMs();
    final successorId = newId();
    final created = await into(tasks).insertReturningOrNull(
      TasksCompanion.insert(
        id: successorId,
        workspaceId: series.workspaceId,
        title: series.title,
        description: Value.absentIfNull(series.description),
        priority: Value(series.priority),
        dueAt: Value(next.startsAtMs),
        reminderAt: Value.absentIfNull(
          series.reminderOffsetMinutes == null
              ? null
              : next.startsAtMs - series.reminderOffsetMinutes! * 60000,
        ),
        contactId: Value.absentIfNull(series.contactId),
        projectId: Value.absentIfNull(series.projectId),
        taskSeriesId: Value(series.id),
        taskOccurrenceNumber: Value(nextNumber),
        predecessorTaskId: Value(task.id),
        recurrenceScheduledLocal: Value(next.key),
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    if (created != null) {
      return TaskCompletionResult(taskId: id, successorTaskId: successorId);
    }
    final concurrent =
        await (select(tasks)..where(
              (row) =>
                  row.taskSeriesId.equals(seriesId) &
                  row.taskOccurrenceNumber.equals(nextNumber),
            ))
            .getSingleOrNull();
    return TaskCompletionResult(taskId: id, successorTaskId: concurrent?.id);
  });

  /// Reopens a completed task and removes its still-open generated successor
  /// atomically. Repeating the undo is a no-op and returns the same successor
  /// id while that relationship remains as a soft-deleted row.
  Future<String?> undoCompletion(String taskId, TaskStatus restoredStatus) =>
      transaction(() async {
        if (restoredStatus == TaskStatus.done) {
          throw ArgumentError.value(restoredStatus, 'restoredStatus');
        }
        final task = await (select(
          tasks,
        )..where((row) => row.id.equals(taskId))).getSingleOrNull();
        if (task == null || task.deletedAt != null) return null;

        final successor =
            await (select(tasks)
                  ..where((row) => row.predecessorTaskId.equals(taskId))
                  ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
    if (successor != null &&
        successor.deletedAt == null &&
        successor.status != TaskStatus.open) {
      throw StateError('A progressed successor cannot be removed by undo');
        }

        final now = utcNowMs();
        if (task.status == TaskStatus.done || task.completedAt != null) {
          await (update(tasks)..where((row) => row.id.equals(taskId))).write(
            TasksCompanion(
              status: Value(restoredStatus),
              completedAt: const Value(null),
              updatedAt: Value(now),
              isDirty: const Value(true),
            ),
          );
        }
        if (successor != null && successor.deletedAt == null) {
          await (update(
            tasks,
          )..where((row) => row.id.equals(successor.id))).write(
            TasksCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              isDirty: const Value(true),
            ),
          );
        }
        return successor?.id;
      });

  /// Live tasks of one project, soonest due first.
  Stream<List<Task>> watchForProject(String projectId) {
    final query = _active
      ..where((t) => t.projectId.equals(projectId))
      ..where(
        (_) => existsQuery(
          select(attachedDatabase.projects)
            ..where((p) => p.id.equals(projectId) & p.deletedAt.isNull()),
        ),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.dueAt, nulls: NullsOrder.last),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }

  /// Live tasks linked to [contactId], soonest due first.
  Stream<List<Task>> watchForContact(String contactId) {
    final query = _active
      ..where((t) => t.contactId.equals(contactId))
      ..where(
        (_) => existsQuery(
          select(attachedDatabase.contacts)
            ..where((c) => c.id.equals(contactId) & c.deletedAt.isNull()),
        ),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.dueAt, nulls: NullsOrder.last),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }
}
