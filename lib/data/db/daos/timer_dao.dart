import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'timer_dao.g.dart';

@DriftAccessor(tables: [TimerSessions])
class TimerDao extends DatabaseAccessor<AppDatabase> with _$TimerDaoMixin {
  TimerDao(super.db);

  SimpleSelectStatement<$TimerSessionsTable, TimerSession> get _running =>
      select(timerSessions)
        ..where((t) => t.deletedAt.isNull() & t.stoppedAt.isNull());

  /// The single running session, if any (one at a time, spec §6.6 v1).
  Stream<TimerSession?> watchRunning() => _running.watchSingleOrNull();

  Future<TimerSession?> getRunning() => _running.getSingleOrNull();

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
}
