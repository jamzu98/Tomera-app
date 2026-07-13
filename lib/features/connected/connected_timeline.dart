import '../../data/db/database.dart';

enum ConnectedActivityType { event, completedTask, note, timer, billable }

class ConnectedActivity {
  const ConnectedActivity({
    required this.type,
    required this.id,
    required this.title,
    required this.timestamp,
    required this.route,
  });

  final ConnectedActivityType type;
  final String id;
  final String title;
  final int timestamp;
  final String route;
}

/// Produces a typed, deterministic timeline directly from source records.
/// No opaque activity-log rows are persisted, so edits and soft-deletes are
/// reflected immediately by the source providers.
List<ConnectedActivity> buildConnectedTimeline({
  Iterable<Event> events = const [],
  Iterable<Task> tasks = const [],
  Iterable<Note> notes = const [],
  Iterable<TimerSession> timers = const [],
  Iterable<BillableItem> billables = const [],
}) {
  final activities = <ConnectedActivity>[
    for (final event in events)
      ConnectedActivity(
        type: ConnectedActivityType.event,
        id: event.id,
        title: event.title,
        timestamp: event.startsAt,
        route: '/calendar/${event.id}',
      ),
    for (final task in tasks)
      if (task.completedAt case final completedAt?)
        ConnectedActivity(
          type: ConnectedActivityType.completedTask,
          id: task.id,
          title: task.title,
          timestamp: completedAt,
          route: '/work/tasks/${task.id}',
        ),
    for (final note in notes)
      ConnectedActivity(
        type: ConnectedActivityType.note,
        id: note.id,
        title: note.title,
        timestamp: note.updatedAt,
        route: '/work/notes/${note.id}',
      ),
    for (final timer in timers)
      ConnectedActivity(
        type: ConnectedActivityType.timer,
        id: timer.id,
        title: timer.description?.trim().isNotEmpty == true
            ? timer.description!.trim()
            : 'Timer session',
        timestamp: timer.stoppedAt ?? timer.startedAt,
        route: '/finance/timers/${Uri.encodeComponent(timer.id)}',
      ),
    for (final billable in billables)
      ConnectedActivity(
        type: ConnectedActivityType.billable,
        id: billable.id,
        title: billable.title,
        timestamp: billable.createdAt,
        route: '/finance/${billable.id}',
      ),
  ];
  activities.sort((a, b) {
    final byTime = b.timestamp.compareTo(a.timestamp);
    if (byTime != 0) return byTime;
    final byType = a.type.index.compareTo(b.type.index);
    return byType != 0 ? byType : a.id.compareTo(b.id);
  });
  return List.unmodifiable(activities);
}
