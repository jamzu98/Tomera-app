import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/calendar/conflict.dart';

Event makeEvent({
  required String id,
  required int start,
  required int end,
  bool allDay = false,
  String workspaceId = 'w1',
}) =>
    Event(
      id: id,
      ownerId: null,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: null,
      isDirty: true,
      workspaceId: workspaceId,
      title: id,
      description: null,
      location: null,
      startsAt: start,
      endsAt: end,
      allDay: allDay,
      rrule: null,
    );

void main() {
  group('rangesOverlap', () {
    test('detects a partial overlap', () {
      expect(rangesOverlap(10, 20, 15, 25), isTrue);
      expect(rangesOverlap(15, 25, 10, 20), isTrue);
    });

    test('detects a fully contained range', () {
      expect(rangesOverlap(10, 20, 12, 18), isTrue);
      expect(rangesOverlap(12, 18, 10, 20), isTrue);
    });

    test('identical ranges overlap', () {
      expect(rangesOverlap(10, 20, 10, 20), isTrue);
    });

    test('touching boundaries do NOT overlap (half-open ranges)', () {
      expect(rangesOverlap(10, 20, 20, 30), isFalse);
      expect(rangesOverlap(20, 30, 10, 20), isFalse);
    });

    test('disjoint ranges do not overlap', () {
      expect(rangesOverlap(10, 20, 30, 40), isFalse);
    });
  });

  group('findConflictingEvents', () {
    test('finds conflicts across different workspaces', () {
      final conflicts = findConflictingEvents(
        candidates: [
          makeEvent(id: 'a', start: 10, end: 20, workspaceId: 'w1'),
          makeEvent(id: 'b', start: 15, end: 25, workspaceId: 'w2'),
        ],
        startMs: 18,
        endMs: 22,
      );
      expect(conflicts.map((e) => e.id), ['a', 'b']);
    });

    test('excludes the event being edited', () {
      final conflicts = findConflictingEvents(
        candidates: [makeEvent(id: 'a', start: 10, end: 20)],
        startMs: 10,
        endMs: 20,
        excludeEventId: 'a',
      );
      expect(conflicts, isEmpty);
    });

    test('all-day events never conflict', () {
      final conflicts = findConflictingEvents(
        candidates: [makeEvent(id: 'a', start: 0, end: 100, allDay: true)],
        startMs: 10,
        endMs: 20,
      );
      expect(conflicts, isEmpty);
    });

    test('back-to-back events do not conflict', () {
      final conflicts = findConflictingEvents(
        candidates: [makeEvent(id: 'a', start: 10, end: 20)],
        startMs: 20,
        endMs: 30,
      );
      expect(conflicts, isEmpty);
    });
  });
}
