import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../../recurrence/recurrence_models.dart';
import '../../recurrence/recurrence_rule.dart';
import '../database.dart';
import '../tables.dart';

part 'event_dao.g.dart';

@DriftAccessor(
  tables: [
    Events,
    EventContacts,
    EventSeriesTable,
    EventSeriesContacts,
    Reminders,
  ],
)
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  SimpleSelectStatement<$EventsTable, Event> get _active =>
      select(events)..where(
        (e) =>
            e.deletedAt.isNull() &
            (e.recurrenceSuppressed.isNull() |
                e.recurrenceSuppressed.equals(false)) &
            _workspaceIsActive(e),
      );

  Expression<bool> _workspaceIsActive($EventsTable event) {
    final parent = attachedDatabase.workspaces;
    return existsQuery(
      select(
        parent,
      )..where((w) => w.id.equalsExp(event.workspaceId) & w.deletedAt.isNull()),
    );
  }

  /// Live events overlapping [startMs, endMs), optionally for one workspace.
  Stream<List<Event>> watchInRange(
    int startMs,
    int endMs, {
    String? workspaceId,
  }) {
    final query = _active
      ..where(
        (e) =>
            e.startsAt.isSmallerThanValue(endMs) &
            e.endsAt.isBiggerThanValue(startMs),
      );
    if (workspaceId != null) {
      query.where((e) => e.workspaceId.equals(workspaceId));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.startsAt)]);
    return query.watch();
  }

  /// The ongoing or next event after [afterMs], optionally constrained to a
  /// set of visible workspaces. A focused LIMIT query keeps Today scalable.
  Stream<Event?> watchOngoingOrNext(int afterMs, {Set<String>? workspaceIds}) {
    if (workspaceIds != null && workspaceIds.isEmpty) {
      return Stream.value(null);
    }
    final query = _active..where((e) => e.endsAt.isBiggerThanValue(afterMs));
    if (workspaceIds != null) {
      query.where((e) => e.workspaceId.isIn(workspaceIds));
    }
    query
      ..orderBy([(e) => OrderingTerm.asc(e.startsAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  /// Events whose time range overlaps [startMs, endMs) across ALL workspaces
  /// (spec §6.2 conflict detection). Touching boundaries do not overlap.
  Future<List<Event>> findOverlapping(
    int startMs,
    int endMs, {
    String? excludeEventId,
  }) {
    final query = _active
      ..where(
        (e) =>
            e.startsAt.isSmallerThanValue(endMs) &
            e.endsAt.isBiggerThanValue(startMs),
      );
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
      transaction(() async {
        final existing = await (select(
          events,
        )..where((e) => e.id.equals(id))).getSingleOrNull();
        await (update(events)..where((e) => e.id.equals(id))).write(
          entry.copyWith(
            recurrenceException: existing?.seriesId == null
                ? const Value.absent()
                : const Value(true),
            updatedAt: Value(utcNowMs()),
            isDirty: const Value(true),
          ),
        );
      });

  Future<void> softDelete(String id) =>
      updateEvent(id, EventsCompanion(deletedAt: Value(utcNowMs())));

  Future<void> restore(String id) =>
      updateEvent(id, const EventsCompanion(deletedAt: Value(null)));

  Stream<List<Event>> watchSeriesOccurrences(String seriesId) {
    final query = _active
      ..where((e) => e.seriesId.equals(seriesId))
      ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]);
    return query.watch();
  }

  Future<EventSeriesRecord?> getSeries(String seriesId) =>
      (select(eventSeriesTable)
            ..where((s) => s.id.equals(seriesId) & s.deletedAt.isNull()))
          .getSingleOrNull();

  Stream<EventSeriesRecord?> watchSeries(String seriesId) =>
      (select(eventSeriesTable)
            ..where((s) => s.id.equals(seriesId) & s.deletedAt.isNull()))
          .watchSingleOrNull();

  Future<RecurringEventCreation> createRecurring({
    required EventSeriesTemplate template,
    required RecurrenceRule rule,
    required int horizonUtcMs,
  }) => transaction(() async {
    final seriesId = await _insertSeries(template, rule);
    final occurrenceIds = await _materializeSeries(seriesId, horizonUtcMs);
    if (occurrenceIds.isEmpty) {
      throw StateError('The recurrence rule produces no occurrence');
    }
    return RecurringEventCreation(
      seriesId: seriesId,
      occurrenceIds: occurrenceIds,
    );
  });

  Future<List<String>> materializeSeries(String seriesId, int horizonUtcMs) =>
      transaction(() => _materializeSeries(seriesId, horizonUtcMs));

  Future<Map<String, List<String>>> materializeAllSeries(int horizonUtcMs) =>
      transaction(() async {
        final active =
            await (select(eventSeriesTable)..where(
                  (series) =>
                      series.deletedAt.isNull() &
                      existsQuery(
                        select(attachedDatabase.workspaces)..where(
                          (workspace) =>
                              workspace.id.equalsExp(series.workspaceId) &
                              workspace.deletedAt.isNull(),
                        ),
                      ),
                ))
                .get();
        return {
          for (final series in active)
            series.id: await _materializeSeries(series.id, horizonUtcMs),
        };
      });

  Future<String> _insertSeries(
    EventSeriesTemplate template,
    RecurrenceRule rule,
  ) async {
    if (template.duration <= Duration.zero) {
      throw ArgumentError.value(template.duration, 'duration');
    }
    if (template.reminderOffsetMinutes != null &&
        template.reminderOffsetMinutes! < 0) {
      throw ArgumentError.value(
        template.reminderOffsetMinutes,
        'reminderOffsetMinutes',
      );
    }
    // Resolve once up front so invalid IANA identifiers fail before any write.
    RecurrenceEngine().toUtcMs(template.localStartsAt, template.timezoneId);

    final id = newId();
    final now = utcNowMs();
    await into(eventSeriesTable).insert(
      EventSeriesTableCompanion.insert(
        id: id,
        workspaceId: template.workspaceId,
        title: template.title,
        description: Value.absentIfNull(template.description),
        location: Value.absentIfNull(template.location),
        localStartsAt: formatLocalDateTime(template.localStartsAt),
        durationMs: template.duration.inMilliseconds,
        timezoneId: template.timezoneId,
        allDay: Value(template.allDay),
        projectId: Value.absentIfNull(template.projectId),
        reminderOffsetMinutes: Value.absentIfNull(
          template.reminderOffsetMinutes,
        ),
        ruleJson: rule.encode(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final contactId in template.contactIds) {
      await into(eventSeriesContacts).insert(
        EventSeriesContactsCompanion.insert(
          id: newId(),
          seriesId: id,
          contactId: contactId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return id;
  }

  Future<List<String>> _materializeSeries(
    String seriesId,
    int horizonUtcMs,
  ) async {
    final series =
        await (select(eventSeriesTable)..where(
              (s) =>
                  s.id.equals(seriesId) &
                  s.deletedAt.isNull() &
                  existsQuery(
                    select(attachedDatabase.workspaces)..where(
                      (w) =>
                          w.id.equalsExp(s.workspaceId) & w.deletedAt.isNull(),
                    ),
                  ),
            ))
            .getSingleOrNull();
    if (series == null) return const [];

    final engine = RecurrenceEngine();
    final generated = engine.generate(
      startLocal: parseLocalDateTime(series.localStartsAt),
      timezoneId: series.timezoneId,
      rule: RecurrenceRule.decode(series.ruleJson),
      horizonUtcMs: horizonUtcMs,
      endsBeforeLocalKey: series.endsBeforeLocal,
    );
    final existing = await (select(
      events,
    )..where((e) => e.seriesId.equals(seriesId))).get();
    final existingKeys = {for (final event in existing) event.occurrenceKey};
    final contacts =
        await (select(eventSeriesContacts)..where(
              (link) =>
                  link.seriesId.equals(seriesId) &
                  link.deletedAt.isNull() &
                  existsQuery(
                    select(attachedDatabase.contacts)..where(
                      (contact) =>
                          contact.id.equalsExp(link.contactId) &
                          contact.deletedAt.isNull(),
                    ),
                  ),
            ))
            .get();

    final inserted = <String>[];
    for (final occurrence in generated) {
      if (existingKeys.contains(occurrence.key)) continue;
      final id = newId();
      final now = utcNowMs();
      final endsAt = series.allDay
          ? engine.toUtcMs(
              DateTime.utc(
                occurrence.scheduledLocal.year,
                occurrence.scheduledLocal.month,
                occurrence.scheduledLocal.day +
                    ((series.durationMs + Duration.millisecondsPerDay - 1) ~/
                        Duration.millisecondsPerDay),
                occurrence.scheduledLocal.hour,
                occurrence.scheduledLocal.minute,
                occurrence.scheduledLocal.second,
                occurrence.scheduledLocal.millisecond,
              ),
              series.timezoneId,
            )
          : occurrence.startsAtMs + series.durationMs;
      final created = await into(events).insertReturningOrNull(
        EventsCompanion.insert(
          id: id,
          workspaceId: series.workspaceId,
          title: series.title,
          description: Value.absentIfNull(series.description),
          location: Value.absentIfNull(series.location),
          startsAt: occurrence.startsAtMs,
          endsAt: endsAt,
          allDay: Value(series.allDay),
          projectId: Value.absentIfNull(series.projectId),
          seriesId: Value(series.id),
          occurrenceKey: Value(occurrence.key),
          originalStartsAt: Value(occurrence.startsAtMs),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (created == null) continue;
      inserted.add(id);
      existingKeys.add(occurrence.key);

      for (final contact in contacts) {
        await into(eventContacts).insert(
          EventContactsCompanion.insert(
            id: newId(),
            eventId: id,
            contactId: contact.contactId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (series.reminderOffsetMinutes case final int offset) {
        await into(reminders).insert(
          RemindersCompanion.insert(
            id: newId(),
            parentType: ParentType.event,
            parentId: id,
            fireAt: occurrence.startsAtMs - offset * 60000,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    return inserted;
  }

  Future<List<String>> suppressOccurrence(String eventId) async {
    final now = utcNowMs();
    final changed =
        await (update(events)..where(
              (e) =>
                  e.id.equals(eventId) &
                  e.deletedAt.isNull() &
                  e.seriesId.isNotNull(),
            ))
            .write(
              EventsCompanion(
                recurrenceSuppressed: const Value(true),
                updatedAt: Value(now),
                isDirty: const Value(true),
              ),
            );
    if (changed == 0) return const [];
    await _softDeleteEventReminders([eventId], now);
    return [eventId];
  }

  Future<void> restoreSuppressedOccurrence(String eventId) =>
      transaction(() async {
        final now = utcNowMs();
        await (update(events)..where(
              (event) =>
                  event.id.equals(eventId) &
                  event.deletedAt.isNull() &
                  event.seriesId.isNotNull(),
            ))
            .write(
              EventsCompanion(
                recurrenceSuppressed: const Value(false),
                updatedAt: Value(now),
                isDirty: const Value(true),
              ),
            );
        await (update(reminders)..where(
              (reminder) =>
                  reminder.parentType.equalsValue(ParentType.event) &
                  reminder.parentId.equals(eventId) &
                  reminder.deletedAt.isNotNull(),
            ))
            .write(
              RemindersCompanion(
                deletedAt: const Value(null),
                updatedAt: Value(now),
                isDirty: const Value(true),
              ),
            );
      });

  Future<RecurringEventCreation> splitSeriesFromOccurrence({
    required String eventId,
    required EventSeriesTemplate template,
    required RecurrenceRule rule,
    required int horizonUtcMs,
  }) => transaction(() async {
    final occurrence =
        await (select(events)..where(
              (e) =>
                  e.id.equals(eventId) &
                  e.deletedAt.isNull() &
                  e.seriesId.isNotNull() &
                  e.occurrenceKey.isNotNull(),
            ))
            .getSingleOrNull();
    if (occurrence == null) {
      throw StateError('The recurrence occurrence no longer exists');
    }
    final seriesId = occurrence.seriesId!;
    final splitKey = occurrence.occurrenceKey!;
    final now = utcNowMs();
    final priorSeries =
        await (select(eventSeriesTable)..where(
              (series) =>
                  series.id.equals(seriesId) &
                  series.deletedAt.isNull() &
                  series.endsBeforeLocal.isNull(),
            ))
            .getSingleOrNull();
    if (priorSeries == null) {
      throw StateError('The recurrence series no longer exists');
    }
    final pastIdentities =
        await (select(events)..where(
              (event) =>
                  event.seriesId.equals(seriesId) &
                  event.occurrenceKey.isSmallerThanValue(splitKey),
            ))
            .get();
    var effectiveRule = rule;
    if (rule.count case final int totalCount) {
      final remainingCount = totalCount - pastIdentities.length;
      if (remainingCount < 1) {
        throw ArgumentError.value(
          totalCount,
          'rule.count',
          'Count must include the current occurrence after preserved history',
        );
      }
      effectiveRule = rule.copyWith(count: remainingCount);
    }
    final futureRows =
        await (select(events)..where(
              (event) =>
                  event.seriesId.equals(seriesId) &
                  event.occurrenceKey.isBiggerOrEqualValue(splitKey) &
                  event.deletedAt.isNull(),
            ))
            .get();
    await (update(eventSeriesTable)..where((s) => s.id.equals(seriesId))).write(
      EventSeriesTableCompanion(
        endsBeforeLocal: Value(splitKey),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
    await (update(events)..where(
          (e) =>
              e.seriesId.equals(seriesId) &
              e.occurrenceKey.isBiggerOrEqualValue(splitKey) &
              e.deletedAt.isNull(),
        ))
        .write(
          EventsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );

    await _softDeleteEventReminders(futureRows.map((event) => event.id), now);
    final newSeriesId = await _insertSeries(template, effectiveRule);
    final ids = await _materializeSeries(newSeriesId, horizonUtcMs);
    return RecurringEventCreation(seriesId: newSeriesId, occurrenceIds: ids);
  });

  Future<List<String>> deleteCurrentAndFuture(String eventId) =>
      transaction(() async {
        final occurrence =
            await (select(events)..where(
                  (e) =>
                      e.id.equals(eventId) &
                      e.deletedAt.isNull() &
                      e.seriesId.isNotNull() &
                      e.occurrenceKey.isNotNull(),
                ))
                .getSingleOrNull();
        if (occurrence == null) return const [];
        final now = utcNowMs();
        final affected =
            await (select(events)..where(
                  (event) =>
                      event.seriesId.equals(occurrence.seriesId!) &
                      event.occurrenceKey.isBiggerOrEqualValue(
                        occurrence.occurrenceKey!,
                      ) &
                      event.deletedAt.isNull(),
                ))
                .get();
        await (update(
          eventSeriesTable,
        )..where((s) => s.id.equals(occurrence.seriesId!))).write(
          EventSeriesTableCompanion(
            endsBeforeLocal: Value(occurrence.occurrenceKey),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
        await (update(events)..where(
              (e) =>
                  e.seriesId.equals(occurrence.seriesId!) &
                  e.occurrenceKey.isBiggerOrEqualValue(
                    occurrence.occurrenceKey!,
                  ) &
                  e.deletedAt.isNull(),
            ))
            .write(
              EventsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                isDirty: const Value(true),
              ),
            );
        await _softDeleteEventReminders(affected.map((event) => event.id), now);
        return affected.map((event) => event.id).toList(growable: false);
      });

  Future<void> _softDeleteEventReminders(
    Iterable<String> eventIds,
    int now,
  ) async {
    final ids = eventIds.toList(growable: false);
    if (ids.isEmpty) return;
    await (update(reminders)..where(
          (reminder) =>
              reminder.parentType.equalsValue(ParentType.event) &
              reminder.parentId.isIn(ids) &
              reminder.deletedAt.isNull(),
        ))
        .write(
          RemindersCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
  }

  /// Ids of contacts linked to [eventId] via active EventContacts rows.
  Stream<Set<String>> watchContactIds(String eventId) =>
      (select(eventContacts)..where(
            (r) =>
                r.eventId.equals(eventId) &
                r.deletedAt.isNull() &
                existsQuery(
                  select(attachedDatabase.events)..where(
                    (e) => e.id.equalsExp(r.eventId) & e.deletedAt.isNull(),
                  ),
                ) &
                existsQuery(
                  select(attachedDatabase.contacts)..where(
                    (c) => c.id.equalsExp(r.contactId) & c.deletedAt.isNull(),
                  ),
                ),
          ))
          .watch()
          .map((rows) => rows.map((r) => r.contactId).toSet());

  /// Live events linked to [contactId], soonest first.
  Stream<List<Event>> watchForContact(String contactId) {
    final query =
        select(events).join([
            innerJoin(
              eventContacts,
              eventContacts.eventId.equalsExp(events.id) &
                  eventContacts.contactId.equals(contactId) &
                  eventContacts.deletedAt.isNull(),
            ),
          ])
          ..where(
            events.deletedAt.isNull() &
                (events.recurrenceSuppressed.isNull() |
                    events.recurrenceSuppressed.equals(false)) &
                _workspaceIsActive(events) &
                existsQuery(
                  select(attachedDatabase.contacts)..where(
                    (c) => c.id.equals(contactId) & c.deletedAt.isNull(),
                  ),
                ),
          )
          ..orderBy([OrderingTerm.desc(events.startsAt)]);
    return query.map((row) => row.readTable(events)).watch();
  }

  /// Live events of one project, soonest first.
  Stream<List<Event>> watchForProject(String projectId) {
    final query = _active
      ..where((e) => e.projectId.equals(projectId))
      ..where(
        (_) => existsQuery(
          select(attachedDatabase.projects)
            ..where((p) => p.id.equals(projectId) & p.deletedAt.isNull()),
        ),
      )
      ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]);
    return query.watch();
  }

  /// Diffs the active links for [eventId] against [contactIds]: missing rows
  /// are inserted, removed ones soft-deleted.
  Future<void> setContacts(String eventId, Set<String> contactIds) async {
    final now = utcNowMs();
    final current = await (select(
      eventContacts,
    )..where((r) => r.eventId.equals(eventId) & r.deletedAt.isNull())).get();
    final currentIds = current.map((r) => r.contactId).toSet();

    for (final link in current.where(
      (r) => !contactIds.contains(r.contactId),
    )) {
      await (update(eventContacts)..where((r) => r.id.equals(link.id))).write(
        EventContactsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
    }
    for (final contactId in contactIds.difference(currentIds)) {
      await into(eventContacts).insert(
        EventContactsCompanion.insert(
          id: newId(),
          eventId: eventId,
          contactId: contactId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}
