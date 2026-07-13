import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/more_options_section.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../data/recurrence/recurrence_models.dart';
import '../../data/recurrence/recurrence_rule.dart';
import '../../data/repositories/event_repository.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../notes/note_backlinks_section.dart';
import '../projects/project_providers.dart';
import '../recurrence/local_timezone.dart';
import '../recurrence/recurrence_editor.dart';
import '../settings/date_time_format.dart';
import '../settings/settings_providers.dart';
import 'calendar_providers.dart';
import 'reminder_offsets.dart';

Duration recurrenceTemplateDuration({
  required bool allDay,
  required DateTime localStart,
  required DateTime localEnd,
  required int startMs,
  required int endMs,
}) {
  if (!allDay) return Duration(milliseconds: endMs - startMs);
  final start = DateTime.utc(localStart.year, localStart.month, localStart.day);
  final end = DateTime.utc(localEnd.year, localEnd.month, localEnd.day + 1);
  return end.difference(start);
}

class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({
    super.key,
    this.eventId,
    this.initialStartMs,
    this.initialWorkspaceId,
    this.initialContactId,
    this.initialProjectId,
  });

  /// Null when creating a new event.
  final String? eventId;

  /// Pre-filled start (epoch ms) when created from a calendar slot tap.
  final int? initialStartMs;

  final String? initialWorkspaceId;
  final String? initialContactId;

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
  bool _seriesInitialized = false;
  String? _seriesTimezoneId;
  bool _seriesAllowsCurrentAndFuture = false;
  late RecurrenceEditorValue _recurrence = RecurrenceEditorValue.disabled();
  List<Object?>? _baseline;
  bool _isDirty = false;

  bool get _isNew => widget.eventId == null;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.initialWorkspaceId;
    if (widget.initialContactId != null) {
      _linkedContactIds = {widget.initialContactId!};
    }
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
    _start = DateTime.fromMillisecondsSinceEpoch(
      event.startsAt,
      isUtc: true,
    ).toLocal();
    _end = DateTime.fromMillisecondsSinceEpoch(
      event.allDay ? event.endsAt - 1 : event.endsAt,
      isUtc: true,
    ).toLocal();
  }

  void _initSeries(EventSeriesRecord series, Event event) {
    if (_seriesInitialized) return;
    _seriesInitialized = true;
    _seriesTimezoneId = series.timezoneId;
    _seriesAllowsCurrentAndFuture = series.endsBeforeLocal == null;
    final engine = RecurrenceEngine();
    _start = engine.toLocalComponents(event.startsAt, series.timezoneId);
    _end = engine.toLocalComponents(
      event.allDay ? event.endsAt - 1 : event.endsAt,
      series.timezoneId,
    );
    _recurrence = RecurrenceEditorValue(
      enabled: true,
      rule: RecurrenceRule.decode(series.ruleJson),
    );
  }

  (int, int) get _rangeMs {
    final timezoneId = _seriesTimezoneId;
    if (timezoneId != null) {
      final engine = RecurrenceEngine();
      final start = asLocalComponents(_start);
      if (_allDay) {
        final end = DateTime.utc(_end.year, _end.month, _end.day + 1);
        return (
          engine.toUtcMs(start, timezoneId),
          engine.toUtcMs(end, timezoneId),
        );
      }
      final startMs = engine.toUtcMs(start, timezoneId);
      return (startMs, startMs + _end.difference(_start).inMilliseconds);
    }
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

  Duration get _recurrenceDuration {
    final (startMs, endMs) = _rangeMs;
    return recurrenceTemplateDuration(
      allDay: _allDay,
      localStart: _start,
      localEnd: _end,
      startMs: startMs,
      endMs: endMs,
    );
  }

  Future<RecurrenceEditScope?> _chooseRecurrenceScope({
    required bool deleting,
    required bool allowCurrentAndFuture,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<RecurrenceEditScope>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          deleting ? l10n.deleteRecurringTitle : l10n.editRecurringTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.looks_one_outlined),
              title: Text(
                deleting ? l10n.deleteThisOccurrence : l10n.editThisOccurrence,
              ),
              onTap: () =>
                  Navigator.pop(dialogContext, RecurrenceEditScope.occurrence),
            ),
            if (allowCurrentAndFuture)
              ListTile(
                leading: const Icon(Icons.fast_forward_rounded),
                title: Text(
                  deleting
                      ? l10n.deleteCurrentAndFuture
                      : l10n.editCurrentAndFuture,
                ),
                onTap: () => Navigator.pop(
                  dialogContext,
                  RecurrenceEditScope.currentAndFuture,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  List<Object?> _snapshot() {
    final contactIds = _linkedContactIds.toList()..sort();
    return [
      _titleController.text,
      _descriptionController.text,
      _locationController.text,
      _workspaceId,
      _projectId,
      _allDay,
      _start,
      _end,
      contactIds.join('\u0000'),
      _reminderOffset,
      _recurrence.enabled,
      _recurrence.rule.encode(),
    ];
  }

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
    final l10n = AppLocalizations.of(context)!;
    final (startMs, endMs) = _rangeMs;
    if (endMs <= startMs) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endBeforeStart)));
      return;
    }

    final repository = ref.read(eventRepositoryProvider);
    // Spec §6.2: warn about overlaps across ALL workspaces, but let the user
    // save anyway.
    if (!_recurrence.enabled) {
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
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final String eventId;
    var recurringCreation = false;
    if (_isNew) {
      if (_recurrence.enabled) {
        final timezoneId = await localIanaTimezone();
        final localStart = asLocalComponents(_start);
        if (!recurrenceRuleHasOccurrence(
          startLocal: localStart,
          timezoneId: timezoneId,
          rule: _recurrence.rule,
        )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.recurrenceEndBeforeStart)),
            );
          }
          return;
        }
        final conflicts = await _findRecurringConflicts(
          repository: repository,
          localStart: localStart,
          timezoneId: timezoneId,
          rule: _recurrence.rule,
          duration: _recurrenceDuration,
        );
        if (conflicts.isNotEmpty && mounted) {
          final proceed = await _showConflictDialog(conflicts);
          if (proceed != true) return;
        }
        final creation = await repository.createRecurring(
          template: EventSeriesTemplate(
            workspaceId: workspaceId,
            title: title,
            description: description.isEmpty ? null : description,
            location: location.isEmpty ? null : location,
            localStartsAt: localStart,
            duration: _recurrenceDuration,
            timezoneId: timezoneId,
            allDay: _allDay,
            projectId: _projectId,
            contactIds: _linkedContactIds,
            reminderOffsetMinutes: reminderOffsetMinutes(_reminderOffset),
          ),
          rule: _recurrence.rule,
        );
        if (creation.occurrenceIds.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.recurrenceEndBeforeStart)),
            );
          }
          return;
        }
        eventId = creation.occurrenceIds.first;
        recurringCreation = true;
        await ref
            .read(reminderCoordinatorProvider)
            .syncMaterializedEventReminders(creation.occurrenceIds);
      } else {
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
      }
    } else {
      eventId = widget.eventId!;
      final event = await repository.getById(eventId);
      if (event?.seriesId != null) {
        final scope = await _chooseRecurrenceScope(
          deleting: false,
          allowCurrentAndFuture: _seriesAllowsCurrentAndFuture,
        );
        if (scope == null) return;
        if (scope == RecurrenceEditScope.occurrence) {
          final conflicts = await repository.findConflicts(
            startMs: startMs,
            endMs: endMs,
            excludeEventId: eventId,
            allDay: _allDay,
          );
          if (conflicts.isNotEmpty && mounted) {
            final proceed = await _showConflictDialog(conflicts);
            if (proceed != true) return;
          }
          await repository.updateRecurrence(
            eventId: eventId,
            scope: scope,
            workspaceId: workspaceId,
            title: title,
            startsAt: startMs,
            endsAt: endMs,
            allDay: _allDay,
            description: Value(description.isEmpty ? null : description),
            location: Value(location.isEmpty ? null : location),
            projectId: Value(_projectId),
          );
        } else {
          final timezoneId = _seriesTimezoneId ?? await localIanaTimezone();
          final localStart = asLocalComponents(_start);
          if (!recurrenceRuleHasOccurrence(
            startLocal: localStart,
            timezoneId: timezoneId,
            rule: _recurrence.rule,
          )) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.recurrenceEndBeforeStart)),
              );
            }
            return;
          }
          final conflicts = await _findRecurringConflicts(
            repository: repository,
            localStart: localStart,
            timezoneId: timezoneId,
            rule: _recurrence.rule,
            duration: _recurrenceDuration,
            ignoredSeriesId: event?.seriesId,
          );
          if (conflicts.isNotEmpty && mounted) {
            final proceed = await _showConflictDialog(conflicts);
            if (proceed != true) return;
          }
          await repository.updateRecurrence(
            eventId: eventId,
            scope: scope,
            currentAndFutureTemplate: EventSeriesTemplate(
              workspaceId: workspaceId,
              title: title,
              description: description.isEmpty ? null : description,
              location: location.isEmpty ? null : location,
              localStartsAt: localStart,
              duration: _recurrenceDuration,
              timezoneId: timezoneId,
              allDay: _allDay,
              projectId: _projectId,
              contactIds: _linkedContactIds,
              reminderOffsetMinutes: reminderOffsetMinutes(_reminderOffset),
            ),
            currentAndFutureRule: _recurrence.rule,
          );
          await ref.read(reminderCoordinatorProvider).reconcileFromDatabase();
          recurringCreation = true;
        }
      } else {
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
    }
    if (!recurringCreation) {
      await repository.setContacts(eventId, _linkedContactIds);
      await ref
          .read(reminderCoordinatorProvider)
          .syncEventReminder(
            eventId: eventId,
            title: title,
            fireAtMs: reminderFireAtMs(_reminderOffset, startMs),
          );
    }
    _clearDirtyAndPop();
  }

  Future<List<Event>> _findRecurringConflicts({
    required EventRepository repository,
    required DateTime localStart,
    required String timezoneId,
    required RecurrenceRule rule,
    required Duration duration,
    String? ignoredSeriesId,
  }) async {
    if (_allDay) return const [];
    final engine = RecurrenceEngine();
    final firstUtc = engine.toUtcMs(localStart, timezoneId);
    final rollingHorizon = DateTime.now()
        .toUtc()
        .add(const Duration(days: 550))
        .millisecondsSinceEpoch;
    final firstCandidateHorizon =
        firstUtc +
        Duration(
          days: rule.frequency == RecurrenceFrequency.weekly
              ? rule.interval * 7 + 7
              : 1,
        ).inMilliseconds;
    var horizon = firstCandidateHorizon > rollingHorizon
        ? firstCandidateHorizon
        : rollingHorizon;
    if (rule.untilDate case final until?) {
      final untilHorizon = engine.toUtcMs(
        DateTime.utc(until.year, until.month, until.day, 23, 59, 59),
        timezoneId,
      );
      if (untilHorizon < horizon) horizon = untilHorizon;
    }
    final occurrences = engine.generate(
      startLocal: localStart,
      timezoneId: timezoneId,
      rule: rule,
      horizonUtcMs: horizon,
    );
    final conflicts = <String, Event>{};
    for (final occurrence in occurrences) {
      final found = await repository.findConflicts(
        startMs: occurrence.startsAtMs,
        endMs: occurrence.startsAtMs + duration.inMilliseconds,
      );
      for (final event in found) {
        if (ignoredSeriesId == null || event.seriesId != ignoredSeriesId) {
          conflicts[event.id] = event;
        }
      }
    }
    return conflicts.values.toList(growable: false);
  }

  Future<bool?> _showConflictDialog(List<Event> conflicts) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.read(allWorkspacesProvider).value ?? [];
    final uses24Hour = ref
        .read(timeFormatSettingProvider)
        .resolveUses24Hour(
          systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
        );
    final dateFormat = DateFormat.MMMEd();
    final timeFormat = uses24Hour ? DateFormat.Hm() : DateFormat.jm();
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.conflictTitle),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.conflictBody),
                const SizedBox(height: 8),
                for (final event in conflicts.take(25))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        WorkspaceDot(
                          size: 12,
                          color: Color(
                            workspaces
                                    .where((w) => w.id == event.workspaceId)
                                    .firstOrNull
                                    ?.color ??
                                0xFFB7AD9C,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${event.title}\n'
                            '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())} '
                            '${timeFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (conflicts.length > 25)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.moreConflicts(conflicts.length - 25),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
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
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(eventRepositoryProvider);
    final reminders = ref.read(reminderCoordinatorProvider);
    if (event.seriesId != null) {
      final scope = await _chooseRecurrenceScope(
        deleting: true,
        allowCurrentAndFuture: _seriesAllowsCurrentAndFuture,
      );
      if (scope == null) return;
      final affectedIds = await repository.deleteRecurrence(event.id, scope);
      for (final id in affectedIds) {
        await reminders.cancelEventReminder(id);
      }
      if (scope == RecurrenceEditScope.occurrence) {
        final reminderAt = reminderFireAtMs(_reminderOffset, event.startsAt);
        _clearDirtyAndPop(
          afterPop: () => messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.eventDeleted),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () async {
                  await repository.restoreRecurrenceOccurrence(event.id);
                  await reminders.syncEventReminder(
                    eventId: event.id,
                    title: event.title,
                    fireAtMs: reminderAt,
                  );
                },
              ),
            ),
          ),
        );
      } else {
        _clearDirtyAndPop();
      }
      return;
    }
    final reminderAt = reminderFireAtMs(_reminderOffset, event.startsAt);
    await repository.delete(event.id);
    await reminders.cancelEventReminder(event.id);
    _clearDirtyAndPop(
      afterPop: () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.eventDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await repository.restore(event.id);
              await reminders.syncEventReminder(
                eventId: event.id,
                title: event.title,
                fireAtMs: reminderAt,
              );
            },
          ),
        ),
      ),
    );
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
        builder: appTimePickerBuilder(context, ref),
      );
      if (picked == null) return;
      time = picked;
    }
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    _change(() {
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
    EventSeriesRecord? series;
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
        _reminderOffset = offsetFromFireAt(
          reminder.value?.fireAt,
          event.startsAt,
        );
      }
      if (event?.seriesId case final seriesId?) {
        final seriesValue = ref.watch(eventSeriesProvider(seriesId));
        if (seriesValue.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        series = seriesValue.value;
        if (series != null) _initSeries(series, event!);
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
        appBar: AppBar(title: Text(_isNew ? l10n.newEvent : l10n.editEvent)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }
    _captureBaseline();

    final dateFormat = DateFormat.yMMMEd();
    final timeFormat = appTimeFormat(context, ref);
    String formatMoment(DateTime moment) => _allDay
        ? dateFormat.format(moment)
        : '${dateFormat.format(moment)} ${timeFormat.format(moment)}';

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newEvent : l10n.editEvent),
          actions: [
            if (event != null)
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: l10n.newBillable,
                onPressed: () => context.push(
                  Uri(
                    path: '/finance/new',
                    queryParameters: {
                      'eventId': event!.id,
                      'workspaceId': event.workspaceId,
                      'title': event.title,
                      if (_linkedContactIds.length == 1)
                        'contactId': _linkedContactIds.single,
                      if (event.projectId != null)
                        'projectId': event.projectId!,
                    },
                  ).toString(),
                ),
              ),
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
          onChanged: _syncDirty,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      textInputAction: TextInputAction.next,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.eventTitle,
                      ),
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
                      onChanged: (id) => _change(() {
                        if (_workspaceId != id) _projectId = null;
                        _workspaceId = id;
                      }),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.layers_outlined,
                    label: l10n.projectLabel,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('event-project-$_workspaceId-$_projectId'),
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
                    icon: Icons.schedule_rounded,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.allDayLabel,
                            style: inlineFieldStyle(context),
                          ),
                        ),
                        Switch(
                          value: _allDay,
                          onChanged: (value) => _change(() => _allDay = value),
                        ),
                      ],
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.play_circle_outline_rounded,
                    label: l10n.startsLabel,
                    trailing: Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _pickDateTime(isStart: true),
                    child: Text(
                      formatMoment(_start),
                      style: inlineFieldStyle(context),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.stop_circle_outlined,
                    label: l10n.endsLabel,
                    trailing: Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _pickDateTime(isStart: false),
                    child: Text(
                      formatMoment(_end),
                      style: inlineFieldStyle(context),
                    ),
                  ),
                ],
              ),
              if (_isNew || series != null)
                RecurrenceEditor(
                  key: ValueKey(series?.id ?? 'new-event-recurrence'),
                  initialValue: _recurrence,
                  canToggle: _isNew,
                  readOnly: series != null && !_seriesAllowsCurrentAndFuture,
                  timezoneId: _seriesTimezoneId,
                  onChanged: (value) => _change(() => _recurrence = value),
                ),
              if (ref.watch(allContactsProvider).value case final contacts?
                  when contacts.isNotEmpty)
                FormGroupCard(
                  title: l10n.formGroupLinks,
                  children: [
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
                                selected: _linkedContactIds.contains(
                                  contact.id,
                                ),
                                onSelected: (selected) => _change(() {
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
                  ],
                ),
              MoreOptionsSection(
                initiallyExpanded:
                    _reminderOffset != ReminderOffset.none ||
                    _locationController.text.trim().isNotEmpty ||
                    _descriptionController.text.trim().isNotEmpty,
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
                      onChanged: (offset) => _change(
                        () => _reminderOffset = offset ?? ReminderOffset.none,
                      ),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.location_on_outlined,
                    label: l10n.locationLabel,
                    child: TextFormField(
                      controller: _locationController,
                      textInputAction: TextInputAction.next,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.locationLabel,
                      ),
                    ),
                  ),
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
                ],
              ),
              if (event != null)
                NoteBacklinksSection(
                  targetType: ParentType.event,
                  targetId: event.id,
                  workspaceId: event.workspaceId,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
