import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../projects/project_providers.dart';
import 'calendar_providers.dart';

/// Appointment id prefixes distinguishing our two appointment kinds.
const _eventPrefix = 'event:';
const _taskPrefix = 'task:';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _controller = CalendarController();

  /// Watched window; widened by onViewChanged as the user navigates.
  late MsRange _range = _rangeAround(DateTime.now());

  static MsRange _rangeAround(DateTime anchor) => (
        start: DateTime(anchor.year, anchor.month - 1, 1).millisecondsSinceEpoch,
        end: DateTime(anchor.year, anchor.month + 2, 1).millisecondsSinceEpoch,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onViewChanged(ViewChangedDetails details) {
    if (details.visibleDates.isEmpty) return;
    final first = details.visibleDates.first;
    final last = details.visibleDates.last;
    final range = (
      start: DateTime(first.year, first.month, first.day)
          .millisecondsSinceEpoch,
      end: DateTime(last.year, last.month, last.day + 1)
          .millisecondsSinceEpoch,
    );
    if (range == _range) return;
    // onViewChanged can fire during build; defer the provider switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _range = range);
    });
  }

  void _onTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final appointment = details.appointments?.firstOrNull as Appointment?;
      if (appointment != null) _openAppointment(appointment.id as String);
    } else if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null &&
        _controller.view != CalendarView.month) {
      context.go(
          '/calendar/new?start=${details.date!.millisecondsSinceEpoch}');
    }
  }

  void _openAppointment(String id) {
    if (id.startsWith(_eventPrefix)) {
      context.go('/calendar/${id.substring(_eventPrefix.length)}');
    } else if (id.startsWith(_taskPrefix)) {
      context.go('/tasks/${id.substring(_taskPrefix.length)}');
    }
  }

  /// Persists a drag/resize of an event appointment and warns (non-blocking,
  /// spec §6.2) when the new time overlaps other events.
  Future<void> _applyMove(Appointment appointment) async {
    final id = appointment.id as String;
    if (!id.startsWith(_eventPrefix)) return; // task deadlines don't move
    final eventId = id.substring(_eventPrefix.length);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final startMs = appointment.startTime.toUtc().millisecondsSinceEpoch;
    final endMs = appointment.endTime.toUtc().millisecondsSinceEpoch;
    final repository = ref.read(eventRepositoryProvider);
    await repository.update(eventId, startsAt: startMs, endsAt: endMs);
    final conflicts = await repository.findConflicts(
      startMs: startMs,
      endMs: endMs,
      excludeEventId: eventId,
      allDay: appointment.isAllDay,
    );
    if (conflicts.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.movedEventConflicts(conflicts.length))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final events = ref.watch(calendarEventsProvider(_range)).value ?? [];
    final tasks = ref.watch(agendaTasksProvider(_range)).value ?? [];
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final projects = ref.watch(allProjectsForLookupProvider).value ?? [];

    Color colorOf(Event event) {
      final project =
          projects.where((p) => p.id == event.projectId).firstOrNull;
      final workspace =
          workspaces.where((w) => w.id == event.workspaceId).firstOrNull;
      return Color(
          project?.color ?? workspace?.color ?? theme.colorScheme.primary.toARGB32());
    }

    final appointments = <Appointment>[
      for (final event in events)
        Appointment(
          id: '$_eventPrefix${event.id}',
          subject: event.title,
          notes: event.location,
          startTime: DateTime.fromMillisecondsSinceEpoch(event.startsAt,
                  isUtc: true)
              .toLocal(),
          endTime:
              DateTime.fromMillisecondsSinceEpoch(event.endsAt, isUtc: true)
                  .toLocal(),
          isAllDay: event.allDay,
          color: colorOf(event),
        ),
      for (final task in tasks)
        if (task.dueAt != null)
          Appointment(
            id: '$_taskPrefix${task.id}',
            subject: task.title,
            startTime:
                DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: true)
                    .toLocal(),
            endTime:
                DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: true)
                    .toLocal()
                    .add(const Duration(minutes: 30)),
            color: theme.colorScheme.tertiary,
          ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCalendar),
        actions: [
          IconButton(
            icon: const Icon(Icons.topic_outlined),
            tooltip: l10n.projectsTitle,
            onPressed: () => context.go('/calendar/projects'),
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
      body: SfCalendar(
        controller: _controller,
        view: CalendarView.week,
        allowedViews: const [
          CalendarView.day,
          CalendarView.week,
          CalendarView.month,
          CalendarView.schedule,
        ],
        firstDayOfWeek: 1,
        dataSource: _AppointmentSource(appointments),
        showDatePickerButton: true,
        showTodayButton: true,
        allowDragAndDrop: true,
        allowAppointmentResize: true,
        onViewChanged: _onViewChanged,
        onTap: _onTap,
        onDragEnd: (details) {
          final appointment = details.appointment as Appointment?;
          if (appointment != null) _applyMove(appointment);
        },
        onAppointmentResizeEnd: (details) {
          final appointment = details.appointment as Appointment?;
          if (appointment != null) _applyMove(appointment);
        },
        todayHighlightColor: theme.colorScheme.primary,
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
          showAgenda: true,
        ),
        timeSlotViewSettings: const TimeSlotViewSettings(
          startHour: 6,
          endHour: 24,
        ),
        scheduleViewSettings: const ScheduleViewSettings(
          hideEmptyScheduleWeek: true,
        ),
      ),
    );
  }
}

class _AppointmentSource extends CalendarDataSource {
  _AppointmentSource(List<Appointment> source) {
    appointments = source;
  }
}
