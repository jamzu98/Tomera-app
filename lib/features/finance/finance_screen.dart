import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import 'billable_math.dart';
import 'finance_providers.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final Set<BillableStatus> _statusFilter = {...BillableStatus.values};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final billablesValue = ref.watch(visibleBillablesProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.finance);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabFinance),
        actions: const [WorkspaceFilterButton(), WorkspacesButton()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newBillable,
        onPressed: () => context.go('/finance/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final status in BillableStatus.values)
                  FilterChip(
                    label: Text(billableStatusLabel(l10n, status)),
                    selected: _statusFilter.contains(status),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _statusFilter.add(status);
                      } else {
                        _statusFilter.remove(status);
                      }
                    }),
                  ),
              ],
            ),
          ),
          if (moduleDisabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.financeModuleDisabled,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: switch (billablesValue) {
              AsyncValue(value: final items?) when items.isNotEmpty =>
                _BillableList(
                  items: items
                      .where((b) => _statusFilter.contains(b.status))
                      .toList(),
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => _EmptyState(l10n: l10n),
            },
          ),
        ],
      ),
    );
  }
}

class _BillableList extends ConsumerWidget {
  const _BillableList({required this.items});

  final List<BillableItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) return _EmptyState(l10n: l10n);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final workspace =
            workspaces.where((w) => w.id == item.workspaceId).firstOrNull;
        final contact =
            contacts.where((c) => c.id == item.contactId).firstOrNull;
        final total = billableTotalCents(
          type: item.type,
          rateCents: item.rateCents,
          durationMinutes: item.durationMinutes,
          amountCents: item.amountCents,
        );
        final subtitleParts = [
          billableStatusLabel(l10n, item.status),
          if (contact != null) contact.name,
        ];
        return ListTile(
          leading: IconButton(
            icon: Icon(switch (item.status) {
              BillableStatus.unbilled => Icons.receipt_long_outlined,
              BillableStatus.invoiced => Icons.outgoing_mail,
              BillableStatus.paid => Icons.check_circle,
            }),
            color: switch (item.status) {
              BillableStatus.unbilled => Theme.of(context).colorScheme.outline,
              BillableStatus.invoiced => Theme.of(context).colorScheme.tertiary,
              BillableStatus.paid => Theme.of(context).colorScheme.primary,
            },
            tooltip: billableStatusLabel(l10n, item.status),
            onPressed: () =>
                ref.read(billableRepositoryProvider).cycleStatus(item),
          ),
          title: Text(item.title),
          subtitle: Text(subtitleParts.join(' · ')),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatCents(total)} ${item.currency}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (workspace != null)
                Icon(Icons.circle, size: 10, color: Color(workspace.color)),
            ],
          ),
          onTap: () => context.go('/finance/${item.id}'),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.emptyBillablesTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.emptyBillablesBody),
        ],
      ),
    );
  }
}

String billableStatusLabel(AppLocalizations l10n, BillableStatus status) =>
    switch (status) {
      BillableStatus.unbilled => l10n.statusUnbilled,
      BillableStatus.invoiced => l10n.statusInvoiced,
      BillableStatus.paid => l10n.statusPaid,
    };
