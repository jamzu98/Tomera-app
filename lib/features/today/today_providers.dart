import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../finance/billable_math.dart';

/// A local-time heartbeat used for date-bound sections. Re-reading local time
/// on each tick also picks up timezone and DST changes without cached offsets.
final todayClockProvider = NotifierProvider<TodayClock, DateTime>(
  TodayClock.new,
);

class TodayClock extends Notifier<DateTime> with WidgetsBindingObserver {
  Timer? _heartbeat;
  Timer? _midnight;

  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    _armMidnight();
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _heartbeat?.cancel();
      _midnight?.cancel();
    });
    return DateTime.now();
  }

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      refresh();
      _armMidnight();
    });
  }

  void refresh() {
    final previous = state;
    final now = DateTime.now();
    state = now;
    if (previous.day != now.day ||
        previous.month != now.month ||
        previous.year != now.year ||
        previous.timeZoneOffset != now.timeZoneOffset) {
      _armMidnight();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}

typedef LocalDayRange = ({int start, int end});

LocalDayRange localDayRange(DateTime localNow, {tz.Location? location}) {
  final start = location == null
      ? DateTime(localNow.year, localNow.month, localNow.day)
      : tz.TZDateTime(location, localNow.year, localNow.month, localNow.day);
  // Construct the next local calendar date rather than adding 24 hours so DST
  // transition days retain their true 23/25-hour UTC range.
  final end = location == null
      ? DateTime(localNow.year, localNow.month, localNow.day + 1)
      : tz.TZDateTime(
          location,
          localNow.year,
          localNow.month,
          localNow.day + 1,
        );
  return (
    start: start.toUtc().millisecondsSinceEpoch,
    end: end.toUtc().millisecondsSinceEpoch,
  );
}

Set<String>? _enabledWorkspaceIds(Ref ref, ModuleKey module) {
  final workspaces = ref.watch(allWorkspacesProvider).value;
  if (workspaces == null) return null;
  return {
    for (final workspace in workspaces)
      if (workspace.enabledModules.contains(module)) workspace.id,
  };
}

bool _selectedModuleIsDisabled(String? selectedId, Set<String> enabledIds) =>
    selectedId != null && !enabledIds.contains(selectedId);

/// The global timer deliberately ignores the workspace filter and module
/// toggles, so a running session can never disappear from Today.
final todayActiveTimerProvider = StreamProvider.autoDispose<TimerSession?>(
  (ref) => ref.watch(timerRepositoryProvider).watchRunning(),
);

/// Stopped timers remain visible until a provenance-linked billable exists.
/// Unlike the active timer, this section follows the workspace filter and the
/// Finance module toggle.
final todayRecoverableTimerSessionsProvider =
    StreamProvider.autoDispose<List<TimerSession>>((ref) {
      final selectedId = ref.watch(selectedWorkspaceIdProvider);
      final enabledIds = _enabledWorkspaceIds(ref, ModuleKey.finance);
      if (enabledIds == null ||
          _selectedModuleIsDisabled(selectedId, enabledIds)) {
        return Stream.value(const []);
      }
      return ref
          .watch(timerRepositoryProvider)
          .watchUnconverted(workspaceId: selectedId)
          .map(
            (sessions) => selectedId != null
                ? sessions
                : sessions
                      .where(
                        (session) => enabledIds.contains(session.workspaceId),
                      )
                      .toList(growable: false),
          );
    });

/// The currently ongoing event, or the next future event.
final todayEventProvider = StreamProvider.autoDispose<Event?>((ref) {
  final now = ref.watch(todayClockProvider);
  final selectedId = ref.watch(selectedWorkspaceIdProvider);
  final enabledIds = _enabledWorkspaceIds(ref, ModuleKey.calendar);
  if (enabledIds == null || _selectedModuleIsDisabled(selectedId, enabledIds)) {
    return Stream.value(null);
  }
  return ref
      .watch(eventRepositoryProvider)
      .watchOngoingOrNext(
        now.toUtc().millisecondsSinceEpoch,
        workspaceIds: selectedId == null ? enabledIds : {selectedId},
      );
});

/// Incomplete tasks overdue or due on the current local day.
final todayTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final range = localDayRange(ref.watch(todayClockProvider));
  final selectedId = ref.watch(selectedWorkspaceIdProvider);
  final enabledIds = _enabledWorkspaceIds(ref, ModuleKey.tasks);
  if (enabledIds == null || _selectedModuleIsDisabled(selectedId, enabledIds)) {
    return Stream.value(const []);
  }
  return ref
      .watch(taskRepositoryProvider)
      .watchAll(workspaceId: selectedId)
      .map(
        (tasks) =>
            tasks
                .where(
                  (task) =>
                      task.status != TaskStatus.done &&
                      task.dueAt != null &&
                      task.dueAt! < range.end &&
                      (selectedId != null ||
                          enabledIds.contains(task.workspaceId)),
                )
                .toList()
              ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!)),
      );
});

class UnbilledSummary {
  const UnbilledSummary({
    required this.minutes,
    required this.totalsByCurrency,
  });

  final int minutes;
  final Map<String, int> totalsByCurrency;

  static const empty = UnbilledSummary(
    minutes: 0,
    totalsByCurrency: <String, int>{},
  );
}

/// Unbilled time and values, grouped by currency so unlike currencies are
/// never combined into a misleading total.
final todayUnbilledSummaryProvider =
    StreamProvider.autoDispose<UnbilledSummary>((ref) {
      final selectedId = ref.watch(selectedWorkspaceIdProvider);
      final enabledIds = _enabledWorkspaceIds(ref, ModuleKey.finance);
      if (enabledIds == null ||
          _selectedModuleIsDisabled(selectedId, enabledIds)) {
        return Stream.value(UnbilledSummary.empty);
      }
      return ref
          .watch(billableRepositoryProvider)
          .watchAll(workspaceId: selectedId)
          .map((items) {
            var minutes = 0;
            final totals = SplayTreeMap<String, int>();
            for (final item in items) {
              if (item.status != BillableStatus.unbilled ||
                  (selectedId == null &&
                      !enabledIds.contains(item.workspaceId))) {
                continue;
              }
              if (item.type == BillableType.hourly) {
                minutes += item.durationMinutes ?? 0;
              }
              totals.update(
                item.currency,
                (value) =>
                    value +
                    billableTotalCents(
                      type: item.type,
                      rateCents: item.rateCents,
                      durationMinutes: item.durationMinutes,
                      amountCents: item.amountCents,
                    ),
                ifAbsent: () => billableTotalCents(
                  type: item.type,
                  rateCents: item.rateCents,
                  durationMinutes: item.durationMinutes,
                  amountCents: item.amountCents,
                ),
              );
            }
            return UnbilledSummary(
              minutes: minutes,
              totalsByCurrency: Map.unmodifiable(totals),
            );
          });
    });

/// The three most recently edited visible notes.
final todayRecentNotesProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final selectedId = ref.watch(selectedWorkspaceIdProvider);
  final enabledIds = _enabledWorkspaceIds(ref, ModuleKey.notes);
  if (enabledIds == null || _selectedModuleIsDisabled(selectedId, enabledIds)) {
    return Stream.value(const []);
  }
  return ref
      .watch(noteRepositoryProvider)
      .watchAll(workspaceId: selectedId)
      .map(
        (notes) => notes
            .where(
              (note) =>
                  selectedId != null ||
                  note.workspaceId == null ||
                  enabledIds.contains(note.workspaceId),
            )
            .take(3)
            .toList(growable: false),
      );
});
