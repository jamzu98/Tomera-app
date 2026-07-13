import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/filter_sheet.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/status_ring.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import 'billable_csv.dart';
import 'billable_math.dart';
import 'finance_providers.dart';
import 'recoverable_timer_list.dart';
import 'summary_view.dart';
import 'timer_card.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final Set<BillableStatus> _statusFilter = {...BillableStatus.values};
  bool _showSummary = false;

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final l10n = AppLocalizations.of(context)!;
          final allSelected =
              _statusFilter.length == BillableStatus.values.length;
          return FilterSheetScaffold(
            title: l10n.filtersLabel,
            clearAllLabel: l10n.clearFilters,
            onClearAll: allSelected
                ? null
                : () {
                    setState(
                      () => _statusFilter
                        ..clear()
                        ..addAll(BillableStatus.values),
                    );
                    setSheetState(() {});
                  },
            child: Column(
              children: [
                for (final status in BillableStatus.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(billableStatusLabel(l10n, status)),
                    value: _statusFilter.contains(status),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _statusFilter.add(status);
                        } else {
                          _statusFilter.remove(status);
                        }
                      });
                      setSheetState(() {});
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Exports the currently visible (workspace- and status-filtered) items
  /// through the platform share sheet (spec §6.6).
  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final items = (ref.read(visibleBillablesProvider).value ?? [])
        .where((b) => _statusFilter.contains(b.status))
        .toList();
    if (items.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.nothingToExport)));
      return;
    }
    final workspaces = ref.read(allWorkspacesProvider).value ?? [];
    final contacts = ref.read(allContactsProvider).value ?? [];
    final csv = billablesToCsv(
      items,
      workspaceName: (id) =>
          workspaces.where((w) => w.id == id).firstOrNull?.name ?? id,
      contactName: (id) =>
          contacts.where((c) => c.id == id).firstOrNull?.name ?? '',
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
          fileNameOverrides: ['tomera-billables.csv'],
        ),
      );
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final billablesValue = ref.watch(visibleBillablesProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled =
        selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.finance);
    final Widget contentSliver = moduleDisabled
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.visibility_off_outlined,
              title: l10n.moduleDisabledTitle,
              body: l10n.financeModuleDisabled,
              primaryAction: EmptyStateAction(
                label: l10n.editWorkspace,
                icon: Icons.tune_rounded,
                onPressed: () =>
                    context.push('/workspaces/${selectedWorkspace.id}'),
              ),
            ),
          )
        : _showSummary
        ? const SliverToBoxAdapter(child: SummaryView())
        : switch (billablesValue) {
            AsyncValue(value: final items?) when items.isNotEmpty =>
              _BillableSliver(
                items: items
                    .where((b) => _statusFilter.contains(b.status))
                    .toList(),
                onClearFilters: () => setState(() {
                  _statusFilter
                    ..clear()
                    ..addAll(BillableStatus.values);
                }),
              ),
            AsyncValue(isLoading: true) => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            AsyncValue(hasError: true) => SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.unableToLoadTitle,
                body: l10n.unableToLoadBody,
                retryLabel: l10n.retry,
                onRetry: () => ref.invalidate(visibleBillablesProvider),
              ),
            ),
            _ => SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.emptyBillablesTitle,
                body: l10n.emptyBillablesBody,
                primaryAction: EmptyStateAction(
                  label: l10n.newBillable,
                  icon: Icons.add_rounded,
                  onPressed: () => context.go('/finance/new'),
                ),
              ),
            ),
          };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabFinance),
        actions: [
          const Center(child: WorkspaceSwitcherPill(compact: true)),
          const SizedBox(width: 4),
          AppBarOverflowMenu(
            entries: [
              (
                icon: Icons.ios_share_rounded,
                label: l10n.exportCsv,
                onTap: _exportCsv,
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: TimerCard()),
          const SliverToBoxAdapter(child: _RecoverableTimersPanel()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.itemsTab)),
                  ButtonSegment(value: true, label: Text(l10n.summaryTab)),
                ],
                selected: {_showSummary},
                onSelectionChanged: (selection) =>
                    setState(() => _showSummary = selection.first),
              ),
            ),
          ),
          if (!_showSummary)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilterButton(
                    label: l10n.filtersLabel,
                    activeCount:
                        BillableStatus.values.length - _statusFilter.length,
                    onPressed: _showFilters,
                  ),
                ),
              ),
            ),
          contentSliver,
        ],
      ),
    );
  }
}

class _RecoverableTimersPanel extends ConsumerWidget {
  const _RecoverableTimersPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(recoverableTimerSessionsProvider);
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.unconvertedTime,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.unconvertedTimeBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              RecoverableTimerList(sessions: sessions),
            ],
          ),
        );
      },
    );
  }
}

class _BillableSliver extends ConsumerWidget {
  const _BillableSliver({required this.items, required this.onClearFilters});

  final List<BillableItem> items;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: l10n.emptyBillablesTitle,
          body: l10n.emptyBillablesBody,
          primaryAction: EmptyStateAction(
            label: l10n.newBillable,
            icon: Icons.add_rounded,
            onPressed: () => context.go('/finance/new'),
          ),
          secondaryAction: EmptyStateAction(
            label: l10n.clearFilters,
            onPressed: onClearFilters,
          ),
        ),
      );
    }
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];

    return SliverPadding(
      padding: const EdgeInsets.only(top: 6, bottom: 88),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          final workspace = workspaces
              .where((w) => w.id == item.workspaceId)
              .firstOrNull;
          final contact = contacts
              .where((c) => c.id == item.contactId)
              .firstOrNull;
          final total = billableTotalCents(
            type: item.type,
            rateCents: item.rateCents,
            durationMinutes: item.durationMinutes,
            amountCents: item.amountCents,
          );
          return _BillableTile(
            item: item,
            workspace: workspace,
            contact: contact,
            totalCents: total,
          );
        }, childCount: items.length),
      ),
    );
  }
}

class _BillableTile extends ConsumerWidget {
  const _BillableTile({
    required this.item,
    required this.workspace,
    required this.contact,
    required this.totalCents,
  });

  final BillableItem item;
  final Workspace? workspace;
  final Contact? contact;
  final int totalCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Leading status marker cycles unbilled -> invoiced -> paid on tap.
    final (statusIcon, statusColor, statusFilled) = switch (item.status) {
      BillableStatus.unbilled => (
        Icons.radio_button_unchecked_rounded,
        tokens.ink3,
        false,
      ),
      BillableStatus.invoiced => (
        Icons.schedule_rounded,
        const Color(0xFFE4AB3C),
        false,
      ),
      BillableStatus.paid => (Icons.check_rounded, tokens.success, true),
    };

    return SoftTile(
      leading: StatusRing(
        icon: statusIcon,
        color: statusColor,
        filled: statusFilled,
        squared: true,
        size: 38,
        tooltip: billableStatusLabel(l10n, item.status),
        onTap: () async {
          final previous = item.status;
          await ref.read(billableRepositoryProvider).cycleStatus(item);
          if (!context.mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.billableStatusChanged),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => ref
                    .read(billableRepositoryProvider)
                    .update(item.id, status: previous),
              ),
            ),
          );
        },
      ),
      title: Text(item.title),
      subtitle: Row(
        children: [
          if (workspace != null) ...[
            WorkspaceDot(color: Color(workspace!.color)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              [
                if (contact != null) contact!.name,
                if (workspace != null && contact == null) workspace!.name,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatCents(totalCents),
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: theme.colorScheme.onSurface,
              fontFeatures: tabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${item.currency} · ${billableStatusLabel(l10n, item.status)}'
                .toUpperCase(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: tokens.ink3,
            ),
          ),
        ],
      ),
      onTap: () => context.go('/finance/${item.id}'),
    );
  }
}

String billableStatusLabel(AppLocalizations l10n, BillableStatus status) =>
    switch (status) {
      BillableStatus.unbilled => l10n.statusUnbilled,
      BillableStatus.invoiced => l10n.statusInvoiced,
      BillableStatus.paid => l10n.statusPaid,
    };
