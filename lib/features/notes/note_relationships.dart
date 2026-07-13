import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';

typedef NoteLinkTarget = ({ParentType type, String id});

class NoteTargetOption {
  const NoteTargetOption({
    required this.target,
    required this.label,
    required this.route,
    required this.icon,
    this.workspaceId,
  });

  final NoteLinkTarget target;
  final String label;
  final String route;
  final IconData icon;
  final String? workspaceId;

  String get key => '${target.type.dbValue}:${target.id}';
}

List<NoteTargetOption> buildNoteTargetOptions({
  required Iterable<Workspace> workspaces,
  required Iterable<Contact> contacts,
  required Iterable<Project> projects,
  required Iterable<Task> tasks,
  required Iterable<Event> events,
  required Iterable<BillableItem> billables,
  required Iterable<TimerSession> timers,
}) {
  final options = <NoteTargetOption>[
    for (final workspace in workspaces)
      NoteTargetOption(
        target: (type: ParentType.workspace, id: workspace.id),
        label: workspace.name,
        route: '/workspaces/${workspace.id}',
        icon: Icons.workspaces_outline,
        workspaceId: workspace.id,
      ),
    for (final contact in contacts)
      NoteTargetOption(
        target: (type: ParentType.contact, id: contact.id),
        label: contact.name,
        route: '/contacts/${contact.id}',
        icon: Icons.person_outline_rounded,
      ),
    for (final project in projects)
      NoteTargetOption(
        target: (type: ParentType.project, id: project.id),
        label: project.name,
        route: '/work/projects/${project.id}',
        icon: Icons.layers_outlined,
        workspaceId: project.workspaceId,
      ),
    for (final task in tasks)
      NoteTargetOption(
        target: (type: ParentType.task, id: task.id),
        label: task.title,
        route: '/work/tasks/${task.id}',
        icon: Icons.task_alt_outlined,
        workspaceId: task.workspaceId,
      ),
    for (final event in events)
      NoteTargetOption(
        target: (type: ParentType.event, id: event.id),
        label: event.title,
        route: '/calendar/${event.id}',
        icon: Icons.event_outlined,
        workspaceId: event.workspaceId,
      ),
    for (final billable in billables)
      NoteTargetOption(
        target: (type: ParentType.billable, id: billable.id),
        label: billable.title,
        route: '/finance/${billable.id}',
        icon: Icons.receipt_long_outlined,
        workspaceId: billable.workspaceId,
      ),
    for (final timer in timers)
      NoteTargetOption(
        target: (type: ParentType.timerSession, id: timer.id),
        label: timer.description?.trim().isNotEmpty == true
            ? timer.description!.trim()
            : 'Timer session',
        route: '/finance/timers/${Uri.encodeComponent(timer.id)}',
        icon: Icons.timer_outlined,
        workspaceId: timer.workspaceId,
      ),
  ];
  options.sort((a, b) {
    final byType = a.target.type.index.compareTo(b.target.type.index);
    if (byType != 0) return byType;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return List.unmodifiable(options);
}

String noteTargetTypeLabel(AppLocalizations l10n, ParentType type) =>
    switch (type) {
      ParentType.workspace => l10n.workspaceLabel,
      ParentType.event => l10n.activityEvent,
      ParentType.task => l10n.tabTasks,
      ParentType.contact => l10n.contactLabel,
      ParentType.project => l10n.projectLabel,
      ParentType.billable => l10n.activityBillable,
      ParentType.timerSession => l10n.activityTimer,
    };

String noteTargetRoute(NoteLinkTarget target) => switch (target.type) {
  ParentType.workspace => '/workspaces/${target.id}',
  ParentType.event => '/calendar/${target.id}',
  ParentType.task => '/work/tasks/${target.id}',
  ParentType.contact => '/contacts/${target.id}',
  ParentType.project => '/work/projects/${target.id}',
  ParentType.billable => '/finance/${target.id}',
  ParentType.timerSession =>
    '/finance/timers/${Uri.encodeComponent(target.id)}',
};

IconData noteTargetIcon(ParentType type) => switch (type) {
  ParentType.workspace => Icons.workspaces_outline,
  ParentType.event => Icons.event_outlined,
  ParentType.task => Icons.task_alt_outlined,
  ParentType.contact => Icons.person_outline_rounded,
  ParentType.project => Icons.layers_outlined,
  ParentType.billable => Icons.receipt_long_outlined,
  ParentType.timerSession => Icons.timer_outlined,
};
