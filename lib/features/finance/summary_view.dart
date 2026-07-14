import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_avatar.dart';
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(_month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shiftMonth(1),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _month = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                    ),
                  ),
                  child: Text(l10n.thisMonthButton),
                ),
              ],
            ),
          ),
          SectionHeader(title: l10n.overviewLabel),
          _SummaryCard(summary: summary.overall),
          if (summary.byWorkspace.isNotEmpty) ...[
            SectionHeader(title: l10n.byWorkspaceLabel),
            for (final entry in summary.byWorkspace.entries)
              _GroupTile(
                leading: WorkspaceDot(
                  size: 12,
                  color: Color(
                    workspaces
                            .where((w) => w.id == entry.key)
                            .firstOrNull
                            ?.color ??
                        0xFFB7AD9C,
                  ),
                ),
                name:
                    workspaces
                        .where((w) => w.id == entry.key)
                        .firstOrNull
                        ?.name ??
                    '—',
                summary: entry.value,
              ),
          ],
          if (summary.byContact.isNotEmpty) ...[
            SectionHeader(title: l10n.byContactLabel),
            for (final entry in summary.byContact.entries)
              _GroupTile(
                leading: const Icon(Icons.person_outline_rounded, size: 18),
                name:
                    contacts
                        .where((c) => c.id == entry.key)
                        .firstOrNull
                        ?.name ??
                    '—',
                summary: entry.value,
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    Widget row(String label, String value, {bool highlighted = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 13.5,
                    fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                    color: highlighted
                        ? theme.colorScheme.onSurface
                        : tokens.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: highlighted ? 16 : 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: theme.colorScheme.onSurface,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            row(
              l10n.hoursThisMonth,
              formatMinutesAsHours(summary.minutesThisMonth),
            ),
            row(
              l10n.statusUnbilled,
              '${formatCents(summary.unbilledCents)} EUR',
            ),
            row(
              l10n.invoicedUnpaid,
              '${formatCents(summary.invoicedUnpaidCents)} EUR',
            ),
            row(
              l10n.paidThisMonth,
              '${formatCents(summary.paidThisMonthCents)} EUR',
              highlighted: true,
            ),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return SoftTile(
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
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontFeatures: tabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.statusUnbilled.toUpperCase(),
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
