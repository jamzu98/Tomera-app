import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events, EventContacts])
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

  /// Ids of contacts linked to [eventId] via active EventContacts rows.
  Stream<Set<String>> watchContactIds(String eventId) => (select(eventContacts)
        ..where((r) => r.eventId.equals(eventId) & r.deletedAt.isNull()))
      .watch()
      .map((rows) => rows.map((r) => r.contactId).toSet());

  /// Live events linked to [contactId], soonest first.
  Stream<List<Event>> watchForContact(String contactId) {
    final query = select(events).join([
      innerJoin(
        eventContacts,
        eventContacts.eventId.equalsExp(events.id) &
            eventContacts.contactId.equals(contactId) &
            eventContacts.deletedAt.isNull(),
      ),
    ])
      ..where(events.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(events.startsAt)]);
    return query.map((row) => row.readTable(events)).watch();
  }

  /// Diffs the active links for [eventId] against [contactIds]: missing rows
  /// are inserted, removed ones soft-deleted.
  Future<void> setContacts(String eventId, Set<String> contactIds) async {
    final now = utcNowMs();
    final current = await (select(eventContacts)
          ..where((r) => r.eventId.equals(eventId) & r.deletedAt.isNull()))
        .get();
    final currentIds = current.map((r) => r.contactId).toSet();

    for (final link in current.where((r) => !contactIds.contains(r.contactId))) {
      await (update(eventContacts)..where((r) => r.id.equals(link.id)))
          .write(EventContactsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));
    }
    for (final contactId in contactIds.difference(currentIds)) {
      await into(eventContacts).insert(EventContactsCompanion.insert(
        id: newId(),
        eventId: eventId,
        contactId: contactId,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }
}
