import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/more_options_section.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../settings/date_time_format.dart';
import '../settings/settings_providers.dart';
import 'instance_dates.dart';
import 'project_providers.dart';

/// Wizard that creates many calendar events for one project at once
/// (e.g. every lecture of a course): weekly pattern and/or manual date
/// picks, one default time or per-instance overrides, editable review list.
class AddInstancesScreen extends ConsumerStatefulWidget {
  const AddInstancesScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<AddInstancesScreen> createState() => _AddInstancesScreenState();
}

class _AddInstancesScreenState extends ConsumerState<AddInstancesScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _pickerController = DateRangePickerController();

  TimeOfDay _defaultStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _defaultEnd = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _weekdays = {};
  DateTime _from = DateTime.now();
  DateTime? _until;
  List<EventInstance> _instances = [];
  bool _titleInitialized = false;
  List<Object?>? _baseline;
  bool _isDirty = false;

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _pickerController.dispose();
    super.dispose();
  }

  void _generateFromPattern() {
    final dates = generateWeeklyDates(
      weekdays: _weekdays,
      from: _from,
      until: _until,
    );
    _change(() {
      _instances = mergeDates(
        _instances,
        dates,
        startMinutes: _minutes(_defaultStart),
        endMinutes: _minutes(_defaultEnd),
      );
    });
  }

  void _addPickedDates() {
    final picked = _pickerController.selectedDates ?? [];
    _change(() {
      _instances = mergeDates(
        _instances,
        picked,
        startMinutes: _minutes(_defaultStart),
        endMinutes: _minutes(_defaultEnd),
      );
    });
    _pickerController.selectedDates = [];
  }

  void _applyDefaultsToAll() => _change(() {
    _instances = [
      for (final instance in _instances)
        (
          date: instance.date,
          startMinutes: _minutes(_defaultStart),
          endMinutes: _minutes(_defaultEnd),
        ),
    ];
  });

  Future<void> _editInstance(int index) async {
    final instance = _instances[index];
    final date = await showDatePicker(
      context: context,
      initialDate: instance.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: instance.startMinutes ~/ 60,
        minute: instance.startMinutes % 60,
      ),
      builder: appTimePickerBuilder(context, ref),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: instance.endMinutes ~/ 60,
        minute: instance.endMinutes % 60,
      ),
      builder: appTimePickerBuilder(context, ref),
    );
    if (end == null) return;
    _change(() {
      final updated = [..._instances];
      updated[index] = (
        date: DateTime(date.year, date.month, date.day),
        startMinutes: _minutes(start),
        endMinutes: _minutes(end),
      );
      updated.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.startMinutes.compareTo(b.startMinutes);
      });
      _instances = updated;
    });
  }

  Future<void> _addSingleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    _change(() {
      _instances = mergeDates(
        _instances,
        [date],
        startMinutes: _minutes(_defaultStart),
        endMinutes: _minutes(_defaultEnd),
      );
    });
  }

  Future<void> _save(Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim().isEmpty
        ? project.name
        : _titleController.text.trim();
    final location = _locationController.text.trim();
    final valid = _instances
        .where((i) => i.endMinutes > i.startMinutes)
        .toList();
    if (valid.isEmpty) return;

    // Spec §6.2 conflict detection, aggregated over the whole batch and
    // non-blocking: the user may save anyway.
    final repository = ref.read(eventRepositoryProvider);
    final dateFormat = DateFormat.MMMEd();
    final conflictLines = <String>[];
    for (final instance in valid) {
      final range = instanceRange(instance);
      final conflicts = await repository.findConflicts(
        startMs: range.startsAt,
        endMs: range.endsAt,
      );
      if (conflicts.isNotEmpty) {
        conflictLines.add(
          '${dateFormat.format(instance.date)} — ${conflicts.map((e) => e.title).join(', ')}',
        );
      }
    }
    if (conflictLines.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.conflictTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.instanceConflicts(conflictLines.length)),
                const SizedBox(height: 8),
                for (final line in conflictLines.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
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
      if (proceed != true) return;
    }

    await repository.createMany(
      workspaceId: project.workspaceId,
      title: title,
      location: location.isEmpty ? null : location,
      projectId: project.id,
      ranges: [for (final instance in valid) instanceRange(instance)],
    );
    _clearDirtyAndPop();
  }

  List<Object?> _snapshot() {
    final weekdays = _weekdays.toList()..sort();
    return [
      _titleController.text,
      _locationController.text,
      _defaultStart.hour,
      _defaultStart.minute,
      _defaultEnd.hour,
      _defaultEnd.minute,
      _from,
      _until,
      weekdays.join(','),
      for (final instance in _instances)
        '${instance.date.toIso8601String()}\u0000'
            '${instance.startMinutes}\u0000${instance.endMinutes}',
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

  void _clearDirtyAndPop() {
    if (!mounted) return;
    setState(() {
      _baseline = _snapshot();
      _isDirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final projectValue = ref.watch(projectByIdProvider(widget.projectId));
    final project = projectValue.value;
    if (projectValue.isLoading || project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_titleInitialized) {
      _titleInitialized = true;
      _titleController.text = project.name;
    }
    _captureBaseline();

    final dateFormat = DateFormat.yMMMEd();
    final timeFormat = appTimeFormat(context, ref);
    String timeOf(int minutes) =>
        timeFormat.format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));
    // Weekday chip labels, Monday first, locale-aware.
    final weekdayNames = [
      for (var i = 0; i < 7; i++)
        DateFormat.E().format(
          DateTime(2024, 1, 1 + i),
        ), // 2024-01-01 is a Monday
    ];

    Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: context.tokens.ink3,
        ),
      ),
    );

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.addInstances)),
        bottomNavigationBar: SaveBar(
          label: l10n.createInstances(_instances.length),
          onPressed: _instances.isEmpty ? null : () => _save(project),
        ),
        body: Form(
          onChanged: _syncDirty,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.eventTitle),
              ),
              const SizedBox(height: 12),
              MoreOptionsSection(
                padding: EdgeInsets.zero,
                initiallyExpanded: _locationController.text.trim().isNotEmpty,
                children: [
                  FormFieldRow(
                    icon: Icons.location_on_outlined,
                    label: l10n.locationLabel,
                    child: TextFormField(
                      controller: _locationController,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.locationLabel,
                      ),
                    ),
                  ),
                ],
              ),
              sectionTitle(l10n.defaultTimeLabel),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(timeOf(_minutes(_defaultStart))),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _defaultStart,
                          builder: appTimePickerBuilder(context, ref),
                        );
                        if (picked != null) {
                          _change(() => _defaultStart = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(timeOf(_minutes(_defaultEnd))),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _defaultEnd,
                          builder: appTimePickerBuilder(context, ref),
                        );
                        if (picked != null) _change(() => _defaultEnd = picked);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    tooltip: l10n.applyToAll,
                    onPressed: _instances.isEmpty ? null : _applyDefaultsToAll,
                  ),
                ],
              ),
              sectionTitle(l10n.repeatWeeklyOnLabel),
              Wrap(
                spacing: 6,
                children: [
                  for (
                    var weekday = DateTime.monday;
                    weekday <= DateTime.sunday;
                    weekday++
                  )
                    FilterChip(
                      label: Text(weekdayNames[weekday - 1]),
                      selected: _weekdays.contains(weekday),
                      onSelected: (selected) => _change(() {
                        if (selected) {
                          _weekdays.add(weekday);
                        } else {
                          _weekdays.remove(weekday);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        '${l10n.fromLabel}: '
                        '${DateFormat.MMMd().format(_from)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _from,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) _change(() => _from = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _until == null
                            ? l10n.untilLabel
                            : '${l10n.untilLabel}: '
                                  '${DateFormat.MMMd().format(_until!)}',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _until ?? _from.add(const Duration(days: 60)),
                          firstDate: _from,
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) _change(() => _until = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(l10n.generateDates),
                onPressed: _weekdays.isEmpty || _until == null
                    ? null
                    : _generateFromPattern,
              ),
              sectionTitle(l10n.pickDatesLabel),
              SizedBox(
                height: 300,
                child: SfDateRangePicker(
                  controller: _pickerController,
                  selectionMode: DateRangePickerSelectionMode.multiple,
                  monthViewSettings: DateRangePickerMonthViewSettings(
                    firstDayOfWeek: ref
                        .watch(weekStartSettingProvider)
                        .calendarDay,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(l10n.addSelectedDates),
                onPressed: _addPickedDates,
              ),
              sectionTitle(l10n.instancesCount(_instances.length)),
              if (_instances.isEmpty)
                Text(l10n.noInstancesYet, style: theme.textTheme.bodySmall)
              else
                for (final (index, instance) in _instances.indexed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_rounded, size: 18),
                    title: Text(dateFormat.format(instance.date)),
                    subtitle: Text(
                      '${timeOf(instance.startMinutes)} – ${timeOf(instance.endMinutes)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _change(
                        () => _instances = [..._instances]..removeAt(index),
                      ),
                    ),
                    onTap: () => _editInstance(index),
                  ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addSingleDate),
                onPressed: _addSingleDate,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
