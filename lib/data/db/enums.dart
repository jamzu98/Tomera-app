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
  contact('contact');

  const ParentType(this.dbValue);

  @override
  final String dbValue;
}
