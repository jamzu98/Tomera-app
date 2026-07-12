import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/status_ring.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'task_grouping.dart';
import 'task_providers.dart';

enum _GroupMode { status, dueDate }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _GroupMode _groupMode = _GroupMode.status;
  bool _overdueOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tasksValue = ref.watch(visibleTasksProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.tasks);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabTasks),
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-tasks',
        tooltip: l10n.newTask,
        onPressed: () => context.go('/tasks/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                SegmentedButton<_GroupMode>(
                  segments: [
                    ButtonSegment(
                      value: _GroupMode.status,
                      label: Text(l10n.groupByStatus),
                    ),
                    ButtonSegment(
                      value: _GroupMode.dueDate,
                      label: Text(l10n.groupByDueDate),
                    ),
                  ],
                  selected: {_groupMode},
                  onSelectionChanged: (selection) =>
                      setState(() => _groupMode = selection.first),
                ),
                const Spacer(),
                FilterChip(
                  label: Text(l10n.filterOverdue),
                  selected: _overdueOnly,
                  onSelected: (selected) =>
                      setState(() => _overdueOnly = selected),
                ),
              ],
            ),
          ),
          if (moduleDisabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.tasksModuleDisabled,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: switch (tasksValue) {
              AsyncValue(value: final tasks?) => _TaskList(
                  tasks: _overdueOnly
                      ? tasks
                          .where((t) => isOverdue(t, DateTime.now()))
                          .toList()
                      : tasks,
                  groupMode: _groupMode,
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.groupMode});

  final List<Task> tasks;
  final _GroupMode groupMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_rounded,
        title: l10n.emptyTasksTitle,
        body: l10n.emptyTasksBody,
      );
    }

    final sections = <(String, Color, List<Task>)>[];
    if (groupMode == _GroupMode.status) {
      for (final entry in groupByStatus(tasks).entries) {
        final color = switch (entry.key) {
          TaskStatus.open => theme.colorScheme.onSurface,
          TaskStatus.inProgress => const Color(0xFF7C7FF2),
          TaskStatus.done => tokens.success,
        };
        sections.add((_statusLabel(l10n, entry.key), color, entry.value));
      }
    } else {
      for (final entry in groupByDueDate(tasks, DateTime.now()).entries) {
        final color = switch (entry.key) {
          DueSection.overdue => tokens.overdue,
          DueSection.today => theme.colorScheme.onSurface,
          _ => tokens.ink3,
        };
        sections.add((_dueSectionLabel(l10n, entry.key), color, entry.value));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final (title, color, sectionTasks) in sections) ...[
          GroupHeader(title: title, color: color, count: sectionTasks.length),
          for (final task in sectionTasks) _TaskTile(task: task),
        ],
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final overdue = isOverdue(task, DateTime.now());
    final dueAt = task.dueAt;
    final done = task.status == TaskStatus.done;

    // One-tap status ring: open -> in progress -> done.
    final (statusIcon, statusColor, statusFilled) = switch (task.status) {
      TaskStatus.open =>
        (Icons.radio_button_unchecked_rounded, tokens.ink3, false),
      TaskStatus.inProgress =>
        (Icons.timelapse_rounded, const Color(0xFF7C7FF2), false),
      TaskStatus.done => (Icons.check_rounded, tokens.success, true),
    };

    return SoftTile(
      leading: StatusRing(
        icon: statusIcon,
        color: statusColor,
        filled: statusFilled,
        size: 32,
        onTap: () {
          // Completing a task cancels its pending reminder (spec §6.3).
          if (task.status == TaskStatus.inProgress) {
            ref.read(reminderCoordinatorProvider).cancelTaskReminder(task.id);
          }
          ref.read(taskRepositoryProvider).cycleStatus(task);
        },
      ),
      title: Text(
        task.title,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationThickness: 1.5,
                color: tokens.ink3,
              )
            : null,
      ),
      subtitle: dueAt != null
          ? Row(
              children: [
                Icon(
                  overdue
                      ? Icons.event_busy_rounded
                      : (done
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded),
                  size: 14,
                  color: overdue ? tokens.overdue : tokens.ink2,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    DateFormat.yMMMEd().add_Hm().format(
                        DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true)
                            .toLocal()),
                    overflow: TextOverflow.ellipsis,
                    style: overdue
                        ? TextStyle(
                            color: tokens.overdue, fontWeight: FontWeight.w600)
                        : null,
                  ),
                ),
              ],
            )
          : null,
      trailing: task.priority != TaskPriority.normal
          ? Icon(
              task.priority == TaskPriority.high
                  ? Icons.keyboard_double_arrow_up_rounded
                  : Icons.keyboard_double_arrow_down_rounded,
              size: 22,
              color: task.priority == TaskPriority.high
                  ? tokens.overdue
                  : tokens.ink3,
            )
          : null,
      onTap: () => context.go('/tasks/${task.id}'),
    );
  }
}

String _statusLabel(AppLocalizations l10n, TaskStatus status) =>
    switch (status) {
      TaskStatus.open => l10n.statusOpen,
      TaskStatus.inProgress => l10n.statusInProgress,
      TaskStatus.done => l10n.statusDone,
    };

String _dueSectionLabel(AppLocalizations l10n, DueSection section) =>
    switch (section) {
      DueSection.overdue => l10n.dueSectionOverdue,
      DueSection.today => l10n.dueSectionToday,
      DueSection.thisWeek => l10n.dueSectionThisWeek,
      DueSection.later => l10n.dueSectionLater,
      DueSection.noDueDate => l10n.dueSectionNoDueDate,
    };
