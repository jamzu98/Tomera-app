import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  SimpleSelectStatement<$EventsTable, Event> get _active =>
      select(events)..where((e) => e.deletedAt.isNull());

  /// Live events overlapping [startMs, endMs), optionally for one workspace.
  Stream<List<Event>> watchInRange(int startMs, int endMs,
      {String? workspaceId}) {
    final query = _active
      ..where((e) =>
          e.startsAt.isSmallerThanValue(endMs) &
          e.endsAt.isBiggerThanValue(startMs));
    if (workspaceId != null) {
      query.where((e) => e.workspaceId.equals(workspaceId));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.startsAt)]);
    return query.watch();
  }

  /// Events whose time range overlaps [startMs, endMs) across ALL workspaces
  /// (spec §6.2 conflict detection). Touching boundaries do not overlap.
  Future<List<Event>> findOverlapping(int startMs, int endMs,
      {String? excludeEventId}) {
    final query = _active
      ..where((e) =>
          e.startsAt.isSmallerThanValue(endMs) &
          e.endsAt.isBiggerThanValue(startMs));
    if (excludeEventId != null) {
      query.where((e) => e.id.isNotValue(excludeEventId));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.startsAt)]);
    return query.get();
  }

  Future<Event?> getById(String id) =>
      (_active..where((e) => e.id.equals(id))).getSingleOrNull();

  Stream<Event?> watchById(String id) =>
      (_active..where((e) => e.id.equals(id))).watchSingleOrNull();

  Future<void> insertEvent(EventsCompanion entry) => into(events).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateEvent(String id, EventsCompanion entry) =>
      (update(events)..where((e) => e.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateEvent(id, EventsCompanion(deletedAt: Value(utcNowMs())));
}
