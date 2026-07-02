import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/features/calendar/event_layout.dart';

import 'conflict_test.dart' show makeEvent;

void main() {
  group('layoutEvents', () {
    test('non-overlapping events each get a full-width lane', () {
      final laid = layoutEvents([
        makeEvent(id: 'a', start: 0, end: 10),
        makeEvent(id: 'b', start: 10, end: 20),
      ]);
      expect(laid, hasLength(2));
      for (final placed in laid) {
        expect(placed.lane, 0);
        expect(placed.laneCount, 1);
      }
    });

    test('two overlapping events split into two lanes', () {
      final laid = layoutEvents([
        makeEvent(id: 'a', start: 0, end: 20),
        makeEvent(id: 'b', start: 10, end: 30),
      ]);
      expect(laid.map((p) => p.lane).toSet(), {0, 1});
      expect(laid.every((p) => p.laneCount == 2), isTrue);
    });

    test('a lane is reused once its previous event has ended', () {
      final laid = layoutEvents([
        makeEvent(id: 'a', start: 0, end: 30),
        makeEvent(id: 'b', start: 0, end: 10),
        makeEvent(id: 'c', start: 10, end: 20),
      ]);
      final byId = {for (final p in laid) p.event.id: p};
      expect(byId['b']!.lane, byId['c']!.lane);
      expect(laid.every((p) => p.laneCount == 2), isTrue);
    });
  });
}
