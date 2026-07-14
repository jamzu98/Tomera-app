import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/editorial.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_sheet.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/status_ring.dart';
import '../../core/widgets/work_section_switcher.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../settings/date_time_format.dart';
import 'task_grouping.dart';
import 'task_providers.dart';

enum TaskGroupMode { status, dueDate }

@immutable
class TaskListSessionState {
  const TaskListSessionState({
    this.groupMode = TaskGroupMode.status,
    this.overdueOnly = false,
  });

  final TaskGroupMode groupMode;
  final bool overdueOnly;

  TaskListSessionState copyWith({
    TaskGroupMode? groupMode,
    bool? overdueOnly,
  }) => TaskListSessionState(
    groupMode: groupMode ?? this.groupMode,
    overdueOnly: overdueOnly ?? this.overdueOnly,
  );
}

class TaskListSession extends Notifier<TaskListSessionState> {
  @override
  TaskListSessionState build() => const TaskListSessionState();

  void setGroupMode(TaskGroupMode value) =>
      state = state.copyWith(groupMode: value);

  void setOverdueOnly(bool value) => state = state.copyWith(overdueOnly: value);
}

final taskListSessionProvider =
    NotifierProvider<TaskListSession, TaskListSessionState>(
      TaskListSession.new,
    );

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context)!;
          final overdueOnly = ref.read(taskListSessionProvider).overdueOnly;
          return FilterSheetScaffold(
            title: l10n.filtersLabel,
            clearAllLabel: l10n.clearFilters,
            onClearAll: overdueOnly
                ? () {
                    ref
                        .read(taskListSessionProvider.notifier)
                        .setOverdueOnly(false);
                    setSheetState(() {});
                  }
                : null,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.filterOverdue),
              value: overdueOnly,
              onChanged: (value) {
                ref
                    .read(taskListSessionProvider.notifier)
                    .setOverdueOnly(value);
                setSheetState(() {});
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(taskListSessionProvider);
    final tasksValue = ref.watch(visibleTasksProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled =
        selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.tasks);

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      body: Column(
        children: [
          EditorialScreenHeader(
            title: l10n.tabWork,
            subtitle: l10n.tabTasks,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          ),
          const WorkSectionSwitcher(selected: WorkSection.tasks),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<TaskGroupMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TaskGroupMode.status,
                      label: Text(l10n.groupByStatus),
                    ),
                    ButtonSegment(
                      value: TaskGroupMode.dueDate,
                      label: Text(l10n.groupByDueDate),
                    ),
                  ],
                  selected: {session.groupMode},
                  onSelectionChanged: (selection) => ref
                      .read(taskListSessionProvider.notifier)
                      .setGroupMode(selection.first),
                ),
                FilterButton(
                  label: l10n.filtersLabel,
                  activeCount: session.overdueOnly ? 1 : 0,
                  onPressed: _showFilters,
                ),
              ],
            ),
          ),
          Expanded(
            child: moduleDisabled
                ? EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: l10n.moduleDisabledTitle,
                    body: l10n.tasksModuleDisabled,
                    primaryAction: EmptyStateAction(
                      label: l10n.editWorkspace,
                      icon: Icons.tune_rounded,
                      onPressed: () =>
                          context.push('/workspaces/${selectedWorkspace.id}'),
                    ),
                  )
                : switch (tasksValue) {
                    AsyncValue(value: final tasks?) => _TaskList(
                      tasks: session.overdueOnly
                          ? tasks
                                .where((t) => isOverdue(t, DateTime.now()))
                                .toList()
                          : tasks,
                      groupMode: session.groupMode,
                      onCreate: () => context.go('/work/tasks/new'),
                      onClearFilters: session.overdueOnly && tasks.isNotEmpty
                          ? () => ref
                                .read(taskListSessionProvider.notifier)
                                .setOverdueOnly(false)
                          : null,
                    ),
                    AsyncValue(isLoading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _ => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.unableToLoadTitle,
                      body: l10n.unableToLoadBody,
                      retryLabel: l10n.retry,
                      onRetry: () => ref.invalidate(visibleTasksProvider),
                    ),
                  },
          ),
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.tasks,
    required this.groupMode,
    required this.onCreate,
    this.onClearFilters,
  });

  final List<Task> tasks;
  final TaskGroupMode groupMode;
  final VoidCallback onCreate;
  final VoidCallback? onClearFilters;

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
        primaryAction: EmptyStateAction(
          label: l10n.newTask,
          icon: Icons.add_rounded,
          onPressed: onCreate,
        ),
        secondaryAction: onClearFilters == null
            ? null
            : EmptyStateAction(
                label: l10n.clearFilters,
                onPressed: onClearFilters!,
              ),
      );
    }

    final sections = <(String, Color, List<Task>)>[];
    if (groupMode == TaskGroupMode.status) {
      for (final entry in groupByStatus(tasks).entries) {
        final color = switch (entry.key) {
          TaskStatus.open => theme.colorScheme.onSurface,
          TaskStatus.inProgress => tokens.warning,
          TaskStatus.done => tokens.success,
        };
        sections.add((_statusLabel(l10n, entry.key), color, entry.value));
      }
    } else {
      for (final entry in groupByDueDate(tasks, DateTime.now()).entries) {
        final color = switch (entry.key) {
          DueSection.overdue => tokens.danger,
          DueSection.today => theme.colorScheme.onSurface,
          _ => tokens.textTertiary,
        };
        sections.add((_dueSectionLabel(l10n, entry.key), color, entry.value));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final (title, color, sectionTasks) in sections) ...[
          GroupHeader(title: title, color: color, count: sectionTasks.length),
          EditorialPanel(
            children: [
              for (final task in sectionTasks)
                _TaskTile(task: task, embedded: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, this.embedded = false});

  final Task task;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final overdue = isOverdue(task, DateTime.now());
    final dueAt = task.dueAt;
    final done = task.status == TaskStatus.done;

    // One-tap status ring: open -> in progress -> done.
    final (statusIcon, statusColor, statusFilled) = switch (task.status) {
      TaskStatus.open => (
        Icons.radio_button_unchecked_rounded,
        tokens.textTertiary,
        false,
      ),
      TaskStatus.inProgress => (Icons.timelapse_rounded, tokens.warning, false),
      TaskStatus.done => (Icons.check_rounded, tokens.success, true),
    };

    return SoftTile(
      embedded: embedded,
      margin: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: StatusRing(
        icon: statusIcon,
        color: statusColor,
        filled: statusFilled,
        size: 32,
        onTap: () async {
          final previous = task.status;
          final next = switch (previous) {
            TaskStatus.open => TaskStatus.inProgress,
            TaskStatus.inProgress => TaskStatus.done,
            TaskStatus.done => TaskStatus.open,
          };
          final repository = ref.read(taskRepositoryProvider);
          final reminders = ref.read(reminderCoordinatorProvider);
          String? successorId;
          // Recurring completion and reopen are transactional with successor
          // creation/removal. Ordinary status changes keep the lightweight
          // update path.
          try {
            if (next == TaskStatus.done) {
              final result = await repository.complete(task.id);
              successorId = result.successorTaskId;
            } else if (previous == TaskStatus.done) {
              successorId = await repository.undoCompletion(task.id, next);
            } else {
              await repository.update(task.id, status: next);
            }
          } on StateError {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.cannotReopenRecurringTask)),
              );
            }
            return;
          }
          try {
            if (next == TaskStatus.done) {
              await reminders.cancelTaskReminder(task.id);
              if (successorId != null) {
                final successor = await repository.getById(successorId);
                if (successor != null) {
                  await reminders.syncTaskReminder(
                    taskId: successor.id,
                    title: successor.title,
                    reminderAtMs: successor.reminderAt,
                  );
                }
              }
            } else {
              await reminders.syncTaskReminder(
                taskId: task.id,
                title: task.title,
                reminderAtMs: task.reminderAt,
              );
              if (successorId != null) {
                await reminders.cancelTaskReminder(successorId);
              }
            }
          } on Object {
            // Cold-start reconciliation repairs device-only notification
            // state; the database remains authoritative.
          }
          if (!context.mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.taskStatusChanged),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () async {
                  String? undoSuccessorId;
                  try {
                    if (next == TaskStatus.done) {
                      undoSuccessorId = await repository.undoCompletion(
                        task.id,
                        previous,
                      );
                    } else if (previous == TaskStatus.done) {
                      final result = await repository.complete(
                        task.id,
                        completedAtMs: task.completedAt,
                      );
                      undoSuccessorId = result.successorTaskId;
                    } else {
                      await repository.update(task.id, status: previous);
                    }
                  } on StateError {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.cannotReopenRecurringTask)),
                    );
                    return;
                  }
                  try {
                    if (previous == TaskStatus.done) {
                      await reminders.cancelTaskReminder(task.id);
                      if (undoSuccessorId != null) {
                        final successor = await repository.getById(
                          undoSuccessorId,
                        );
                        if (successor != null) {
                          await reminders.syncTaskReminder(
                            taskId: successor.id,
                            title: successor.title,
                            reminderAtMs: successor.reminderAt,
                          );
                        }
                      }
                    } else {
                      await reminders.syncTaskReminder(
                        taskId: task.id,
                        title: task.title,
                        reminderAtMs: task.reminderAt,
                      );
                      if (undoSuccessorId != null) {
                        await reminders.cancelTaskReminder(undoSuccessorId);
                      }
                    }
                  } on Object {
                    // Reconciled from persisted task state on next start.
                  }
                },
              ),
            ),
          );
        },
      ),
      title: Text(
        task.title,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationThickness: 1.5,
                color: tokens.textTertiary,
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
                  color: overdue ? tokens.danger : tokens.textSecondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    () {
                      final due = DateTime.fromMillisecondsSinceEpoch(
                        dueAt,
                        isUtc: true,
                      ).toLocal();
                      return '${DateFormat.yMMMEd().format(due)} '
                          '${appTimeFormat(context, ref).format(due)}';
                    }(),
                    overflow: TextOverflow.ellipsis,
                    style: overdue
                        ? TextStyle(
                            color: tokens.danger,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
                ),
              ],
            )
          : null,
      trailing:
          task.taskSeriesId != null || task.priority != TaskPriority.normal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.taskSeriesId != null)
                  Tooltip(
                    message: l10n.recurringSeriesContext,
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 20,
                      color: tokens.textTertiary,
                    ),
                  ),
                if (task.taskSeriesId != null &&
                    task.priority != TaskPriority.normal)
                  const SizedBox(width: 6),
                if (task.priority != TaskPriority.normal)
                  Icon(
                    task.priority == TaskPriority.high
                        ? Icons.keyboard_double_arrow_up_rounded
                        : Icons.keyboard_double_arrow_down_rounded,
                    size: 22,
                    color: task.priority == TaskPriority.high
                        ? tokens.danger
                        : tokens.textTertiary,
                  ),
              ],
            )
          : null,
      onTap: () => context.go('/work/tasks/${task.id}'),
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
