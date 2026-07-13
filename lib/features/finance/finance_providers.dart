import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import 'billable_math.dart';

/// Billables visible under the current workspace filter. In the
/// all-workspaces view, items from workspaces with the finance module
/// disabled are hidden (data is never deleted).
final visibleBillablesProvider = StreamProvider.autoDispose<List<BillableItem>>(
  (ref) {
    final workspaceId = ref.watch(selectedWorkspaceIdProvider);
    final billables = ref
        .watch(billableRepositoryProvider)
        .watchAll(workspaceId: workspaceId);
    if (workspaceId != null) return billables;

    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final enabledIds = {
      for (final w in workspaces)
        if (w.enabledModules.contains(ModuleKey.finance)) w.id,
    };
    return billables.map(
      (list) => list.where((b) => enabledIds.contains(b.workspaceId)).toList(),
    );
  },
);

/// One billable by id (edit screen).
final billableByIdProvider = StreamProvider.autoDispose
    .family<BillableItem?, String>(
      (ref, id) => ref.watch(billableRepositoryProvider).watchById(id),
    );

/// Billables linked to a contact (contact detail screen).
final billablesForContactProvider = StreamProvider.autoDispose
    .family<List<BillableItem>, String>(
      (ref, contactId) =>
          ref.watch(billableRepositoryProvider).watchAll(contactId: contactId),
    );

/// Every live billable across all workspaces — the summary view is the
/// spec's "monthly overview across workspaces" and ignores the filter.
final allBillablesProvider = StreamProvider.autoDispose<List<BillableItem>>(
  (ref) => ref.watch(billableRepositoryProvider).watchAll(),
);

/// The single running timer session, if any (spec §6.6 v1: one at a time).
final runningTimerProvider = StreamProvider<TimerSession?>(
  (ref) => ref.watch(timerRepositoryProvider).watchRunning(),
);

final timerSessionByIdProvider = StreamProvider.autoDispose
    .family<TimerSession?, String>(
      (ref, timerId) => ref
          .watch(timerRepositoryProvider)
          .watchAll()
          .map(
            (sessions) =>
                sessions.where((session) => session.id == timerId).firstOrNull,
          ),
    );

final timerBillableProvider = StreamProvider.autoDispose
    .family<BillableItem?, String>(
      (ref, timerId) => ref
          .watch(billableRepositoryProvider)
          .watchAll(timerSessionId: timerId)
          .map((items) => items.firstOrNull),
    );

/// Stopped timers which have not yet produced an active billable. These are
/// deliberately durable so dismissing the conversion editor cannot lose work.
final recoverableTimerSessionsProvider =
    StreamProvider.autoDispose<List<TimerSession>>((ref) {
      final workspaceId = ref.watch(selectedWorkspaceIdProvider);
      final sessions = ref
          .watch(timerRepositoryProvider)
          .watchUnconverted(workspaceId: workspaceId);
      final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
      if (workspaceId != null) {
        final selected = workspaces
            .where((workspace) => workspace.id == workspaceId)
            .firstOrNull;
        if (selected != null &&
            !selected.enabledModules.contains(ModuleKey.finance)) {
          return Stream.value(const []);
        }
        return sessions;
      }

      final enabledIds = {
        for (final w in workspaces)
          if (w.enabledModules.contains(ModuleKey.finance)) w.id,
      };
      return sessions.map(
        (list) =>
            list.where((s) => enabledIds.contains(s.workspaceId)).toList(),
      );
    });

typedef HourlyRateContext = ({
  String workspaceId,
  String? contactId,
  String? projectId,
});

/// Effective rate for an editor/timer context, applying the repository's
/// project → workspace/contact → contact → workspace precedence.
final resolvedHourlyRateProvider = FutureProvider.autoDispose
    .family<int?, HourlyRateContext>(
      (ref, context) => ref
          .watch(billableRepositoryProvider)
          .resolveHourlyRateCents(
            workspaceId: context.workspaceId,
            contactId: context.contactId,
            projectId: context.projectId,
          ),
    );

/// One-second heartbeat for elapsed-time displays. Elapsed is always
/// recomputed from the session's persisted startedAt, never accumulated.
final timerTickProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ),
);

/// Unbilled/invoiced/paid totals for a contact (spec §6.5).
final contactTotalsProvider = StreamProvider.autoDispose
    .family<BillableTotals, String>(
      (ref, contactId) => ref
          .watch(billableRepositoryProvider)
          .watchTotalsForContact(contactId),
    );

final contactTotalsByCurrencyProvider = StreamProvider.autoDispose
    .family<Map<String, BillableTotals>, String>(
      (ref, contactId) => ref
          .watch(billableRepositoryProvider)
          .watchTotalsByCurrencyForContact(contactId),
    );
