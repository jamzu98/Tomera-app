import '../../data/db/database.dart';

/// An event placed in a horizontal lane so overlapping events render side by
/// side instead of on top of each other.
class LaidOutEvent {
  const LaidOutEvent(this.event, this.lane, this.laneCount);

  final Event event;

  /// Zero-based lane within the overlap cluster.
  final int lane;

  /// Total lanes in this event's overlap cluster.
  final int laneCount;
}

/// Greedy lane assignment for one day column. [events] must be non-all-day
/// and are processed in start order; each cluster of transitively-overlapping
/// events shares its lane count so widths divide evenly.
List<LaidOutEvent> layoutEvents(List<Event> events) {
  final sorted = [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final result = <LaidOutEvent>[];

  var cluster = <(Event, int)>[];
  var laneEnds = <int>[];
  var clusterEnd = 0;

  void flush() {
    for (final (event, lane) in cluster) {
      result.add(LaidOutEvent(event, lane, laneEnds.length));
    }
    cluster = [];
    laneEnds = [];
  }

  for (final event in sorted) {
    if (cluster.isNotEmpty && event.startsAt >= clusterEnd) flush();
    var lane = laneEnds.indexWhere((end) => end <= event.startsAt);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(event.endsAt);
    } else {
      laneEnds[lane] = event.endsAt;
    }
    cluster.add((event, lane));
    if (event.endsAt > clusterEnd) clusterEnd = event.endsAt;
  }
  flush();
  return result;
}
