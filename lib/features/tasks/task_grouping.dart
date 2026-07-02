import '../../data/db/database.dart';

/// Sections for the "by due date" grouping, in display order.
enum DueSection { overdue, today, thisWeek, later, noDueDate }

/// Groups tasks by status in the order open → in progress → done.
/// Statuses with no tasks are omitted.
Map<TaskStatus, List<Task>> groupByStatus(List<Task> tasks) {
  final grouped = <TaskStatus, List<Task>>{};
  for (final status in TaskStatus.values) {
    final section = tasks.where((t) => t.status == status).toList();
    if (section.isNotEmpty) grouped[status] = section;
  }
  return grouped;
}

/// Groups tasks into due-date buckets relative to [now] (local time).
/// Sections with no tasks are omitted.
Map<DueSection, List<Task>> groupByDueDate(List<Task> tasks, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final nextWeek = today.add(const Duration(days: 7));

  DueSection sectionOf(Task task) {
    final dueAt = task.dueAt;
    if (dueAt == null) return DueSection.noDueDate;
    final due =
        DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true).toLocal();
    if (due.isBefore(now)) return DueSection.overdue;
    if (due.isBefore(tomorrow)) return DueSection.today;
    if (due.isBefore(nextWeek)) return DueSection.thisWeek;
    return DueSection.later;
  }

  final grouped = <DueSection, List<Task>>{};
  for (final section in DueSection.values) {
    final matches = tasks.where((t) => sectionOf(t) == section).toList();
    if (matches.isNotEmpty) grouped[section] = matches;
  }
  return grouped;
}

/// True when the task is past due and not done, relative to [now].
bool isOverdue(Task task, DateTime now) =>
    task.dueAt != null &&
    task.status != TaskStatus.done &&
    task.dueAt! < now.toUtc().millisecondsSinceEpoch;
