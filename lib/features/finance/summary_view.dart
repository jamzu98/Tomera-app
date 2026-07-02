import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import 'finance_providers.dart';
import 'finance_summary.dart';

/// Monthly finance summary (spec §6.6): overview across workspaces plus
/// per-workspace and per-contact breakdowns.
class SummaryView extends ConsumerStatefulWidget {
  const SummaryView({super.key});

  @override
  ConsumerState<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends ConsumerState<SummaryView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final billables = ref.watch(allBillablesProvider).value ?? [];
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];

    final summary = summarizeBillables(
      [
        for (final item in billables)
          (
            workspaceId: item.workspaceId,
            contactId: item.contactId,
            type: item.type,
            status: item.status,
            rateCents: item.rateCents,
            durationMinutes: item.durationMinutes,
            amountCents: item.amountCents,
            createdAtMs: item.createdAt,
          ),
      ],
      _month.year,
      _month.month,
    );

    Widget sectionTitle(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
              TextButton(
                onPressed: () => setState(() => _month =
                    DateTime(DateTime.now().year, DateTime.now().month)),
                child: Text(l10n.thisMonthButton),
              ),
            ],
          ),
        ),
        sectionTitle(l10n.overviewLabel),
        _SummaryCard(summary: summary.overall),
        if (summary.byWorkspace.isNotEmpty) ...[
          sectionTitle(l10n.byWorkspaceLabel),
          for (final entry in summary.byWorkspace.entries)
            _GroupTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: Color(workspaces
                        .where((w) => w.id == entry.key)
                        .firstOrNull
                        ?.color ??
                    0xFF888888),
              ),
              name: workspaces
                      .where((w) => w.id == entry.key)
                      .firstOrNull
                      ?.name ??
                  '—',
              summary: entry.value,
            ),
        ],
        if (summary.byContact.isNotEmpty) ...[
          sectionTitle(l10n.byContactLabel),
          for (final entry in summary.byContact.entries)
            _GroupTile(
              leading: const Icon(Icons.person_outline, size: 18),
              name: contacts
                      .where((c) => c.id == entry.key)
                      .firstOrNull
                      ?.name ??
                  '—',
              summary: entry.value,
            ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row(l10n.hoursThisMonth,
                formatMinutesAsHours(summary.minutesThisMonth)),
            row(l10n.statusUnbilled,
                '${formatCents(summary.unbilledCents)} EUR'),
            row(l10n.invoicedUnpaid,
                '${formatCents(summary.invoicedUnpaidCents)} EUR'),
            row(l10n.paidThisMonth,
                '${formatCents(summary.paidThisMonthCents)} EUR'),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.leading,
    required this.name,
    required this.summary,
  });

  final Widget leading;
  final String name;
  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      dense: true,
      leading: leading,
      title: Text(name),
      subtitle: Text(
        '${formatMinutesAsHours(summary.minutesThisMonth)}'
        ' · ${l10n.invoicedUnpaid}: ${formatCents(summary.invoicedUnpaidCents)}'
        ' · ${l10n.paidThisMonth}: ${formatCents(summary.paidThisMonthCents)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${formatCents(summary.unbilledCents)} EUR',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(l10n.statusUnbilled,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
