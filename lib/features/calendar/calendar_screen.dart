import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/editorial.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../projects/project_providers.dart';
import '../settings/date_time_format.dart';
import '../settings/settings_providers.dart';
import '../workspaces/workspace_style.dart';
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
      start: DateTime(
        first.year,
        first.month,
        first.day,
      ).millisecondsSinceEpoch,
      end: DateTime(last.year, last.month, last.day + 1).millisecondsSinceEpoch,
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
      context.push(
        '/calendar/new?start=${details.date!.millisecondsSinceEpoch}',
      );
    }
  }

  void _openAppointment(String id) {
    if (id.startsWith(_eventPrefix)) {
      context.push('/calendar/${id.substring(_eventPrefix.length)}');
    } else if (id.startsWith(_taskPrefix)) {
      context.push('/work/tasks/${id.substring(_taskPrefix.length)}');
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
    final reminders = ref.read(reminderCoordinatorProvider);
    final before = await repository.getById(eventId);
    if (before == null) return;
    final reminder = await reminders.watchEventReminder(eventId).first;
    final reminderOffset = reminder == null
        ? null
        : reminder.fireAt - before.startsAt;
    await repository.update(eventId, startsAt: startMs, endsAt: endMs);
    if (reminderOffset != null) {
      await reminders.syncEventReminder(
        eventId: eventId,
        title: before.title,
        fireAtMs: startMs + reminderOffset,
      );
    }
    final conflicts = await repository.findConflicts(
      startMs: startMs,
      endMs: endMs,
      excludeEventId: eventId,
      allDay: appointment.isAllDay,
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          conflicts.isEmpty
              ? l10n.eventMoved
              : l10n.movedEventConflicts(conflicts.length),
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await repository.update(
              eventId,
              startsAt: before.startsAt,
              endsAt: before.endsAt,
            );
            if (reminder != null) {
              await reminders.syncEventReminder(
                eventId: eventId,
                title: before.title,
                fireAtMs: reminder.fireAt,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    final weekStart = ref.watch(weekStartSettingProvider);
    final uses24Hour = ref
        .watch(timeFormatSettingProvider)
        .resolveUses24Hour(
          systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
        );
    final events = ref.watch(calendarEventsProvider(_range)).value ?? [];
    final tasks = ref.watch(agendaTasksProvider(_range)).value ?? [];
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final projects = ref.watch(allProjectsForLookupProvider).value ?? [];

    Color colorOf(Event event) {
      final project = projects
          .where((p) => p.id == event.projectId)
          .firstOrNull;
      final workspace = workspaces
          .where((w) => w.id == event.workspaceId)
          .firstOrNull;
      return Color(
        project?.color ??
            workspace?.color ??
            theme.colorScheme.primary.toARGB32(),
      );
    }

    final appointments = <Appointment>[
      for (final event in events)
        Appointment(
          id: '$_eventPrefix${event.id}',
          subject: event.title,
          notes: event.location,
          startTime: DateTime.fromMillisecondsSinceEpoch(
            event.startsAt,
            isUtc: true,
          ).toLocal(),
          endTime: DateTime.fromMillisecondsSinceEpoch(
            event.endsAt,
            isUtc: true,
          ).toLocal(),
          isAllDay: event.allDay,
          color: colorOf(event),
        ),
      for (final task in tasks)
        if (task.dueAt != null)
          Appointment(
            id: '$_taskPrefix${task.id}',
            subject: task.title,
            startTime: DateTime.fromMillisecondsSinceEpoch(
              task.dueAt!,
              isUtc: true,
            ).toLocal(),
            endTime: DateTime.fromMillisecondsSinceEpoch(
              task.dueAt!,
              isUtc: true,
            ).toLocal().add(const Duration(minutes: 30)),
            color: theme.colorScheme.tertiary,
          ),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          const Center(child: WorkspaceSwitcherPill(compact: true)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: l10n.projectsTitle,
            onPressed: () => context.go('/work/projects'),
          ),
          const AppBarOverflowMenu(),
        ],
      ),
      body: Column(
        children: [
          EditorialScreenHeader(title: l10n.tabCalendar),
          Expanded(
            child: SfCalendarTheme(
              data: _calendarTheme(theme, tokens),
              child: SfCalendar(
                controller: _controller,
                // The time grid produces a very noisy semantics tree. Prefer the
                // linear schedule view when assistive navigation is active.
                view: accessibleNavigation
                    ? CalendarView.schedule
                    : CalendarView.week,
                allowedViews: const [
                  CalendarView.day,
                  CalendarView.week,
                  CalendarView.month,
                  CalendarView.schedule,
                ],
                firstDayOfWeek: weekStart.calendarDay,
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
                backgroundColor: Colors.transparent,
                cellBorderColor: tokens.borderSubtle,
                todayHighlightColor: theme.colorScheme.primary,
                selectionDecoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.6,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                headerStyle: CalendarHeaderStyle(
                  backgroundColor: Colors.transparent,
                  textStyle: TextStyle(
                    fontFamily: displayFontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                viewHeaderStyle: ViewHeaderStyle(
                  dayTextStyle: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.textTertiary,
                  ),
                  dateTextStyle: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                appointmentBuilder: _buildAppointment,
                monthViewSettings: MonthViewSettings(
                  appointmentDisplayMode:
                      MonthAppointmentDisplayMode.appointment,
                  showAgenda: true,
                  monthCellStyle: MonthCellStyle(
                    textStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    trailingDatesTextStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textTertiary,
                    ),
                    leadingDatesTextStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textTertiary,
                    ),
                  ),
                  agendaStyle: AgendaStyle(
                    dayTextStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.textTertiary,
                    ),
                    dateTextStyle: TextStyle(
                      fontFamily: displayFontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                timeSlotViewSettings: TimeSlotViewSettings(
                  startHour: 6,
                  endHour: 24,
                  timeFormat: uses24Hour ? 'HH:mm' : 'h a',
                  timeTextStyle: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.textTertiary,
                  ),
                ),
                scheduleViewSettings: ScheduleViewSettings(
                  hideEmptyScheduleWeek: true,
                  monthHeaderSettings: MonthHeaderSettings(
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    monthTextStyle: TextStyle(
                      fontFamily: displayFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  weekHeaderSettings: WeekHeaderSettings(
                    weekTextStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: tokens.textTertiary,
                    ),
                  ),
                  dayHeaderSettings: DayHeaderSettings(
                    dayTextStyle: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.textTertiary,
                    ),
                    dateTextStyle: TextStyle(
                      fontFamily: displayFontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SfCalendarThemeData _calendarTheme(ThemeData theme, TomeraTokens tokens) {
    return SfCalendarThemeData(
      backgroundColor: Colors.transparent,
      headerBackgroundColor: Colors.transparent,
      cellBorderColor: tokens.borderSubtle,
      todayHighlightColor: theme.colorScheme.primary,
      selectionBorderColor: theme.colorScheme.primary,
    );
  }

  /// Renders the redesign's event tile: a workspace-tinted rounded card with
  /// a colored left rail; task deadlines get a dashed-feel outline card with
  /// a status glyph instead.
  Widget _buildAppointment(
    BuildContext context,
    CalendarAppointmentDetails details,
  ) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final appointment = details.appointments.first as Appointment;
    final id = appointment.id as String;
    final isTask = id.startsWith(_taskPrefix);
    final bounds = details.bounds;
    // Below this height the title + meta line don't fit; drop the meta line.
    final compact = bounds.height < 42;
    final inMonthCell = bounds.height <= 20 && !details.isMoreAppointmentRegion;

    // Tiny month-cell strips: just a colored bar with the title.
    if (inMonthCell) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: appointment.color,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          appointment.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: workspaceForeground(appointment.color),
          ),
        ),
      );
    }

    final timeFormat = appTimeFormat(context, ref);
    final timeLabel =
        '${timeFormat.format(appointment.startTime)} – '
        '${timeFormat.format(appointment.endTime)}';

    if (isTask) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(9),
          border: Border(
            left: BorderSide(color: tokens.textTertiary, width: 3),
            top: BorderSide(color: tokens.borderStrong),
            right: BorderSide(color: tokens.borderStrong),
            bottom: BorderSide(color: tokens.borderStrong),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked_rounded,
              size: 14,
              color: tokens.textTertiary,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                appointment.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tint = Color.alphaBlend(
      appointment.color.withValues(alpha: 0.16),
      theme.colorScheme.surfaceContainer,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: appointment.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            appointment.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (!compact && !appointment.isAllDay)
            Text(
              [
                timeLabel,
                if (appointment.notes?.isNotEmpty == true) appointment.notes!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: bodyFontFamily,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentSource extends CalendarDataSource {
  _AppointmentSource(List<Appointment> source) {
    appointments = source;
  }
}
