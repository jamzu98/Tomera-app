import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';

/// Agenda (list) view: one section per day with events and task deadlines
/// interleaved in time order (spec §6.2).
class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.days,
    required this.events,
    required this.tasks,
    required this.colorOf,
    required this.onEventTap,
    required this.onTaskTap,
  });

  /// Local midnights of the days to show, in order.
  final List<DateTime> days;
  final List<Event> events;
  final List<Task> tasks;
  final Color Function(String workspaceId) colorOf;
  final ValueChanged<Event> onEventTap;
  final ValueChanged<Task> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sections = <Widget>[];

    for (final day in days) {
      final dayStart = day.millisecondsSinceEpoch;
      final dayEnd =
          DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;

      final entries = <(int, Widget)>[
        for (final event in events)
          if (event.startsAt < dayEnd && event.endsAt > dayStart)
            (
              event.allDay ? dayStart : event.startsAt,
              _EventTile(
                event: event,
                color: colorOf(event.workspaceId),
                onTap: () => onEventTap(event),
              )
            ),
        for (final task in tasks)
          if (task.dueAt != null &&
              task.dueAt! >= dayStart &&
              task.dueAt! < dayEnd)
            (
              task.dueAt!,
              _TaskTile(task: task, onTap: () => onTaskTap(task))
            ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));

      if (entries.isEmpty) continue;
      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          DateFormat.MMMEd().format(day),
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ));
      sections.addAll(entries.map((e) => e.$2));
    }

    if (sections.isEmpty) {
      return Center(child: Text(l10n.emptyAgenda));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: sections,
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.color,
    required this.onTap,
  });

  final Event event;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat.Hm();
    final time = event.allDay
        ? l10n.allDayLabel
        : '${timeFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}'
            ' – '
            '${timeFormat.format(DateTime.fromMillisecondsSinceEpoch(event.endsAt, isUtc: true).toLocal())}';
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 14, color: color),
      title: Text(event.title),
      subtitle: Text(
          event.location?.isNotEmpty == true ? '$time · ${event.location}' : time),
      onTap: onTap,
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.done;
    return ListTile(
      dense: true,
      leading: Icon(
        done ? Icons.check_circle_outline : Icons.flag_outlined,
        size: 18,
        color: done ? theme.colorScheme.outline : theme.colorScheme.tertiary,
      ),
      title: Text(
        task.title,
        style: done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        '${l10n.taskDueLabel} · '
        '${DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: true).toLocal())}',
      ),
      onTap: onTap,
    );
  }
}
