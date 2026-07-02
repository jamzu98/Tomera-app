import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'agenda_view.dart';
import 'calendar_providers.dart';
import 'week_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// Local midnight of the first day of the displayed week (Monday).
  late DateTime _weekStart = _mondayOf(DateTime.now());
  bool _agenda = false;

  static DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  List<DateTime> get _days => [
        for (var i = 0; i < 7; i++)
          DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i),
      ];

  MsRange get _range => (
        start: _weekStart.millisecondsSinceEpoch,
        end: DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7)
            .millisecondsSinceEpoch,
      );

  void _shiftWeek(int weeks) => setState(() => _weekStart = DateTime(
      _weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final events = ref.watch(calendarEventsProvider(_range)).value ?? [];
    final tasks = ref.watch(agendaTasksProvider(_range)).value ?? [];
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.calendar);

    Color colorOf(String workspaceId) {
      final workspace =
          workspaces.where((w) => w.id == workspaceId).firstOrNull;
      return workspace != null
          ? Color(workspace.color)
          : theme.colorScheme.primary;
    }

    final days = _days;
    final rangeLabel =
        '${DateFormat.MMMd().format(days.first)} – ${DateFormat.MMMd().format(days.last)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCalendar),
        actions: [
          IconButton(
            icon: Icon(_agenda ? Icons.calendar_view_week : Icons.view_agenda),
            tooltip: _agenda ? l10n.weekView : l10n.agendaView,
            onPressed: () => setState(() => _agenda = !_agenda),
          ),
          const WorkspaceFilterButton(),
          const WorkspacesButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newEvent,
        onPressed: () => context.go('/calendar/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l10n.previousWeek,
                  onPressed: () => _shiftWeek(-1),
                ),
                Expanded(
                  child: Text(
                    rangeLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l10n.nextWeek,
                  onPressed: () => _shiftWeek(1),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _weekStart = _mondayOf(DateTime.now())),
                  child: Text(l10n.todayButton),
                ),
              ],
            ),
          ),
          if (moduleDisabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.calendarModuleDisabled,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: _agenda
                ? AgendaView(
                    days: days,
                    events: events,
                    tasks: tasks,
                    colorOf: colorOf,
                    onEventTap: (event) => context.go('/calendar/${event.id}'),
                    onTaskTap: (task) => context.go('/tasks/${task.id}'),
                  )
                : WeekView(
                    days: days,
                    events: events,
                    colorOf: colorOf,
                    onEventTap: (event) => context.go('/calendar/${event.id}'),
                    onSlotTap: (slotStart) => context.go(
                        '/calendar/new?start=${slotStart.millisecondsSinceEpoch}'),
                  ),
          ),
        ],
      ),
    );
  }
}
