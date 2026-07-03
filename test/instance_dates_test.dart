import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/features/projects/instance_dates.dart';

void main() {
  group('generateWeeklyDates', () {
    // 2026-09-07 is a Monday.
    final monday = DateTime(2026, 9, 7);

    test('generates matching weekdays inside an inclusive until bound', () {
      final dates = generateWeeklyDates(
        weekdays: {DateTime.monday, DateTime.wednesday},
        from: monday,
        until: DateTime(2026, 9, 21),
      );
      expect(dates, [
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 21), // until itself matches Monday
      ]);
    });

    test('count bound stops after N occurrences', () {
      final dates = generateWeeklyDates(
        weekdays: {DateTime.friday},
        from: monday,
        count: 3,
      );
      expect(dates, [
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 18),
        DateTime(2026, 9, 25),
      ]);
    });

    test('from date not matching a weekday starts at the next match', () {
      final dates = generateWeeklyDates(
        weekdays: {DateTime.thursday},
        from: monday,
        count: 1,
      );
      expect(dates.single, DateTime(2026, 9, 10));
    });

    test('empty weekdays or missing bounds produce nothing', () {
      expect(
        generateWeeklyDates(weekdays: {}, from: monday, count: 5),
        isEmpty,
      );
      expect(
        generateWeeklyDates(weekdays: {DateTime.monday}, from: monday),
        isEmpty,
      );
    });

    test('caps runaway generation at maxGeneratedDates', () {
      final dates = generateWeeklyDates(
        weekdays: {...List.generate(7, (i) => i + 1)},
        from: monday,
        until: DateTime(2100),
      );
      expect(dates, hasLength(maxGeneratedDates));
    });
  });

  group('instanceRange', () {
    test('converts local wall-clock minutes to UTC epoch ms', () {
      final range = instanceRange((
        date: DateTime(2026, 9, 7),
        startMinutes: 9 * 60,
        endMinutes: 10 * 60 + 30,
      ));
      expect(
        range.startsAt,
        DateTime(2026, 9, 7, 9).toUtc().millisecondsSinceEpoch,
      );
      expect(
        range.endsAt,
        DateTime(2026, 9, 7, 10, 30).toUtc().millisecondsSinceEpoch,
      );
    });
  });

  group('mergeDates', () {
    test('skips dates already present and sorts by date', () {
      final existing = [
        (date: DateTime(2026, 9, 9), startMinutes: 600, endMinutes: 660),
      ];
      final merged = mergeDates(
        existing,
        [DateTime(2026, 9, 9), DateTime(2026, 9, 7)],
        startMinutes: 540,
        endMinutes: 600,
      );
      expect(merged.map((i) => i.date), [
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 9),
      ]);
      // The pre-existing 9th keeps its custom times.
      expect(merged[1].startMinutes, 600);
      expect(merged[0].startMinutes, 540);
    });
  });
}
