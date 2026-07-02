import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/features/finance/timer_math.dart';

void main() {
  group('elapsedMs', () {
    test('is the difference between now and start', () {
      expect(elapsedMs(startedAtMs: 1000, nowMs: 61000), 60000);
    });

    test('clamps clock skew to zero', () {
      expect(elapsedMs(startedAtMs: 61000, nowMs: 1000), 0);
    });
  });

  group('roundedDurationMinutes', () {
    test('no rounding: partial minutes round up, minimum one minute', () {
      expect(roundedDurationMinutes(0, 0), 1);
      expect(roundedDurationMinutes(59999, 0), 1);
      expect(roundedDurationMinutes(60000, 0), 1);
      expect(roundedDurationMinutes(60001, 0), 2);
      expect(roundedDurationMinutes(25 * 60000, 0), 25);
    });

    test('rounds up to the step (spec §6.6)', () {
      expect(roundedDurationMinutes(1 * 60000, 15), 15);
      expect(roundedDurationMinutes(15 * 60000, 15), 15);
      expect(roundedDurationMinutes(16 * 60000, 15), 30);
      expect(roundedDurationMinutes(21 * 60000, 5), 25);
      expect(roundedDurationMinutes(29 * 60000, 30), 30);
      expect(roundedDurationMinutes(31 * 60000, 30), 60);
    });

    test('a just-started timer bills the full first step', () {
      expect(roundedDurationMinutes(1000, 15), 15);
    });
  });

  group('formatElapsed', () {
    test('formats H:MM:SS', () {
      expect(formatElapsed(0), '0:00:00');
      expect(formatElapsed(59000), '0:00:59');
      expect(formatElapsed(61000), '0:01:01');
      expect(formatElapsed(3661000), '1:01:01');
      expect(formatElapsed(36000000), '10:00:00');
    });
  });
}
