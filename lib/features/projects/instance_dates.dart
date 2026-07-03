/// Pure date/time logic for batch instance creation (project courses etc.).
library;

/// Hard limit so a runaway pattern cannot flood the calendar.
const maxGeneratedDates = 200;

/// One planned event instance: a local date plus start/end as minutes since
/// local midnight (kept primitive so the logic stays pure and testable).
typedef EventInstance = ({DateTime date, int startMinutes, int endMinutes});

/// Dates matching [weekdays] (DateTime.monday..sunday) from [from] onwards,
/// bounded by [until] (inclusive) or [count] occurrences, whichever comes
/// first; at most [maxGeneratedDates]. Returns local midnights.
List<DateTime> generateWeeklyDates({
  required Set<int> weekdays,
  required DateTime from,
  DateTime? until,
  int? count,
}) {
  if (weekdays.isEmpty || (until == null && count == null)) return const [];
  final dates = <DateTime>[];
  var day = DateTime(from.year, from.month, from.day);
  final lastDay =
      until != null ? DateTime(until.year, until.month, until.day) : null;
  final limit =
      count != null ? count.clamp(0, maxGeneratedDates) : maxGeneratedDates;

  while (dates.length < limit) {
    if (lastDay != null && day.isAfter(lastDay)) break;
    if (weekdays.contains(day.weekday)) dates.add(day);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return dates;
}

/// Absolute event times for an instance (local wall-clock → UTC epoch ms).
({int startsAt, int endsAt}) instanceRange(EventInstance instance) {
  final date = instance.date;
  DateTime at(int minutes) => DateTime(
      date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  return (
    startsAt: at(instance.startMinutes).toUtc().millisecondsSinceEpoch,
    endsAt: at(instance.endMinutes).toUtc().millisecondsSinceEpoch,
  );
}

/// Adds [dates] as instances with the given default times, skipping dates
/// already present, and returns the list sorted by date then start time.
List<EventInstance> mergeDates(
  List<EventInstance> existing,
  Iterable<DateTime> dates, {
  required int startMinutes,
  required int endMinutes,
}) {
  final present = {for (final i in existing) DateTime(i.date.year, i.date.month, i.date.day)};
  final merged = [
    ...existing,
    for (final date in dates)
      if (present.add(DateTime(date.year, date.month, date.day)))
        (
          date: DateTime(date.year, date.month, date.day),
          startMinutes: startMinutes,
          endMinutes: endMinutes,
        ),
  ];
  merged.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.startMinutes.compareTo(b.startMinutes);
  });
  return merged;
}
