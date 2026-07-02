import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import 'billable_math.dart';

/// Billables visible under the current workspace filter. In the
/// all-workspaces view, items from workspaces with the finance module
/// disabled are hidden (data is never deleted).
final visibleBillablesProvider =
    StreamProvider.autoDispose<List<BillableItem>>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceIdProvider);
  final billables =
      ref.watch(billableRepositoryProvider).watchAll(workspaceId: workspaceId);
  if (workspaceId != null) return billables;

  final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
  final enabledIds = {
    for (final w in workspaces)
      if (w.enabledModules.contains(ModuleKey.finance)) w.id,
  };
  return billables.map(
    (list) => list.where((b) => enabledIds.contains(b.workspaceId)).toList(),
  );
});

/// One billable by id (edit screen).
final billableByIdProvider =
    StreamProvider.autoDispose.family<BillableItem?, String>(
  (ref, id) => ref.watch(billableRepositoryProvider).watchById(id),
);

/// Billables linked to a contact (contact detail screen).
final billablesForContactProvider =
    StreamProvider.autoDispose.family<List<BillableItem>, String>(
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

/// One-second heartbeat for elapsed-time displays. Elapsed is always
/// recomputed from the session's persisted startedAt, never accumulated.
final timerTickProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream<DateTime>.periodic(
      const Duration(seconds: 1), (_) => DateTime.now()),
);

/// Unbilled/invoiced/paid totals for a contact (spec §6.5).
final contactTotalsProvider =
    StreamProvider.autoDispose.family<BillableTotals, String>(
  (ref, contactId) =>
      ref.watch(billableRepositoryProvider).watchTotalsForContact(contactId),
);
