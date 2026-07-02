import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
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
        actions: const [WorkspaceFilterButton(), WorkspacesButton()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newTask,
        onPressed: () => context.go('/tasks/new'),
        child: const Icon(Icons.add),
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
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.emptyTasksTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.emptyTasksBody),
          ],
        ),
      );
    }

    final sections = <(String, List<Task>)>[];
    if (groupMode == _GroupMode.status) {
      for (final entry in groupByStatus(tasks).entries) {
        sections.add((_statusLabel(l10n, entry.key), entry.value));
      }
    } else {
      for (final entry in groupByDueDate(tasks, DateTime.now()).entries) {
        sections.add((_dueSectionLabel(l10n, entry.key), entry.value));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final (title, sectionTasks) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
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
    final theme = Theme.of(context);
    final overdue = isOverdue(task, DateTime.now());
    final dueAt = task.dueAt;

    return ListTile(
      leading: IconButton(
        icon: Icon(switch (task.status) {
          TaskStatus.open => Icons.radio_button_unchecked,
          TaskStatus.inProgress => Icons.timelapse,
          TaskStatus.done => Icons.check_circle,
        }),
        color: switch (task.status) {
          TaskStatus.open => theme.colorScheme.outline,
          TaskStatus.inProgress => theme.colorScheme.tertiary,
          TaskStatus.done => theme.colorScheme.primary,
        },
        onPressed: () => ref.read(taskRepositoryProvider).cycleStatus(task),
      ),
      title: Text(
        task.title,
        style: task.status == TaskStatus.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: dueAt != null
          ? Text(
              DateFormat.yMMMEd().add_Hm().format(
                  DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true)
                      .toLocal()),
              style: overdue
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            )
          : null,
      trailing: task.priority != TaskPriority.normal
          ? Icon(
              task.priority == TaskPriority.high
                  ? Icons.keyboard_double_arrow_up
                  : Icons.keyboard_double_arrow_down,
              color: task.priority == TaskPriority.high
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
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
