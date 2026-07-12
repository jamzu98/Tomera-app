import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import 'calendar_providers.dart';
import 'reminder_offsets.dart';

class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen(
      {super.key, this.eventId, this.initialStartMs, this.initialProjectId});

  /// Null when creating a new event.
  final String? eventId;

  /// Pre-filled start (epoch ms) when created from a calendar slot tap.
  final int? initialStartMs;

  /// Pre-selected project when created from a project detail screen.
  final String? initialProjectId;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _workspaceId;
  String? _projectId;
  bool _allDay = false;
  late DateTime _start;
  late DateTime _end;
  Set<String> _linkedContactIds = {};
  ReminderOffset _reminderOffset = ReminderOffset.none;
  bool _initialized = false;
  bool _contactsInitialized = false;
  bool _reminderInitialized = false;

  bool get _isNew => widget.eventId == null;

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
    final initialMs = widget.initialStartMs;
    _start = initialMs != null
        ? DateTime.fromMillisecondsSinceEpoch(initialMs)
        : _nextFullHour(DateTime.now());
    _end = _start.add(const Duration(hours: 1));
  }

  static DateTime _nextFullHour(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour + 1);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initFrom(Event event) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.location ?? '';
    _workspaceId = event.workspaceId;
    _projectId = event.projectId;
    _allDay = event.allDay;
    _start = DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true)
        .toLocal();
    _end = DateTime.fromMillisecondsSinceEpoch(event.endsAt, isUtc: true)
        .toLocal();
  }

  (int, int) get _rangeMs {
    if (_allDay) {
      final dayStart = DateTime(_start.year, _start.month, _start.day);
      final dayEnd = DateTime(_end.year, _end.month, _end.day + 1);
      return (
        dayStart.toUtc().millisecondsSinceEpoch,
        dayEnd.toUtc().millisecondsSinceEpoch,
      );
    }
    return (
      _start.toUtc().millisecondsSinceEpoch,
      _end.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final (startMs, endMs) = _rangeMs;
    if (endMs <= startMs) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.endBeforeStart)));
      return;
    }

    final repository = ref.read(eventRepositoryProvider);
    // Spec §6.2: warn about overlaps across ALL workspaces, but let the user
    // save anyway.
    final conflicts = await repository.findConflicts(
      startMs: startMs,
      endMs: endMs,
      excludeEventId: widget.eventId,
      allDay: _allDay,
    );
    if (conflicts.isNotEmpty && mounted) {
      final proceed = await _showConflictDialog(conflicts);
      if (proceed != true) return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final String eventId;
    if (_isNew) {
      eventId = await repository.create(
        workspaceId: workspaceId,
        title: title,
        description: description.isEmpty ? null : description,
        location: location.isEmpty ? null : location,
        startsAt: startMs,
        endsAt: endMs,
        allDay: _allDay,
        projectId: _projectId,
      );
    } else {
      eventId = widget.eventId!;
      await repository.update(
        eventId,
        workspaceId: workspaceId,
        title: title,
        startsAt: startMs,
        endsAt: endMs,
        allDay: _allDay,
        description: Value(description.isEmpty ? null : description),
        location: Value(location.isEmpty ? null : location),
        projectId: Value(_projectId),
      );
    }
    await repository.setContacts(eventId, _linkedContactIds);
    await ref.read(reminderCoordinatorProvider).syncEventReminder(
          eventId: eventId,
          title: title,
          fireAtMs: reminderFireAtMs(_reminderOffset, startMs),
        );
    if (mounted) context.pop();
  }

  Future<bool?> _showConflictDialog(List<Event> conflicts) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.read(allWorkspacesProvider).value ?? [];
    final format = DateFormat.MMMEd().add_Hm();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.conflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.conflictBody),
            const SizedBox(height: 8),
            for (final event in conflicts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    WorkspaceDot(
                      size: 12,
                      color: Color(workspaces
                              .where((w) => w.id == event.workspaceId)
                              .firstOrNull
                              ?.color ??
                          0xFFB7AD9C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${event.title}\n'
                        '${format.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.goBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.saveAnyway),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Event event) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEventTitle),
        content: Text(l10n.deleteEventBody(event.title)),
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
    await ref.read(eventRepositoryProvider).delete(event.id);
    await ref.read(reminderCoordinatorProvider).cancelEventReminder(event.id);
    if (mounted) context.pop();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    var time = TimeOfDay.fromDateTime(current);
    if (!_allDay) {
      final picked = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (picked == null) return;
      time = picked;
    }
    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        // Keep the duration when moving the start.
        final duration = _end.difference(_start);
        _start = result;
        _end = result.add(duration);
      } else {
        _end = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    Event? event;
    if (!_isNew) {
      final value = ref.watch(eventByIdProvider(widget.eventId!));
      final contactIds = ref.watch(eventContactIdsProvider(widget.eventId!));
      final reminder = ref.watch(eventReminderProvider(widget.eventId!));
      event = value.value;
      if (value.isLoading || contactIds.isLoading || reminder.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (event != null) _initFrom(event);
      if (!_contactsInitialized) {
        _contactsInitialized = true;
        _linkedContactIds = {...contactIds.value ?? const <String>{}};
      }
      if (!_reminderInitialized && event != null) {
        _reminderInitialized = true;
        _reminderOffset =
            offsetFromFireAt(reminder.value?.fireAt, event.startsAt);
      }
    }
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? l10n.newEvent : l10n.editEvent)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }

    final dateFormat = DateFormat.yMMMEd();
    final timeFormat = DateFormat.Hm();
    String formatMoment(DateTime moment) => _allDay
        ? dateFormat.format(moment)
        : '${dateFormat.format(moment)} ${timeFormat.format(moment)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newEvent : l10n.editEvent),
        actions: [
          if (event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.delete,
              onPressed: () => _delete(event!),
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
              title: l10n.formGroupEvent,
              children: [
                FormFieldRow(
                  icon: Icons.title_rounded,
                  label: l10n.eventTitle,
                  child: TextFormField(
                    controller: _titleController,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context,
                        hint: l10n.eventTitle),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.titleRequired
                            : null,
                  ),
                ),
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
                  icon: Icons.schedule_rounded,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.allDayLabel,
                            style: inlineFieldStyle(context)),
                      ),
                      Switch(
                        value: _allDay,
                        onChanged: (value) =>
                            setState(() => _allDay = value),
                      ),
                    ],
                  ),
                ),
                FormFieldRow(
                  icon: Icons.play_circle_outline_rounded,
                  label: l10n.startsLabel,
                  trailing: Icon(Icons.edit_calendar_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: () => _pickDateTime(isStart: true),
                  child: Text(formatMoment(_start),
                      style: inlineFieldStyle(context)),
                ),
                FormFieldRow(
                  icon: Icons.stop_circle_outlined,
                  label: l10n.endsLabel,
                  trailing: Icon(Icons.edit_calendar_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onTap: () => _pickDateTime(isStart: false),
                  child: Text(formatMoment(_end),
                      style: inlineFieldStyle(context)),
                ),
              ],
            ),
            FormGroupCard(
              title: l10n.formGroupDetails,
              children: [
                FormFieldRow(
                  icon: Icons.notifications_outlined,
                  label: l10n.reminderLabel,
                  child: DropdownButtonFormField<ReminderOffset>(
                    initialValue: _reminderOffset,
                    isDense: true,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context),
                    items: [
                      DropdownMenuItem(
                        value: ReminderOffset.none,
                        child: Text(l10n.remindNone),
                      ),
                      DropdownMenuItem(
                        value: ReminderOffset.atStart,
                        child: Text(l10n.remindAtStart),
                      ),
                      DropdownMenuItem(
                        value: ReminderOffset.min15,
                        child: Text(l10n.remind15m),
                      ),
                      DropdownMenuItem(
                        value: ReminderOffset.hour1,
                        child: Text(l10n.remind1h),
                      ),
                      DropdownMenuItem(
                        value: ReminderOffset.day1,
                        child: Text(l10n.remind1d),
                      ),
                    ],
                    onChanged: (offset) => setState(
                        () => _reminderOffset = offset ?? ReminderOffset.none),
                  ),
                ),
                if (ref.watch(allContactsProvider).value case final contacts?
                    when contacts.isNotEmpty)
                  FormFieldRow(
                    icon: Icons.group_outlined,
                    label: l10n.linkedContacts,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          for (final contact in contacts)
                            FilterChip(
                              label: Text(contact.name),
                              selected:
                                  _linkedContactIds.contains(contact.id),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _linkedContactIds.add(contact.id);
                                } else {
                                  _linkedContactIds.remove(contact.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                FormFieldRow(
                  icon: Icons.location_on_outlined,
                  label: l10n.locationLabel,
                  child: TextFormField(
                    controller: _locationController,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context,
                        hint: l10n.locationLabel),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
