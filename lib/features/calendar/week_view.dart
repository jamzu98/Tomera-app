import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import 'event_layout.dart';

const _hourHeight = 56.0;
const _gutterWidth = 44.0;

/// Custom 7-day week grid: hour lines, positioned event blocks colored by
/// workspace, all-day strip on top. Tapping an empty slot creates an event
/// at that hour.
class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.days,
    required this.events,
    required this.colorOf,
    required this.onEventTap,
    required this.onSlotTap,
  });

  /// Seven local midnights, first day of week first.
  final List<DateTime> days;
  final List<Event> events;
  final Color Function(String workspaceId) colorOf;
  final ValueChanged<Event> onEventTap;
  final ValueChanged<DateTime> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final allDayEvents = events.where((e) => e.allDay).toList();
    return Column(
      children: [
        _DayHeaderRow(days: days),
        if (allDayEvents.isNotEmpty)
          _AllDayStrip(
            days: days,
            events: allDayEvents,
            colorOf: colorOf,
            onEventTap: onEventTap,
          ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: ScrollController(
                initialScrollOffset: 7.5 * _hourHeight),
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HourGutter(),
                  for (final day in days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        events: events,
                        colorOf: colorOf,
                        onEventTap: onEventTap,
                        onSlotTap: onSlotTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(width: _gutterWidth),
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(
                    MaterialLocalizations.of(context)
                        .narrowWeekdays[day.weekday % 7],
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: _isSameDay(day, now)
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _isSameDay(day, now)
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.days,
    required this.events,
    required this.colorOf,
    required this.onEventTap,
  });

  final List<DateTime> days;
  final List<Event> events;
  final Color Function(String workspaceId) colorOf;
  final ValueChanged<Event> onEventTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: _gutterWidth),
        for (final day in days)
          Expanded(
            child: Column(
              children: [
                for (final event in events.where(
                    (e) => _intersectsDay(e, day)))
                  GestureDetector(
                    onTap: () => onEventTap(event),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: colorOf(event.workspaceId),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HourGutter extends StatelessWidget {
  const _HourGutter();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    return SizedBox(
      width: _gutterWidth,
      height: 24 * _hourHeight,
      child: Stack(
        children: [
          for (var hour = 1; hour < 24; hour++)
            Positioned(
              top: hour * _hourHeight - 7,
              right: 6,
              child: Text('$hour', style: style),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.colorOf,
    required this.onEventTap,
    required this.onSlotTap,
  });

  final DateTime day;
  final List<Event> events;
  final Color Function(String workspaceId) colorOf;
  final ValueChanged<Event> onEventTap;
  final ValueChanged<DateTime> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final dayStart = day.millisecondsSinceEpoch;
    final dayEnd = DateTime(day.year, day.month, day.day + 1)
        .millisecondsSinceEpoch;
    final dayEvents = events
        .where((e) => !e.allDay && e.startsAt < dayEnd && e.endsAt > dayStart)
        .toList();
    final laidOut = layoutEvents(dayEvents);
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final hour = (details.localPosition.dy / _hourHeight).floor();
            onSlotTap(DateTime(day.year, day.month, day.day, hour));
          },
          child: SizedBox(
            height: 24 * _hourHeight,
            child: Stack(
              children: [
                // Hour and column separators.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: borderColor)),
                    ),
                  ),
                ),
                for (var hour = 1; hour < 24; hour++)
                  Positioned(
                    top: hour * _hourHeight,
                    left: 0,
                    right: 0,
                    child: Divider(height: 1, color: borderColor),
                  ),
                for (final placed in laidOut)
                  _eventBlock(placed, dayStart, dayEnd, width),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _eventBlock(
      LaidOutEvent placed, int dayStartMs, int dayEndMs, double width) {
    final event = placed.event;
    // Epoch ms are timezone-independent; dayStartMs is local midnight's epoch,
    // so the difference below is already "time since local midnight".
    final visibleStart = event.startsAt.clamp(dayStartMs, dayEndMs);
    final visibleEnd = event.endsAt.clamp(dayStartMs, dayEndMs);
    const msPerHour = Duration.millisecondsPerHour;

    final top = (visibleStart - dayStartMs) / msPerHour * _hourHeight;
    final height = ((visibleEnd - visibleStart) / msPerHour * _hourHeight)
        .clamp(20.0, 24 * _hourHeight);
    final laneWidth = width / placed.laneCount;

    return Positioned(
      top: top,
      left: placed.lane * laneWidth,
      width: laneWidth,
      height: height,
      child: GestureDetector(
        onTap: () => onEventTap(event),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: colorOf(event.workspaceId),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.title,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _intersectsDay(Event event, DateTime day) {
  final dayStart = day.millisecondsSinceEpoch;
  final dayEnd =
      DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch;
  return event.startsAt < dayEnd && event.endsAt > dayStart;
}
