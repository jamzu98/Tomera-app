import '../../data/db/database.dart';

/// Half-open interval overlap (spec §6.2): touching boundaries — one event
/// ending exactly when another starts — do NOT conflict.
bool rangesOverlap(int aStartMs, int aEndMs, int bStartMs, int bEndMs) =>
    aStartMs < bEndMs && aEndMs > bStartMs;

/// Events from [candidates] that conflict with the given time range.
///
/// All-day events never conflict (a birthday shouldn't block a meeting), and
/// the event being edited is excluded so it doesn't conflict with itself.
/// Callers must already have filtered out soft-deleted rows.
List<Event> findConflictingEvents({
  required List<Event> candidates,
  required int startMs,
  required int endMs,
  String? excludeEventId,
}) =>
    candidates
        .where((e) =>
            e.id != excludeEventId &&
            !e.allDay &&
            rangesOverlap(e.startsAt, e.endsAt, startMs, endMs))
        .toList();
