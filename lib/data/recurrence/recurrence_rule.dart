import 'dart:convert';

import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

enum RecurrenceFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.dbValue);

  final String dbValue;
}

/// Calendar recurrence expressed in the originating timezone. [untilDate] is
/// an inclusive local calendar date; its time component is ignored.
class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    Set<int> weekdays = const {},
    DateTime? untilDate,
    this.count,
  }) : weekdays = Set.unmodifiable(weekdays),
       untilDate = untilDate == null
           ? null
           : DateTime.utc(untilDate.year, untilDate.month, untilDate.day) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval');
    if (weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (count != null && count! < 1) throw ArgumentError.value(count, 'count');
  }

  final RecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final DateTime? untilDate;
  final int? count;

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? weekdays,
    DateTime? untilDate,
    bool clearUntilDate = false,
    int? count,
    bool clearCount = false,
  }) => RecurrenceRule(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    untilDate: clearUntilDate ? null : (untilDate ?? this.untilDate),
    count: clearCount ? null : (count ?? this.count),
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'frequency': frequency.dbValue,
    'interval': interval,
    'weekdays': weekdays.toList()..sort(),
    if (untilDate != null) 'untilDate': formatLocalDate(untilDate!),
    if (count != null) 'count': count,
  };

  String encode() => jsonEncode(toJson());

  factory RecurrenceRule.fromJson(Map<String, Object?> json) {
    final frequencyValue = json['frequency'] as String?;
    final frequency = RecurrenceFrequency.values.firstWhere(
      (value) => value.dbValue == frequencyValue,
      orElse: () => throw FormatException(
        'Unsupported recurrence frequency: $frequencyValue',
      ),
    );
    final rawWeekdays = json['weekdays'] as List<Object?>? ?? const [];
    return RecurrenceRule(
      frequency: frequency,
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      weekdays: rawWeekdays.map((day) => (day as num).toInt()).toSet(),
      untilDate: switch (json['untilDate']) {
        final String value => parseLocalDate(value),
        _ => null,
      },
      count: (json['count'] as num?)?.toInt(),
    );
  }

  factory RecurrenceRule.decode(String value) =>
      RecurrenceRule.fromJson(jsonDecode(value) as Map<String, Object?>);
}

class RecurrenceOccurrence {
  const RecurrenceOccurrence({
    required this.key,
    required this.scheduledLocal,
    required this.resolvedLocal,
    required this.startsAtMs,
  });

  /// Stable identity based on the intended local wall-clock components.
  final String key;
  final DateTime scheduledLocal;

  /// Actual local representation after DST gap resolution.
  final DateTime resolvedLocal;
  final int startsAtMs;
}

/// Pure calendar expansion. Ambiguous wall times resolve to the earlier UTC
/// instant; nonexistent wall times shift forward using timezone's gap policy.
class RecurrenceEngine {
  RecurrenceEngine() {
    _ensureTimeZones();
  }

  static bool _initialized = false;

  static void _ensureTimeZones() {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    _initialized = true;
  }

  List<RecurrenceOccurrence> generate({
    required DateTime startLocal,
    required String timezoneId,
    required RecurrenceRule rule,
    required int horizonUtcMs,
    String? endsBeforeLocalKey,
  }) {
    final normalizedStart = asLocalComponents(startLocal);
    final location = _location(timezoneId);
    final result = <RecurrenceOccurrence>[];
    var attempts = 0;

    for (final candidate in _localCandidates(normalizedStart, rule)) {
      if (++attempts > 100000) {
        throw StateError('Recurrence expansion exceeded its safety limit');
      }
      if (_afterInclusiveEnd(candidate, rule.untilDate)) break;
      final key = formatLocalDateTime(candidate);
      if (endsBeforeLocalKey != null &&
          key.compareTo(endsBeforeLocalKey) >= 0) {
        break;
      }
      final resolved = _resolveLocal(location, candidate);
      if (resolved.millisecondsSinceEpoch > horizonUtcMs) break;
      result.add(
        RecurrenceOccurrence(
          key: key,
          scheduledLocal: candidate,
          resolvedLocal: DateTime.utc(
            resolved.year,
            resolved.month,
            resolved.day,
            resolved.hour,
            resolved.minute,
            resolved.second,
            resolved.millisecond,
          ),
          startsAtMs: resolved.millisecondsSinceEpoch,
        ),
      );
      if (rule.count != null && result.length >= rule.count!) break;
    }
    return result;
  }

  RecurrenceOccurrence? nextAfter({
    required DateTime seriesStartLocal,
    required DateTime afterScheduledLocal,
    required String timezoneId,
    required RecurrenceRule rule,
  }) {
    final afterKey = formatLocalDateTime(
      asLocalComponents(afterScheduledLocal),
    );
    final horizon = DateTime.utc(
      seriesStartLocal.year + 400,
      12,
      31,
    ).millisecondsSinceEpoch;
    for (final occurrence in generate(
      startLocal: seriesStartLocal,
      timezoneId: timezoneId,
      rule: rule,
      horizonUtcMs: horizon,
    )) {
      if (occurrence.key.compareTo(afterKey) > 0) return occurrence;
    }
    return null;
  }

  int toUtcMs(DateTime localComponents, String timezoneId) => _resolveLocal(
    _location(timezoneId),
    asLocalComponents(localComponents),
  ).millisecondsSinceEpoch;

  DateTime toLocalComponents(int utcMs, String timezoneId) {
    final value = tz.TZDateTime.fromMillisecondsSinceEpoch(
      _location(timezoneId),
      utcMs,
    );
    return DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
    );
  }

  tz.Location _location(String timezoneId) {
    if (timezoneId == 'UTC' || timezoneId == 'Etc/UTC') return tz.UTC;
    try {
      return tz.getLocation(timezoneId);
    } on tz.LocationNotFoundException {
      throw ArgumentError.value(timezoneId, 'timezoneId', 'Unknown IANA zone');
    }
  }

  tz.TZDateTime _resolveLocal(tz.Location location, DateTime local) {
    final constructed = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
    );

    // Find both sides of an overlap and consistently choose the earlier UTC
    // instant. In an ordinary time this finds only [constructed]. In a gap it
    // finds no exact wall-clock match and timezone's forward normalization is
    // retained.
    final exact = <tz.TZDateTime>[];
    for (var minutes = -180; minutes <= 180; minutes += 15) {
      final probe = tz.TZDateTime.fromMillisecondsSinceEpoch(
        location,
        constructed.millisecondsSinceEpoch + minutes * 60000,
      );
      if (_sameComponents(probe, local)) exact.add(probe);
    }
    if (exact.isEmpty) return constructed;
    exact.sort(
      (a, b) => a.millisecondsSinceEpoch.compareTo(b.millisecondsSinceEpoch),
    );
    return exact.first;
  }

  bool _sameComponents(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute &&
      a.second == b.second &&
      a.millisecond == b.millisecond;
}

Iterable<DateTime> _localCandidates(DateTime start, RecurrenceRule rule) sync* {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      for (var index = 0; ; index++) {
        yield DateTime.utc(
          start.year,
          start.month,
          start.day + index * rule.interval,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
        );
      }
    case RecurrenceFrequency.weekly:
      final weekdays = rule.weekdays.isEmpty ? {start.weekday} : rule.weekdays;
      final firstDay = DateTime.utc(start.year, start.month, start.day);
      final anchorMonday = firstDay.subtract(
        Duration(days: firstDay.weekday - DateTime.monday),
      );
      final orderedDays = weekdays.toList()..sort();
      for (var block = 0; ; block++) {
        final weekStart = anchorMonday.add(
          Duration(days: block * rule.interval * 7),
        );
        for (final weekday in orderedDays) {
          final date = weekStart.add(Duration(days: weekday - 1));
          if (date.isBefore(firstDay)) continue;
          yield DateTime.utc(
            date.year,
            date.month,
            date.day,
            start.hour,
            start.minute,
            start.second,
            start.millisecond,
          );
        }
      }
    case RecurrenceFrequency.monthly:
      for (var index = 0; ; index++) {
        final monthIndex =
            start.year * 12 + start.month - 1 + index * rule.interval;
        final year = monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        if (!_validDate(year, month, start.day)) continue;
        yield DateTime.utc(
          year,
          month,
          start.day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
        );
      }
    case RecurrenceFrequency.yearly:
      for (var index = 0; ; index++) {
        final year = start.year + index * rule.interval;
        if (!_validDate(year, start.month, start.day)) continue;
        yield DateTime.utc(
          year,
          start.month,
          start.day,
          start.hour,
          start.minute,
          start.second,
          start.millisecond,
        );
      }
  }
}

bool _validDate(int year, int month, int day) {
  final value = DateTime.utc(year, month, day);
  return value.year == year && value.month == month && value.day == day;
}

bool _afterInclusiveEnd(DateTime value, DateTime? untilDate) {
  if (untilDate == null) return false;
  final date = DateTime.utc(value.year, value.month, value.day);
  return date.isAfter(untilDate);
}

DateTime asLocalComponents(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
);

String formatLocalDate(DateTime value) =>
    '${_four(value.year)}-${_two(value.month)}-${_two(value.day)}';

String formatLocalDateTime(DateTime value) =>
    '${formatLocalDate(value)}T${_two(value.hour)}:${_two(value.minute)}:'
    '${_two(value.second)}.${_three(value.millisecond)}';

DateTime parseLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw FormatException('Invalid local date: $value');
  final result = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (formatLocalDate(result) != value) {
    throw FormatException('Invalid local date: $value');
  }
  return result;
}

DateTime parseLocalDateTime(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.(\d{3})$',
  ).firstMatch(value);
  if (match == null) throw FormatException('Invalid local date-time: $value');
  final result = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
    int.parse(match.group(7)!),
  );
  if (formatLocalDateTime(result) != value) {
    throw FormatException('Invalid local date-time: $value');
  }
  return result;
}

String _two(int value) => value.toString().padLeft(2, '0');
String _three(int value) => value.toString().padLeft(3, '0');
String _four(int value) => value.toString().padLeft(4, '0');
