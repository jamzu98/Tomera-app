import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/more_options_section.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../data/recurrence/recurrence_models.dart';
import '../../data/recurrence/recurrence_rule.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../notes/note_backlinks_section.dart';
import '../projects/project_providers.dart';
import '../recurrence/local_timezone.dart';
import '../recurrence/recurrence_editor.dart';
import '../settings/date_time_format.dart';
import 'task_providers.dart';

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({
    super.key,
    this.taskId,
    this.initialWorkspaceId,
    this.initialContactId,
    this.initialProjectId,
    this.initialTitle,
    this.initialDescription,
    this.sourceNoteId,
  });

  /// Null when creating a new task.
  final String? taskId;

  final String? initialWorkspaceId;
  final String? initialContactId;

  /// Pre-selected project when created from a project detail screen.
  final String? initialProjectId;
  final String? initialTitle;
  final String? initialDescription;

  /// Existing note whose selected text started this task. The note receives
  /// a durable task reference after the task is saved.
  final String? sourceNoteId;

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _workspaceId;
  String? _contactId;
  String? _projectId;
  TaskPriority _priority = TaskPriority.normal;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.initialWorkspaceId;
    _contactId = widget.initialContactId;
    _projectId = widget.initialProjectId;
    _titleController.text = widget.initialTitle ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
  }

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderAt;
  bool _initialized = false;
  bool _seriesInitialized = false;
  List<Object?>? _baseline;
  bool _isDirty = false;
  late RecurrenceEditorValue _recurrence = RecurrenceEditorValue.disabled();

  bool get _isNew => widget.taskId == null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFrom(Task task) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _workspaceId = task.workspaceId;
    _contactId = task.contactId;
    _projectId = task.projectId;
    _priority = task.priority;
    final dueAt = task.dueAt;
    if (dueAt != null) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        dueAt,
        isUtc: true,
      ).toLocal();
      _dueDate = DateTime(local.year, local.month, local.day);
      _dueTime = TimeOfDay.fromDateTime(local);
    }
    final reminderAt = task.reminderAt;
    if (reminderAt != null) {
      _reminderAt = DateTime.fromMillisecondsSinceEpoch(
        reminderAt,
        isUtc: true,
      ).toLocal();
    }
  }

  void _initSeries(TaskSeriesRecord series) {
    if (_seriesInitialized) return;
    _seriesInitialized = true;
    _recurrence = RecurrenceEditorValue(
      enabled: true,
      rule: RecurrenceRule.decode(series.ruleJson),
      taskAnchor: series.repeatAnchor,
    );
  }

  int? get _dueAtMs {
    final date = _dueDate;
    if (date == null) return null;
    final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc().millisecondsSinceEpoch;
  }

  List<Object?> _snapshot() => [
    _titleController.text,
    _descriptionController.text,
    _workspaceId,
    _contactId,
    _projectId,
    _priority,
    _dueDate,
    _dueTime,
    _reminderAt,
    _recurrence.enabled,
    _recurrence.rule.encode(),
    _recurrence.taskAnchor,
  ];

  void _captureBaseline() => _baseline ??= _snapshot();

  void _syncDirty() {
    final baseline = _baseline;
    if (baseline == null || !mounted) return;
    final isDirty = !listEquals(baseline, _snapshot());
    if (isDirty != _isDirty) setState(() => _isDirty = isDirty);
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      final baseline = _baseline;
      if (baseline != null) {
        _isDirty = !listEquals(baseline, _snapshot());
      }
    });
  }

  void _clearDirtyAndPop({VoidCallback? afterPop}) {
    if (!mounted) return;
    setState(() {
      _baseline = _snapshot();
      _isDirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
        afterPop?.call();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final repository = ref.read(taskRepositoryProvider);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final reminderAtMs = _reminderAt?.toUtc().millisecondsSinceEpoch;

    if (_isNew && _recurrence.enabled && _dueAtMs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.recurrenceRequiresDueDate,
          ),
        ),
      );
      return;
    }

    final String taskId;
    if (_isNew) {
      if (_recurrence.enabled) {
        final dueAt = _dueAtMs!;
        if (reminderAtMs != null && reminderAtMs > dueAt) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.recurrenceReminderBeforeDue,
              ),
            ),
          );
          return;
        }
        final timezoneId = await localIanaTimezone();
        final firstDueLocal = asLocalComponents(
          DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true).toLocal(),
        );
        if (!recurrenceRuleHasOccurrence(
          startLocal: firstDueLocal,
          timezoneId: timezoneId,
          rule: _recurrence.rule,
        )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.recurrenceEndBeforeStart,
                ),
              ),
            );
          }
          return;
        }
        final creation = await repository.createRepeating(
          template: TaskSeriesTemplate(
            workspaceId: workspaceId,
            title: title,
            description: description.isEmpty ? null : description,
            priority: _priority,
            firstDueLocal: firstDueLocal,
            timezoneId: timezoneId,
            contactId: _contactId,
            projectId: _projectId,
            reminderOffsetMinutes: reminderAtMs == null
                ? null
                : (dueAt - reminderAtMs) ~/ Duration.millisecondsPerMinute,
          ),
          rule: _recurrence.rule,
          anchor: _recurrence.taskAnchor,
        );
        taskId = creation.firstTaskId;
      } else {
        taskId = await repository.create(
          workspaceId: workspaceId,
          title: title,
          description: description.isEmpty ? null : description,
          priority: _priority,
          dueAt: _dueAtMs,
          reminderAt: reminderAtMs,
          contactId: _contactId,
          projectId: _projectId,
        );
      }
      if (widget.sourceNoteId case final sourceNoteId?) {
        await ref
            .read(noteRepositoryProvider)
            .addLink(sourceNoteId, ParentType.task, taskId);
      }
    } else {
      taskId = widget.taskId!;
      await repository.update(
        taskId,
        workspaceId: workspaceId,
        title: title,
        priority: _priority,
        description: Value(description.isEmpty ? null : description),
        dueAt: Value(_dueAtMs),
        reminderAt: Value(reminderAtMs),
        contactId: Value(_contactId),
        projectId: Value(_projectId),
      );
    }
    final persistedTask = await repository.getById(taskId);
    await ref
        .read(reminderCoordinatorProvider)
        .syncTaskReminder(
          taskId: taskId,
          title: persistedTask?.title ?? title,
          reminderAtMs: persistedTask?.reminderAt ?? reminderAtMs,
        );
    _clearDirtyAndPop();
  }

  Future<void> _delete(Task task) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(taskRepositoryProvider);
    final reminders = ref.read(reminderCoordinatorProvider);
    await repository.delete(task.id);
    await reminders.cancelTaskReminder(task.id);
    _clearDirtyAndPop(
      afterPop: () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.taskDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await repository.restore(task.id);
              await reminders.syncTaskReminder(
                taskId: task.id,
                title: task.title,
                reminderAtMs: task.reminderAt,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderAt ?? _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderAt != null
          ? TimeOfDay.fromDateTime(_reminderAt!)
          : const TimeOfDay(hour: 9, minute: 0),
      builder: appTimePickerBuilder(context, ref),
    );
    if (time == null) return;
    _change(
      () => _reminderAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _change(() => _dueDate = picked);
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: appTimePickerBuilder(context, ref),
    );
    if (picked != null) _change(() => _dueTime = picked);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _nextMonday(DateTime now) {
    final today = _dateOnly(now);
    final daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
    return today.add(
      Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday),
    );
  }

  void _setDueDateShortcut(DateTime date) =>
      _change(() => _dueDate = _dateOnly(date));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    Task? task;
    TaskSeriesRecord? series;
    if (!_isNew) {
      final value = ref.watch(taskByIdProvider(widget.taskId!));
      task = value.value;
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (task != null) _initFrom(task);
      if (task?.taskSeriesId case final seriesId?) {
        final seriesValue = ref.watch(taskSeriesProvider(seriesId));
        if (seriesValue.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        series = seriesValue.value;
        if (series != null) _initSeries(series);
      }
    }
    _workspaceId ??=
        ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);
    final projects = (ref.watch(allProjectsProvider).value ?? <Project>[])
        .where((project) => project.workspaceId == _workspaceId)
        .toList(growable: false);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? l10n.newTask : l10n.editTask)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }
    _captureBaseline();

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newTask : l10n.editTask),
          actions: [
            if (task != null)
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: l10n.newBillable,
                onPressed: () => context.push(
                  Uri(
                    path: '/finance/new',
                    queryParameters: {
                      'taskId': task!.id,
                      'workspaceId': task.workspaceId,
                      'title': task.title,
                      if (task.contactId != null) 'contactId': task.contactId!,
                      if (task.projectId != null) 'projectId': task.projectId!,
                    },
                  ).toString(),
                ),
              ),
            if (task != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.delete,
                onPressed: () => _delete(task!),
              ),
          ],
        ),
        bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
        body: Form(
          key: _formKey,
          onChanged: _syncDirty,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              FormGroupCard(
                title: l10n.tabTasks,
                children: [
                  FormFieldRow(
                    icon: Icons.title_rounded,
                    label: l10n.taskTitle,
                    child: TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.taskTitle,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.titleRequired
                          : null,
                    ),
                  ),
                ],
              ),
              FormGroupCard(
                title: l10n.formGroupLinks,
                children: [
                  FormFieldRow(
                    icon: Icons.workspaces_outline,
                    label: l10n.workspaceLabel,
                    child: DropdownButtonFormField<String>(
                      initialValue: _workspaceId,
                      isDense: true,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context),
                      items: [
                        for (final w in workspaces)
                          DropdownMenuItem(
                            value: w.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                WorkspaceDot(color: Color(w.color), size: 12),
                                const SizedBox(width: 8),
                                Text(w.name),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (id) => _change(() {
                        if (_workspaceId != id) _projectId = null;
                        _workspaceId = id;
                      }),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.contactLabel,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _contactId,
                      isDense: true,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.noContact),
                        ),
                        for (final contact
                            in ref.watch(allContactsProvider).value ??
                                <Contact>[])
                          DropdownMenuItem(
                            value: contact.id,
                            child: Text(contact.name),
                          ),
                      ],
                      onChanged: (id) => _change(() => _contactId = id),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.layers_outlined,
                    label: l10n.projectLabel,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('task-project-$_workspaceId-$_projectId'),
                      initialValue:
                          projects.any((project) => project.id == _projectId)
                          ? _projectId
                          : null,
                      isDense: true,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.noProject),
                        ),
                        for (final project in projects)
                          DropdownMenuItem(
                            value: project.id,
                            child: Text(project.name),
                          ),
                      ],
                      onChanged: (id) => _change(() => _projectId = id),
                    ),
                  ),
                ],
              ),
              FormGroupCard(
                title: l10n.formGroupWhen,
                children: [
                  FormFieldRow(
                    icon: Icons.event_rounded,
                    label: l10n.dueDateLabel,
                    onTap: _pickDueDate,
                    trailing: _dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            tooltip: l10n.clearDueDate,
                            onPressed: () => _change(() {
                              _dueDate = null;
                              _dueTime = null;
                            }),
                          )
                        : Icon(
                            Icons.edit_calendar_outlined,
                            size: 20,
                            color: context.tokens.ink3,
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dueDate == null
                              ? l10n.dueDateLabel
                              : DateFormat.yMMMEd().format(_dueDate!),
                          style: _dueDate == null
                              ? inlineFieldStyle(
                                  context,
                                ).copyWith(color: context.tokens.ink3)
                              : inlineFieldStyle(context),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              label: Text(l10n.todayButton),
                              onPressed: () =>
                                  _setDueDateShortcut(DateTime.now()),
                            ),
                            ActionChip(
                              label: Text(l10n.tomorrowButton),
                              onPressed: () => _setDueDateShortcut(
                                DateTime.now().add(const Duration(days: 1)),
                              ),
                            ),
                            ActionChip(
                              label: Text(l10n.nextMondayButton),
                              onPressed: () => _setDueDateShortcut(
                                _nextMonday(DateTime.now()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.schedule_rounded,
                    label: l10n.dueTimeLabel,
                    onTap: _dueDate == null ? null : _pickDueTime,
                    child: Text(
                      _dueTime == null
                          ? l10n.dueTimeLabel
                          : formatTimeOfDay(context, ref, _dueTime!),
                      style: _dueTime == null
                          ? inlineFieldStyle(
                              context,
                            ).copyWith(color: context.tokens.ink3)
                          : inlineFieldStyle(context),
                    ),
                  ),
                ],
              ),
              if (_isNew || series != null)
                RecurrenceEditor(
                  key: ValueKey(series?.id ?? 'new-task-recurrence'),
                  initialValue: _recurrence,
                  showTaskAnchor: true,
                  readOnly: series != null,
                  timezoneId: series?.timezoneId,
                  onChanged: (value) => _change(() => _recurrence = value),
                ),
              if (task != null)
                NoteBacklinksSection(
                  targetType: ParentType.task,
                  targetId: task.id,
                  workspaceId: task.workspaceId,
                ),
              MoreOptionsSection(
                initiallyExpanded:
                    _descriptionController.text.trim().isNotEmpty ||
                    _priority != TaskPriority.normal ||
                    _reminderAt != null,
                children: [
                  FormFieldRow(
                    icon: Icons.notes_rounded,
                    label: l10n.descriptionLabel,
                    child: TextFormField(
                      controller: _descriptionController,
                      textInputAction: TextInputAction.newline,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.descriptionLabel,
                      ),
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.flag_outlined,
                    label: l10n.priorityLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SegmentedButton<TaskPriority>(
                        segments: [
                          ButtonSegment(
                            value: TaskPriority.low,
                            label: Text(l10n.priorityLow),
                          ),
                          ButtonSegment(
                            value: TaskPriority.normal,
                            label: Text(l10n.priorityNormal),
                          ),
                          ButtonSegment(
                            value: TaskPriority.high,
                            label: Text(l10n.priorityHigh),
                          ),
                        ],
                        selected: {_priority},
                        onSelectionChanged: (selection) =>
                            _change(() => _priority = selection.first),
                      ),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.notifications_outlined,
                    label: l10n.reminderLabel,
                    onTap: _pickReminder,
                    trailing: _reminderAt != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            tooltip: l10n.clearReminder,
                            onPressed: () => _change(() => _reminderAt = null),
                          )
                        : null,
                    child: Text(
                      _reminderAt == null
                          ? l10n.remindNone
                          : '${DateFormat.yMMMEd().format(_reminderAt!)} '
                                '${appTimeFormat(context, ref).format(_reminderAt!)}',
                      style: _reminderAt == null
                          ? inlineFieldStyle(
                              context,
                            ).copyWith(color: context.tokens.ink3)
                          : inlineFieldStyle(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
