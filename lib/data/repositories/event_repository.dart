import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../../features/calendar/conflict.dart';
import '../db/daos/event_dao.dart';
import '../db/database.dart';

/// The only layer calendar widgets talk to (via providers).
class EventRepository {
  EventRepository(this._dao);

  final EventDao _dao;

  Stream<List<Event>> watchInRange(int startMs, int endMs,
          {String? workspaceId}) =>
      _dao.watchInRange(startMs, endMs, workspaceId: workspaceId);

  Stream<Event?> watchById(String id) => _dao.watchById(id);

  Stream<List<Event>> watchForProject(String projectId) =>
      _dao.watchForProject(projectId);

  /// Conflicting events across ALL workspaces (spec §6.2). The warning is
  /// non-blocking: the caller shows the list and may save anyway.
  Future<List<Event>> findConflicts({
    required int startMs,
    required int endMs,
    String? excludeEventId,
    bool allDay = false,
  }) async {
    if (allDay) return [];
    final overlapping = await _dao.findOverlapping(startMs, endMs,
        excludeEventId: excludeEventId);
    return findConflictingEvents(
      candidates: overlapping,
      startMs: startMs,
      endMs: endMs,
      excludeEventId: excludeEventId,
    );
  }

  Future<String> create({
    required String workspaceId,
    required String title,
    String? description,
    String? location,
    required int startsAt,
    required int endsAt,
    bool allDay = false,
    String? projectId,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertEvent(EventsCompanion.insert(
      id: id,
      workspaceId: workspaceId,
      title: title,
      description: Value.absentIfNull(description),
      location: Value.absentIfNull(location),
      startsAt: startsAt,
      endsAt: endsAt,
      allDay: Value(allDay),
      projectId: Value.absentIfNull(projectId),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Batch-creates one event per range (project instance creation). All
  /// share the same title/location/project; each becomes an independent
  /// event row.
  Future<void> createMany({
    required String workspaceId,
    required String title,
    String? location,
    String? projectId,
    required List<({int startsAt, int endsAt})> ranges,
  }) async {
    for (final range in ranges) {
      await create(
        workspaceId: workspaceId,
        title: title,
        location: location,
        projectId: projectId,
        startsAt: range.startsAt,
        endsAt: range.endsAt,
      );
    }
  }

  /// Nullable columns take a [Value] so callers can distinguish "leave
  /// unchanged" (absent) from "clear" (Value(null)).
  Future<void> update(
    String id, {
    String? workspaceId,
    String? title,
    int? startsAt,
    int? endsAt,
    bool? allDay,
    Value<String?> description = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
  }) =>
      _dao.updateEvent(
        id,
        EventsCompanion(
          workspaceId: Value.absentIfNull(workspaceId),
          title: Value.absentIfNull(title),
          startsAt: Value.absentIfNull(startsAt),
          endsAt: Value.absentIfNull(endsAt),
          allDay: Value.absentIfNull(allDay),
          description: description,
          location: location,
          projectId: projectId,
        ),
      );

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Contact links (spec §4 EventContact join table).
  Stream<Set<String>> watchContactIds(String eventId) =>
      _dao.watchContactIds(eventId);

  Stream<List<Event>> watchForContact(String contactId) =>
      _dao.watchForContact(contactId);

  Future<void> setContacts(String eventId, Set<String> contactIds) =>
      _dao.setContacts(eventId, contactIds);
}
