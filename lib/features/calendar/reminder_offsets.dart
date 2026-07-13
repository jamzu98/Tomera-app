/// Quick reminder offsets for events (spec §6.3). Kept as pure functions so
/// the fire-time math is unit-testable.
enum ReminderOffset { none, atStart, min15, hour1, day1 }

const _offsetMs = {
  ReminderOffset.atStart: 0,
  ReminderOffset.min15: 15 * 60 * 1000,
  ReminderOffset.hour1: 60 * 60 * 1000,
  ReminderOffset.day1: 24 * 60 * 60 * 1000,
};

/// Absolute fire time for [offset] relative to an event start, or null for
/// [ReminderOffset.none].
int? reminderFireAtMs(ReminderOffset offset, int startMs) {
  final delta = _offsetMs[offset];
  return delta == null ? null : startMs - delta;
}

/// Offset stored by recurrence templates, in whole minutes.
int? reminderOffsetMinutes(ReminderOffset offset) {
  final delta = _offsetMs[offset];
  return delta == null ? null : delta ~/ Duration.millisecondsPerMinute;
}

/// Reverse mapping for pre-selecting the picker when editing. Falls back to
/// [ReminderOffset.atStart] for a custom delta (e.g. the event start moved
/// after the reminder was created).
ReminderOffset offsetFromFireAt(int? fireAtMs, int startMs) {
  if (fireAtMs == null) return ReminderOffset.none;
  for (final entry in _offsetMs.entries) {
    if (startMs - entry.value == fireAtMs) return entry.key;
  }
  return ReminderOffset.atStart;
}
