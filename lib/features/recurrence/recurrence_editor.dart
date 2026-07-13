import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/form_group.dart';
import '../../data/db/enums.dart';
import '../../data/recurrence/recurrence_rule.dart';
import '../../l10n/app_localizations.dart';

enum RecurrenceEndMode { never, onDate, afterCount }

@immutable
class RecurrenceEditorValue {
  const RecurrenceEditorValue({
    required this.enabled,
    required this.rule,
    this.taskAnchor = TaskRepeatAnchor.schedule,
  });

  RecurrenceEditorValue.disabled()
    : enabled = false,
      rule = RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      taskAnchor = TaskRepeatAnchor.schedule;

  final bool enabled;
  final RecurrenceRule rule;
  final TaskRepeatAnchor taskAnchor;

  RecurrenceEditorValue copyWith({
    bool? enabled,
    RecurrenceRule? rule,
    TaskRepeatAnchor? taskAnchor,
  }) => RecurrenceEditorValue(
    enabled: enabled ?? this.enabled,
    rule: rule ?? this.rule,
    taskAnchor: taskAnchor ?? this.taskAnchor,
  );
}

/// A shared recurrence form for events and tasks. It produces the same
/// [RecurrenceRule] contract used by both repositories and intentionally has
/// no persistence logic of its own.
class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.showTaskAnchor = false,
    this.readOnly = false,
    this.canToggle = true,
    this.timezoneId,
  });

  final RecurrenceEditorValue initialValue;
  final ValueChanged<RecurrenceEditorValue> onChanged;
  final bool showTaskAnchor;
  final bool readOnly;
  final bool canToggle;
  final String? timezoneId;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  late RecurrenceEditorValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _set(RecurrenceEditorValue value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  RecurrenceEndMode get _endMode => _value.rule.untilDate != null
      ? RecurrenceEndMode.onDate
      : _value.rule.count != null
      ? RecurrenceEndMode.afterCount
      : RecurrenceEndMode.never;

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final current = _value.rule.untilDate ?? now.add(const Duration(days: 30));
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = current.isBefore(today)
        ? DateTime(current.year, current.month, current.day)
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: firstDate,
      lastDate: DateTime(2200),
    );
    if (picked == null) return;
    _set(
      _value.copyWith(
        rule: _value.rule.copyWith(untilDate: picked, clearCount: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rule = _value.rule;
    return FormGroupCard(
      title: l10n.repeatLabel,
      children: [
        FormFieldRow(
          icon: Icons.repeat_rounded,
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _value.enabled
                    ? recurrenceSummary(context, _value)
                    : l10n.doesNotRepeat,
              ),
              value: _value.enabled,
              onChanged: widget.readOnly || !widget.canToggle
                  ? null
                  : (enabled) => _set(_value.copyWith(enabled: enabled)),
            ),
          ),
        ),
        if (_value.enabled && widget.timezoneId != null)
          FormFieldRow(
            icon: Icons.public_rounded,
            child: Text(l10n.recurrenceTimezone(widget.timezoneId!)),
          ),
        if (_value.enabled) ...[
          FormFieldRow(
            icon: Icons.calendar_view_week_outlined,
            label: l10n.recurrenceFrequencyLabel,
            child: DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: rule.frequency,
              isDense: true,
              decoration: inlineFieldDecoration(context),
              items: [
                for (final frequency in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: frequency,
                    child: Text(_frequencyLabel(l10n, frequency)),
                  ),
              ],
              onChanged: widget.readOnly
                  ? null
                  : (frequency) {
                      if (frequency == null) return;
                      _set(
                        _value.copyWith(
                          rule: rule.copyWith(frequency: frequency),
                        ),
                      );
                    },
            ),
          ),
          FormFieldRow(
            icon: Icons.swap_vert_rounded,
            label: l10n.repeatEveryLabel,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    key: const ValueKey('recurrence-interval'),
                    initialValue: '${rule.interval}',
                    enabled: !widget.readOnly,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: inlineFieldDecoration(context),
                    validator: (text) {
                      if (!_value.enabled) return null;
                      final value = int.tryParse(text?.trim() ?? '');
                      return value == null || value < 1
                          ? l10n.invalidInterval
                          : null;
                    },
                    onChanged: (text) {
                      final interval = int.tryParse(text.trim());
                      if (interval != null && interval > 0) {
                        _set(
                          _value.copyWith(
                            rule: rule.copyWith(interval: interval),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_intervalUnit(l10n, rule.frequency))),
              ],
            ),
          ),
          if (rule.frequency == RecurrenceFrequency.weekly)
            FormFieldRow(
              icon: Icons.date_range_rounded,
              label: l10n.repeatOnLabel,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(_weekdayLabel(context, day)),
                      selected: rule.weekdays.contains(day),
                      onSelected: widget.readOnly
                          ? null
                          : (selected) {
                              final weekdays = {...rule.weekdays};
                              selected
                                  ? weekdays.add(day)
                                  : weekdays.remove(day);
                              _set(
                                _value.copyWith(
                                  rule: rule.copyWith(weekdays: weekdays),
                                ),
                              );
                            },
                    ),
                ],
              ),
            ),
          FormFieldRow(
            icon: Icons.flag_outlined,
            label: l10n.recurrenceEndsLabel,
            child: DropdownButtonFormField<RecurrenceEndMode>(
              initialValue: _endMode,
              isDense: true,
              decoration: inlineFieldDecoration(context),
              items: [
                DropdownMenuItem(
                  value: RecurrenceEndMode.never,
                  child: Text(l10n.recurrenceNeverEnds),
                ),
                DropdownMenuItem(
                  value: RecurrenceEndMode.onDate,
                  child: Text(l10n.recurrenceOnDate),
                ),
                DropdownMenuItem(
                  value: RecurrenceEndMode.afterCount,
                  child: Text(l10n.recurrenceAfterCount),
                ),
              ],
              onChanged: widget.readOnly
                  ? null
                  : (mode) {
                      if (mode == null) return;
                      final updated = switch (mode) {
                        RecurrenceEndMode.never => rule.copyWith(
                          clearUntilDate: true,
                          clearCount: true,
                        ),
                        RecurrenceEndMode.onDate => rule.copyWith(
                          untilDate:
                              rule.untilDate ??
                              DateTime.now().add(const Duration(days: 30)),
                          clearCount: true,
                        ),
                        RecurrenceEndMode.afterCount => rule.copyWith(
                          count: rule.count ?? 10,
                          clearUntilDate: true,
                        ),
                      };
                      _set(_value.copyWith(rule: updated));
                    },
            ),
          ),
          if (_endMode == RecurrenceEndMode.onDate)
            FormFieldRow(
              icon: Icons.event_available_outlined,
              label: l10n.inclusiveEndDateLabel,
              onTap: widget.readOnly ? null : _pickEndDate,
              trailing: widget.readOnly
                  ? null
                  : const Icon(Icons.edit_calendar_outlined),
              child: Text(
                DateFormat.yMMMEd().format(rule.untilDate!),
                style: inlineFieldStyle(context),
              ),
            ),
          if (_endMode == RecurrenceEndMode.afterCount)
            FormFieldRow(
              icon: Icons.tag_rounded,
              label: l10n.occurrenceCountLabel,
              child: TextFormField(
                key: const ValueKey('recurrence-count'),
                initialValue: '${rule.count ?? 10}',
                enabled: !widget.readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: inlineFieldDecoration(context),
                validator: (text) {
                  if (!_value.enabled) return null;
                  final value = int.tryParse(text?.trim() ?? '');
                  return value == null || value < 1
                      ? l10n.invalidOccurrenceCount
                      : null;
                },
                onChanged: (text) {
                  final count = int.tryParse(text.trim());
                  if (count != null && count > 0) {
                    _set(
                      _value.copyWith(
                        rule: rule.copyWith(count: count, clearUntilDate: true),
                      ),
                    );
                  }
                },
              ),
            ),
          if (widget.showTaskAnchor)
            FormFieldRow(
              icon: Icons.forward_rounded,
              label: l10n.repeatAnchorLabel,
              child: Material(
                type: MaterialType.transparency,
                child: RadioGroup<TaskRepeatAnchor>(
                  groupValue: _value.taskAnchor,
                  onChanged: (anchor) {
                    if (!widget.readOnly && anchor != null) {
                      _set(_value.copyWith(taskAnchor: anchor));
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<TaskRepeatAnchor>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.repeatFromSchedule),
                        value: TaskRepeatAnchor.schedule,
                        enabled: !widget.readOnly,
                      ),
                      RadioListTile<TaskRepeatAnchor>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.repeatFromCompletion),
                        value: TaskRepeatAnchor.completion,
                        enabled: !widget.readOnly,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

String recurrenceSummary(BuildContext context, RecurrenceEditorValue value) {
  final l10n = AppLocalizations.of(context)!;
  if (!value.enabled) return l10n.doesNotRepeat;
  final rule = value.rule;
  final frequency = _frequencyLabel(l10n, rule.frequency);
  final base = rule.interval == 1
      ? frequency
      : '${l10n.repeatEveryLabel.toLowerCase()} ${rule.interval} '
            '${_intervalUnit(l10n, rule.frequency)}';
  if (rule.untilDate != null) {
    return '$base · ${l10n.recurrenceOnDate.toLowerCase()} '
        '${DateFormat.yMMMd().format(rule.untilDate!)}';
  }
  if (rule.count != null) {
    return '$base · ${rule.count} ${l10n.occurrenceCountLabel.toLowerCase()}';
  }
  return base;
}

String _frequencyLabel(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.daily => l10n.recurrenceDaily,
      RecurrenceFrequency.weekly => l10n.recurrenceWeekly,
      RecurrenceFrequency.monthly => l10n.recurrenceMonthly,
      RecurrenceFrequency.yearly => l10n.recurrenceYearly,
    };

String _intervalUnit(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.daily => l10n.intervalUnitDays,
      RecurrenceFrequency.weekly => l10n.intervalUnitWeeks,
      RecurrenceFrequency.monthly => l10n.intervalUnitMonths,
      RecurrenceFrequency.yearly => l10n.intervalUnitYears,
    };

String _weekdayLabel(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  // 2024-01-01 was a Monday, matching DateTime's weekday numbering.
  return DateFormat.E(locale).format(DateTime.utc(2024, 1, weekday));
}

/// Validates inclusive end rules before a repository writes the series. Rules
/// without an end always contain a future occurrence; bounded rules are
/// expanded through the inclusive local end date to catch weekday exclusions.
bool recurrenceRuleHasOccurrence({
  required DateTime startLocal,
  required String timezoneId,
  required RecurrenceRule rule,
}) {
  final until = rule.untilDate;
  if (until == null) return true;
  final engine = RecurrenceEngine();
  final horizon = engine.toUtcMs(
    DateTime.utc(until.year, until.month, until.day, 23, 59, 59),
    timezoneId,
  );
  return engine
      .generate(
        startLocal: startLocal,
        timezoneId: timezoneId,
        rule: rule,
        horizonUtcMs: horizon,
      )
      .isNotEmpty;
}
