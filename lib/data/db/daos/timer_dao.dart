import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'timer_dao.g.dart';

@DriftAccessor(tables: [TimerSessions, BillableItems])
class TimerDao extends DatabaseAccessor<AppDatabase> with _$TimerDaoMixin {
  TimerDao(super.db);

  SimpleSelectStatement<$TimerSessionsTable, TimerSession> get _runningAny =>
      select(timerSessions)
        ..where((t) => t.deletedAt.isNull() & t.stoppedAt.isNull());

  SimpleSelectStatement<$TimerSessionsTable, TimerSession> get _active =>
      select(timerSessions)..where(
        (t) =>
            t.deletedAt.isNull() &
            existsQuery(
              select(attachedDatabase.workspaces)..where(
                (w) => w.id.equalsExp(t.workspaceId) & w.deletedAt.isNull(),
              ),
            ),
      );

  /// The single running session, if any (one at a time, spec §6.6 v1).
  Stream<TimerSession?> watchRunning() =>
      (_active..where((t) => t.stoppedAt.isNull())).watchSingleOrNull();

  Future<TimerSession?> getRunning() =>
      (_active..where((t) => t.stoppedAt.isNull())).getSingleOrNull();

  /// Includes a running session whose workspace was soft-deleted so the
  /// single-running invariant can still be enforced and the row stopped.
  Future<TimerSession?> getAnyRunning() => _runningAny.getSingleOrNull();

  Future<TimerSession?> getById(String id) =>
      (_active..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Active sessions for typed timelines, newest activity first.
  Stream<List<TimerSession>> watchAll({
    String? workspaceId,
    String? contactId,
    String? projectId,
  }) {
    final query = _active;
    if (workspaceId != null) {
      query.where((t) => t.workspaceId.equals(workspaceId));
    }
    if (contactId != null) {
      query.where((t) => t.contactId.equals(contactId));
    }
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.stoppedAt, nulls: NullsOrder.first),
      (t) => OrderingTerm.desc(t.startedAt),
    ]);
    return query.watch();
  }

  /// Stopped sessions which have not been converted to an active billable.
  Stream<List<TimerSession>> watchUnconverted({String? workspaceId}) {
    final query = _active
      ..where((t) => t.stoppedAt.isNotNull())
      ..where(
        (t) => notExistsQuery(
          select(billableItems)..where(
            (b) => b.timerSessionId.equalsExp(t.id) & b.deletedAt.isNull(),
          ),
        ),
      );
    if (workspaceId != null) {
      query.where((t) => t.workspaceId.equals(workspaceId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.stoppedAt)]);
    return query.watch();
  }

  Future<void> insertSession(TimerSessionsCompanion entry) =>
      into(timerSessions).insert(entry);

  /// Marks the session stopped, bumping `updatedAt`/`isDirty`.
  Future<void> stopSession(String id, int stoppedAtMs) =>
      (update(timerSessions)..where((t) => t.id.equals(id))).write(
        TimerSessionsCompanion(
          stoppedAt: Value(stoppedAtMs),
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  /// Soft-deletes a stopped session only while it has no active billable.
  /// Returning false lets stale UI avoid removing a session that was converted
  /// concurrently on another surface.
  Future<bool> softDeleteUnconverted(String id) async {
    final now = utcNowMs();
    final changed =
        await (update(timerSessions)..where(
              (t) =>
                  t.id.equals(id) &
                  t.deletedAt.isNull() &
                  t.stoppedAt.isNotNull() &
                  notExistsQuery(
                    select(billableItems)..where(
                      (b) =>
                          b.timerSessionId.equalsExp(t.id) &
                          b.deletedAt.isNull(),
                    ),
                  ),
            ))
            .write(
              TimerSessionsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                isDirty: const Value(true),
              ),
            );
    return changed == 1;
  }

  Future<void> restore(String id) =>
      (update(timerSessions)..where((t) => t.id.equals(id))).write(
        TimerSessionsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );
}
