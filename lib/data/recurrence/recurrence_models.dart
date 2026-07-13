import '../db/enums.dart';

class EventSeriesTemplate {
  const EventSeriesTemplate({
    required this.workspaceId,
    required this.title,
    required this.localStartsAt,
    required this.duration,
    required this.timezoneId,
    this.description,
    this.location,
    this.allDay = false,
    this.projectId,
    this.contactIds = const {},
    this.reminderOffsetMinutes,
  });

  final String workspaceId;
  final String title;
  final String? description;
  final String? location;
  final DateTime localStartsAt;
  final Duration duration;
  final String timezoneId;
  final bool allDay;
  final String? projectId;
  final Set<String> contactIds;
  final int? reminderOffsetMinutes;
}

class TaskSeriesTemplate {
  const TaskSeriesTemplate({
    required this.workspaceId,
    required this.title,
    required this.firstDueLocal,
    required this.timezoneId,
    this.description,
    this.priority = TaskPriority.normal,
    this.contactId,
    this.projectId,
    this.reminderOffsetMinutes,
  });

  final String workspaceId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime firstDueLocal;
  final String timezoneId;
  final String? contactId;
  final String? projectId;
  final int? reminderOffsetMinutes;
}

class RecurringEventCreation {
  const RecurringEventCreation({
    required this.seriesId,
    required this.occurrenceIds,
  });

  final String seriesId;
  final List<String> occurrenceIds;
}

class RepeatingTaskCreation {
  const RepeatingTaskCreation({
    required this.seriesId,
    required this.firstTaskId,
  });

  final String seriesId;
  final String firstTaskId;
}

class TaskCompletionResult {
  const TaskCompletionResult({required this.taskId, this.successorTaskId});

  final String taskId;
  final String? successorTaskId;
}
