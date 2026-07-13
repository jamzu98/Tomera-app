import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/connected/connected_timeline.dart';

void main() {
  test('typed connected timeline merges source records by timestamp', () {
    final event = Event(
      id: 'event',
      createdAt: 1,
      updatedAt: 1,
      isDirty: false,
      workspaceId: 'workspace',
      title: 'Review',
      startsAt: 300,
      endsAt: 400,
      allDay: false,
    );
    final completedTask = Task(
      id: 'task-done',
      createdAt: 1,
      updatedAt: 1,
      isDirty: false,
      workspaceId: 'workspace',
      title: 'Ship',
      status: TaskStatus.done,
      priority: TaskPriority.normal,
      completedAt: 500,
    );
    final openTask = Task(
      id: 'task-open',
      createdAt: 1,
      updatedAt: 600,
      isDirty: false,
      workspaceId: 'workspace',
      title: 'Draft',
      status: TaskStatus.open,
      priority: TaskPriority.normal,
    );
    final note = Note(
      id: 'note',
      createdAt: 1,
      updatedAt: 200,
      isDirty: false,
      title: 'Notes',
      body: '',
    );
    final timer = TimerSession(
      id: 'timer',
      createdAt: 1,
      updatedAt: 1,
      isDirty: false,
      workspaceId: 'workspace',
      startedAt: 50,
      stoppedAt: 450,
    );

    final result = buildConnectedTimeline(
      events: [event],
      tasks: [openTask, completedTask],
      notes: [note],
      timers: [timer],
    );

    expect(result.map((entry) => entry.id), [
      'task-done',
      'timer',
      'event',
      'note',
    ]);
    expect(
      result.map((entry) => entry.type),
      containsAll(<ConnectedActivityType>{
        ConnectedActivityType.completedTask,
        ConnectedActivityType.timer,
        ConnectedActivityType.event,
        ConnectedActivityType.note,
      }),
    );
    expect(
      result.singleWhere((entry) => entry.id == 'timer').route,
      '/finance/timers/timer',
    );
  });
}
