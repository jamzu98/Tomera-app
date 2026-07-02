import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'task_providers.dart';

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({super.key, this.taskId});

  /// Null when creating a new task.
  final String? taskId;

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _workspaceId;
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
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
    _priority = task.priority;
    final dueAt = task.dueAt;
    if (dueAt != null) {
      final local =
          DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true).toLocal();
      _dueDate = DateTime(local.year, local.month, local.day);
      _dueTime = TimeOfDay.fromDateTime(local);
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

    if (_isNew) {
      await repository.create(
        workspaceId: workspaceId,
        title: title,
        description: description.isEmpty ? null : description,
        priority: _priority,
        dueAt: _dueAtMs,
      );
    } else {
      await repository.update(
        widget.taskId!,
        workspaceId: workspaceId,
        title: title,
        priority: _priority,
        description: Value(description.isEmpty ? null : description),
        dueAt: Value(_dueAtMs),
      );
    }
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
    if (mounted) context.pop();
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
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(task!),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.taskTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.titleRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionLabel,
                border: const OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _workspaceId,
              decoration: InputDecoration(
                labelText: l10n.workspaceLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final w in workspaces)
                  DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Color(w.color)),
                        const SizedBox(width: 8),
                        Text(w.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _workspaceId = id),
            ),
            const SizedBox(height: 16),
            Text(l10n.priorityLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_dueDate == null
                        ? l10n.dueDateLabel
                        : DateFormat.yMMMEd().format(_dueDate!)),
                    onPressed: _pickDueDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_dueTime == null
                        ? l10n.dueTimeLabel
                        : _dueTime!.format(context)),
                    onPressed: _dueDate == null ? null : _pickDueTime,
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.clearDueDate,
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _dueTime = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
