/// Enums stored as TEXT in the database.
///
/// Each enum carries an explicit [dbValue] so the persisted strings match the
/// spec (`in_progress`, not `inProgress`) and stay stable if Dart names are
/// ever refactored — important once rows sync to a server.
library;

abstract interface class DbEnum {
  String get dbValue;
}

enum ModuleKey implements DbEnum {
  calendar('calendar'),
  tasks('tasks'),
  notes('notes'),
  contacts('contacts'),
  finance('finance');

  const ModuleKey(this.dbValue);

  @override
  final String dbValue;
}

enum TaskStatus implements DbEnum {
  open('open'),
  inProgress('in_progress'),
  done('done');

  const TaskStatus(this.dbValue);

  @override
  final String dbValue;
}

enum TaskPriority implements DbEnum {
  low('low'),
  normal('normal'),
  high('high');

  const TaskPriority(this.dbValue);

  @override
  final String dbValue;
}

/// User-facing edit/delete scope for a materialized recurrence occurrence.
enum RecurrenceEditScope { occurrence, currentAndFuture }

/// The instant from which a repeating task's next due date advances.
enum TaskRepeatAnchor implements DbEnum {
  schedule('schedule'),
  completion('completion');

  const TaskRepeatAnchor(this.dbValue);

  @override
  final String dbValue;
}

enum BillableType implements DbEnum {
  hourly('hourly'),
  fixed('fixed');

  const BillableType(this.dbValue);

  @override
  final String dbValue;
}

enum BillableStatus implements DbEnum {
  unbilled('unbilled'),
  invoiced('invoiced'),
  paid('paid');

  const BillableStatus(this.dbValue);

  @override
  final String dbValue;
}

/// Polymorphic parent for notes and reminders.
enum ParentType implements DbEnum {
  workspace('workspace'),
  event('event'),
  task('task'),
  contact('contact'),
  project('project'),
  billable('billable'),
  timerSession('timer_session');

  const ParentType(this.dbValue);

  @override
  final String dbValue;
}
