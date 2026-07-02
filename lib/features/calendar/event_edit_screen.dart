import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import 'calendar_providers.dart';

class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({super.key, this.eventId, this.initialStartMs});

  /// Null when creating a new event.
  final String? eventId;

  /// Pre-filled start (epoch ms) when created from a week-view slot tap.
  final int? initialStartMs;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _workspaceId;
  bool _allDay = false;
  late DateTime _start;
  late DateTime _end;
  Set<String> _linkedContactIds = {};
  bool _initialized = false;
  bool _contactsInitialized = false;

  bool get _isNew => widget.eventId == null;

  @override
  void initState() {
    super.initState();
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
      );
    }
    await repository.setContacts(eventId, _linkedContactIds);
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
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: Color(workspaces
                              .where((w) => w.id == event.workspaceId)
                              .firstOrNull
                              ?.color ??
                          0xFF888888),
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
      event = value.value;
      if (value.isLoading || contactIds.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (event != null) _initFrom(event);
      if (!_contactsInitialized) {
        _contactsInitialized = true;
        _linkedContactIds = {...contactIds.value ?? const <String>{}};
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
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(event!),
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
                labelText: l10n.eventTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.titleRequired
                  : null,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.allDayLabel),
              value: _allDay,
              onChanged: (value) => setState(() => _allDay = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l10n.startsLabel),
              trailing: Text(formatMoment(_start)),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l10n.endsLabel),
              trailing: Text(formatMoment(_end)),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 8),
            if (ref.watch(allContactsProvider).value case final contacts?
                when contacts.isNotEmpty) ...[
              Text(l10n.linkedContacts,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final contact in contacts)
                    FilterChip(
                      label: Text(contact.name),
                      selected: _linkedContactIds.contains(contact.id),
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
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.locationLabel,
                border: const OutlineInputBorder(),
              ),
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
