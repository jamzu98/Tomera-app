import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import 'task_providers.dart';

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({super.key, this.taskId, this.initialProjectId});

  /// Null when creating a new task.
  final String? taskId;

  /// Pre-selected project when created from a project detail screen.
  final String? initialProjectId;

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
    _projectId = widget.initialProjectId;
  }
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderAt;
  bool _initialized = false;

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
      final local =
          DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true).toLocal();
      _dueDate = DateTime(local.year, local.month, local.day);
      _dueTime = TimeOfDay.fromDateTime(local);
    }
    final reminderAt = task.reminderAt;
    if (reminderAt != null) {
      _reminderAt =
          DateTime.fromMillisecondsSinceEpoch(reminderAt, isUtc: true)
              .toLocal();
    }
  }

  int? get _dueAtMs {
    final date = _dueDate;
    if (date == null) return null;
    final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .toUtc()
        .millisecondsSinceEpoch;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final repository = ref.read(taskRepositoryProvider);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final reminderAtMs = _reminderAt?.toUtc().millisecondsSinceEpoch;

    final String taskId;
    if (_isNew) {
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
    await ref.read(reminderCoordinatorProvider).syncTaskReminder(
          taskId: taskId,
          title: title,
          reminderAtMs: reminderAtMs,
        );
    if (mounted) context.pop();
  }

  Future<void> _delete(Task task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTaskTitle),
        content: Text(l10n.deleteTaskBody(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(taskRepositoryProvider).delete(task.id);
    await ref.read(reminderCoordinatorProvider).cancelTaskReminder(task.id);
    if (mounted) context.pop();
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
    );
    if (time == null) return;
    setState(() => _reminderAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    Task? task;
    if (!_isNew) {
      final value = ref.watch(taskByIdProvider(widget.taskId!));
      task = value.value;
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (task != null) _initFrom(task);
    }
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? l10n.newTask : l10n.editTask)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newTask : l10n.editTask),
        actions: [
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
                    style: inlineFieldStyle(context),
                    decoration:
                        inlineFieldDecoration(context, hint: l10n.taskTitle),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.titleRequired
                            : null,
                  ),
                ),
                FormFieldRow(
                  icon: Icons.notes_rounded,
                  label: l10n.descriptionLabel,
                  child: TextFormField(
                    controller: _descriptionController,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context,
                        hint: l10n.descriptionLabel),
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
                          setState(() => _priority = selection.first),
                    ),
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
                    onChanged: (id) => setState(() => _workspaceId = id),
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
                          value: null, child: Text(l10n.noContact)),
                      for (final contact in
                          ref.watch(allContactsProvider).value ?? <Contact>[])
                        DropdownMenuItem(
                          value: contact.id,
                          child: Text(contact.name),
                        ),
                    ],
                    onChanged: (id) => setState(() => _contactId = id),
                  ),
                ),
                FormFieldRow(
                  icon: Icons.layers_outlined,
                  label: l10n.projectLabel,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    isDense: true,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l10n.noProject)),
                      for (final project in
                          ref.watch(allProjectsProvider).value ?? <Project>[])
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                    ],
                    onChanged: (id) => setState(() => _projectId = id),
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
                          onPressed: () => setState(() {
                            _dueDate = null;
                            _dueTime = null;
                          }),
                        )
                      : Icon(Icons.edit_calendar_outlined,
                          size: 20, color: context.tokens.ink3),
                  child: Text(
                    _dueDate == null
                        ? l10n.dueDateLabel
                        : DateFormat.yMMMEd().format(_dueDate!),
                    style: _dueDate == null
                        ? inlineFieldStyle(context)
                            .copyWith(color: context.tokens.ink3)
                        : inlineFieldStyle(context),
                  ),
                ),
                FormFieldRow(
                  icon: Icons.schedule_rounded,
                  label: l10n.dueTimeLabel,
                  onTap: _dueDate == null ? null : _pickDueTime,
                  child: Text(
                    _dueTime == null
                        ? l10n.dueTimeLabel
                        : _dueTime!.format(context),
                    style: _dueTime == null
                        ? inlineFieldStyle(context)
                            .copyWith(color: context.tokens.ink3)
                        : inlineFieldStyle(context),
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
                          onPressed: () =>
                              setState(() => _reminderAt = null),
                        )
                      : null,
                  child: Text(
                    _reminderAt == null
                        ? l10n.remindNone
                        : DateFormat.yMMMEd().add_Hm().format(_reminderAt!),
                    style: _reminderAt == null
                        ? inlineFieldStyle(context)
                            .copyWith(color: context.tokens.ink3)
                        : inlineFieldStyle(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
