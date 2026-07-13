import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/recurrence/recurrence_rule.dart';

void main() {
  final engine = RecurrenceEngine();

  int horizon(int year) => DateTime.utc(year, 12, 31).millisecondsSinceEpoch;

  test('daily wall time survives DST and gaps shift forward once', () {
    final occurrences = engine.generate(
      startLocal: DateTime.utc(2026, 3, 28, 3, 30),
      timezoneId: 'Europe/Helsinki',
      rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 3),
      horizonUtcMs: horizon(2026),
    );

    expect(occurrences, hasLength(3));
    expect(
      occurrences.map((value) => value.scheduledLocal.hour),
      everyElement(3),
    );
    expect(
      occurrences.map((value) => value.scheduledLocal.minute),
      everyElement(30),
    );
    expect(occurrences[0].resolvedLocal.hour, 3);
    expect(occurrences[1].resolvedLocal.hour, greaterThanOrEqualTo(4));
    expect(occurrences[2].resolvedLocal.hour, 3);
    expect(occurrences.map((value) => value.startsAtMs).toSet(), hasLength(3));
  });

  test('ambiguous wall time resolves once to a deterministic instant', () {
    final first = engine.generate(
      startLocal: DateTime.utc(2026, 10, 24, 3, 30),
      timezoneId: 'Europe/Helsinki',
      rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 3),
      horizonUtcMs: horizon(2026),
    );
    final second = engine.generate(
      startLocal: DateTime.utc(2026, 10, 24, 3, 30),
      timezoneId: 'Europe/Helsinki',
      rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 3),
      horizonUtcMs: horizon(2026),
    );

    expect(first, hasLength(3));
    expect(first[1].resolvedLocal.hour, 3);
    expect(first[1].resolvedLocal.minute, 30);
    expect(
      first.map((value) => value.startsAtMs),
      second.map((value) => value.startsAtMs),
    );
    expect(first[1].startsAtMs, greaterThan(first[0].startsAtMs));
    expect(first[2].startsAtMs, greaterThan(first[1].startsAtMs));
  });

  test('monthly and yearly rules skip invalid calendar dates', () {
    final monthly = engine.generate(
      startLocal: DateTime.utc(2026, 1, 31, 9),
      timezoneId: 'UTC',
      rule: RecurrenceRule(frequency: RecurrenceFrequency.monthly, count: 4),
      horizonUtcMs: horizon(2027),
    );
    expect(
      monthly.map(
        (value) => (value.scheduledLocal.month, value.scheduledLocal.day),
      ),
      [(1, 31), (3, 31), (5, 31), (7, 31)],
    );

    final yearly = engine.generate(
      startLocal: DateTime.utc(2024, 2, 29, 9),
      timezoneId: 'UTC',
      rule: RecurrenceRule(frequency: RecurrenceFrequency.yearly, count: 3),
      horizonUtcMs: horizon(2033),
    );
    expect(yearly.map((value) => value.scheduledLocal.year), [
      2024,
      2028,
      2032,
    ]);
  });

  test('weekly interval, inclusive end date, and JSON are stable', () {
    final rule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      interval: 2,
      weekdays: {DateTime.monday, DateTime.wednesday},
      untilDate: DateTime.utc(2026, 1, 21),
    );
    final decoded = RecurrenceRule.decode(rule.encode());
    final occurrences = engine.generate(
      startLocal: DateTime.utc(2026, 1, 5, 8),
      timezoneId: 'UTC',
      rule: decoded,
      horizonUtcMs: horizon(2026),
    );

    expect(decoded.interval, 2);
    expect(decoded.weekdays, {DateTime.monday, DateTime.wednesday});
    expect(occurrences.map((value) => formatLocalDate(value.scheduledLocal)), [
      '2026-01-05',
      '2026-01-07',
      '2026-01-19',
      '2026-01-21',
    ]);
  });

  test('unknown IANA timezone is rejected before expansion', () {
    expect(
      () => engine.generate(
        startLocal: DateTime.utc(2026, 1, 1),
        timezoneId: 'Mars/Olympus_Mons',
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 1),
        horizonUtcMs: horizon(2026),
      ),
      throwsArgumentError,
    );
  });
}
