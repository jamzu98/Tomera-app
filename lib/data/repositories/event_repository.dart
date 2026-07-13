import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../../features/calendar/conflict.dart';
import '../db/daos/event_dao.dart';
import '../db/database.dart';
import '../recurrence/recurrence_models.dart';
import '../recurrence/recurrence_rule.dart';

/// The only layer calendar widgets talk to (via providers).
class EventRepository {
  EventRepository(this._dao);

  final EventDao _dao;

  Stream<List<Event>> watchInRange(
    int startMs,
    int endMs, {
    String? workspaceId,
  }) => _dao.watchInRange(startMs, endMs, workspaceId: workspaceId);

  Stream<Event?> watchById(String id) => _dao.watchById(id);

  Stream<Event?> watchOngoingOrNext(int afterMs, {Set<String>? workspaceIds}) =>
      _dao.watchOngoingOrNext(afterMs, workspaceIds: workspaceIds);

  Future<Event?> getById(String id) => _dao.getById(id);

  Stream<EventSeriesRecord?> watchSeries(String seriesId) =>
      _dao.watchSeries(seriesId);

  Stream<List<Event>> watchSeriesOccurrences(String seriesId) =>
      _dao.watchSeriesOccurrences(seriesId);

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
    final overlapping = await _dao.findOverlapping(
      startMs,
      endMs,
      excludeEventId: excludeEventId,
    );
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
    await _dao.insertEvent(
      EventsCompanion.insert(
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
      ),
    );
    return id;
  }

  /// Creates a recurrence template and materializes ordinary event rows
  /// through the rolling horizon (18 months by default).
  Future<RecurringEventCreation> createRecurring({
    required EventSeriesTemplate template,
    required RecurrenceRule rule,
    int? horizonUtcMs,
  }) => _dao.createRecurring(
    template: template,
    rule: rule,
    horizonUtcMs: _recurrenceHorizon(template, rule, horizonUtcMs),
  );

  /// Idempotently extends a series' materialized occurrence window.
  Future<List<String>> materializeSeries(
    String seriesId, {
    required int throughUtcMs,
  }) => _dao.materializeSeries(seriesId, throughUtcMs);

  /// Startup/resume maintenance hook for the rolling occurrence window.
  Future<Map<String, List<String>>> refreshRecurrenceHorizon({
    int? throughUtcMs,
  }) => _dao.materializeAllSeries(
    throughUtcMs ??
        DateTime.now()
            .toUtc()
            .add(const Duration(days: 550))
            .millisecondsSinceEpoch,
  );

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
  }) => _dao.updateEvent(
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

  /// Applies an edit to one occurrence (creating an exception) or splits the
  /// series at that occurrence and regenerates current/future rows. A split
  /// requires the complete new template and rule so no hidden defaults leak
  /// in from an exception row.
  Future<RecurringEventCreation?> updateRecurrence({
    required String eventId,
    required RecurrenceEditScope scope,
    String? workspaceId,
    String? title,
    int? startsAt,
    int? endsAt,
    bool? allDay,
    Value<String?> description = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    EventSeriesTemplate? currentAndFutureTemplate,
    RecurrenceRule? currentAndFutureRule,
    int? horizonUtcMs,
  }) async {
    switch (scope) {
      case RecurrenceEditScope.occurrence:
        await update(
          eventId,
          workspaceId: workspaceId,
          title: title,
          startsAt: startsAt,
          endsAt: endsAt,
          allDay: allDay,
          description: description,
          location: location,
          projectId: projectId,
        );
        return null;
      case RecurrenceEditScope.currentAndFuture:
        final template = currentAndFutureTemplate;
        final rule = currentAndFutureRule;
        if (template == null || rule == null) {
          throw ArgumentError(
            'Current/future edits require a complete template and rule',
          );
        }
        return _dao.splitSeriesFromOccurrence(
          eventId: eventId,
          template: template,
          rule: rule,
          horizonUtcMs: _recurrenceHorizon(template, rule, horizonUtcMs),
        );
    }
  }

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Returns ids whose scheduled notifications should be canceled by UI.
  Future<List<String>> deleteRecurrence(
    String eventId,
    RecurrenceEditScope scope,
  ) => switch (scope) {
    RecurrenceEditScope.occurrence => _dao.suppressOccurrence(eventId),
    RecurrenceEditScope.currentAndFuture => _dao.deleteCurrentAndFuture(
      eventId,
    ),
  };

  Future<void> restoreRecurrenceOccurrence(String eventId) =>
      _dao.restoreSuppressedOccurrence(eventId);

  /// Clears a prior soft-delete, for snackbar undo. Reminder restoration is
  /// coordinated by the UI's reminder coordinator alongside this mutation.
  Future<void> restore(String id) => _dao.restore(id);

  /// Contact links (spec §4 EventContact join table).
  Stream<Set<String>> watchContactIds(String eventId) =>
      _dao.watchContactIds(eventId);

  Stream<List<Event>> watchForContact(String contactId) =>
      _dao.watchForContact(contactId);

  Future<void> setContacts(String eventId, Set<String> contactIds) =>
      _dao.setContacts(eventId, contactIds);

  int _recurrenceHorizon(
    EventSeriesTemplate template,
    RecurrenceRule rule,
    int? requested,
  ) {
    if (requested != null) return requested;
    final rolling = DateTime.now()
        .toUtc()
        .add(const Duration(days: 550))
        .millisecondsSinceEpoch;
    final first = RecurrenceEngine().toUtcMs(
      template.localStartsAt,
      template.timezoneId,
    );
    // A weekly rule may exclude the template weekday. Include at least the
    // next custom-interval block so a far-future series still materializes
    // its real first candidate rather than committing an empty template.
    final firstCandidateHorizon =
        first +
        Duration(
          days: rule.frequency == RecurrenceFrequency.weekly
              ? rule.interval * 7 + 7
              : 1,
        ).inMilliseconds;
    return firstCandidateHorizon > rolling ? firstCandidateHorizon : rolling;
  }
}
