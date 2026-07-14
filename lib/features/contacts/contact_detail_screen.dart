import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/financial_summary_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../connected/connected_timeline.dart';
import '../connected/connected_timeline_section.dart';
import '../finance/billable_math.dart';
import '../finance/finance_providers.dart';
import '../finance/finance_screen.dart' show billableStatusLabel;
import '../notes/note_providers.dart';
import '../settings/date_time_format.dart';
import '../workspaces/workspace_style.dart';
import 'contact_providers.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteContactTitle),
        content: Text(l10n.deleteContactBody(contact.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(contactRepositoryProvider).delete(contact.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final contactValue = ref.watch(contactByIdProvider(contactId));
    final contact = contactValue.value;
    if (contactValue.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (contact == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final roles = ref.watch(contactRolesProvider(contactId)).value ?? [];
    final selectedWorkspaceId = ref.watch(selectedWorkspaceIdProvider);
    final noteWorkspaceId =
        roles.any((role) => role.workspaceId == selectedWorkspaceId)
        ? selectedWorkspaceId
        : roles.firstOrNull?.workspaceId;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final tasks = ref.watch(tasksForContactProvider(contactId)).value ?? [];
    final events = ref.watch(eventsForContactProvider(contactId)).value ?? [];
    final parentedNotes =
        ref.watch(notesForContactProvider(contactId)).value ?? [];
    final backlinkNotes =
        ref
            .watch(
              noteBacklinksProvider((type: ParentType.contact, id: contactId)),
            )
            .value ??
        [];
    final notesById = <String, Note>{
      for (final note in parentedNotes) note.id: note,
      for (final note in backlinkNotes) note.id: note,
    };
    final notes = notesById.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final billables =
        ref.watch(billablesForContactProvider(contactId)).value ?? [];
    final timers = ref.watch(timersForContactProvider(contactId)).value ?? [];
    final totalsByCurrency =
        ref.watch(contactTotalsByCurrencyProvider(contactId)).value ?? {};
    final timeline = buildConnectedTimeline(
      events: events,
      tasks: tasks,
      notes: notes,
      timers: timers,
      billables: billables,
    );
    final currencies = totalsByCurrency.keys.toList()..sort();

    Workspace? workspaceOf(String id) =>
        workspaces.where((w) => w.id == id).firstOrNull;

    // Identity color: the first workspace this contact belongs to.
    final identityColor = Color(
      roles.isNotEmpty
          ? (workspaceOf(roles.first.workspaceId)?.color ?? 0xFFB7AD9C)
          : 0xFFB7AD9C,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editContact,
            onPressed: () => context.push('/contacts/$contactId/edit'),
          ),
          AppBarOverflowMenu(
            entries: [
              (
                icon: Icons.delete_outline_rounded,
                label: l10n.delete,
                onTap: () => _delete(context, ref, contact),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _IdentityHeader(
            contact: contact,
            color: identityColor,
            roleChips: [
              for (final role in roles)
                if (workspaceOf(role.workspaceId) case final workspace?)
                  _RoleChip(
                    color: Color(workspace.color),
                    label: role.roleLabel?.isNotEmpty == true
                        ? '${workspace.name} · ${role.roleLabel}'
                        : workspace.name,
                  ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActions(contact: contact, contactId: contactId),
          const SizedBox(height: 6),
          if (contact.email?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.mail_outline_rounded,
              label: l10n.emailLabel,
              value: contact.email!,
            ),
          if (contact.phone?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.call_outlined,
              label: l10n.phoneLabel,
              value: contact.phone!,
              tabular: true,
            ),
          if (contact.organization?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.business_outlined,
              label: l10n.organizationLabel,
              value: contact.organization!,
            ),
          if (contact.defaultHourlyRateCents case final rate?)
            _InfoRow(
              icon: Icons.payments_outlined,
              label: l10n.defaultRateLabel,
              value: '${formatCents(rate)} EUR / h',
              tabular: true,
            ),
          if (contact.notesText?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
              child: Text(
                contact.notesText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ConnectedTimelineSection(activities: timeline),
          _Section(
            title: l10n.linkedTasks,
            children: [
              for (final task in tasks)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(
                    task.status == TaskStatus.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: task.status == TaskStatus.done
                        ? tokens.success
                        : tokens.textTertiary,
                  ),
                  title: Text(task.title),
                  onTap: () => context.push('/work/tasks/${task.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedEvents,
            children: [
              for (final event in events)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: WorkspaceDot(
                    color: Color(
                      workspaceOf(event.workspaceId)?.color ?? 0xFFB7AD9C,
                    ),
                    size: 10,
                  ),
                  title: Text(event.title),
                  subtitle: Text(() {
                    final starts = DateTime.fromMillisecondsSinceEpoch(
                      event.startsAt,
                      isUtc: true,
                    ).toLocal();
                    return '${DateFormat.yMMMEd().format(starts)} '
                        '${appTimeFormat(context, ref).format(starts)}';
                  }()),
                  onTap: () => context.push('/calendar/${event.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedNotes,
            actionLabel: l10n.addNoteAction,
            onAction: () => context.push(
              Uri(
                path: '/work/notes/new',
                queryParameters: {
                  if (noteWorkspaceId != null) 'workspaceId': noteWorkspaceId,
                  'parentType': ParentType.contact.dbValue,
                  'parentId': contactId,
                },
              ).toString(),
            ),
            children: [
              for (final note in notes)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: tokens.textSecondary,
                  ),
                  title: Text(note.title),
                  onTap: () => context.push('/work/notes/${note.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedBillables,
            actionLabel: l10n.newBillable,
            onAction: () => context.push('/finance/new?contactId=$contactId'),
            children: [
              for (final item in billables)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: tokens.textSecondary,
                  ),
                  title: Text(item.title),
                  subtitle: Text(billableStatusLabel(l10n, item.status)),
                  trailing: Text(
                    '${formatCents(billableTotalCents(type: item.type, rateCents: item.rateCents, durationMinutes: item.durationMinutes, amountCents: item.amountCents))} ${item.currency}',
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  onTap: () => context.push('/finance/${item.id}'),
                ),
            ],
          ),
          if (currencies.isNotEmpty) ...[
            SectionHeader(
              title: l10n.financialSummary,
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
            ),
            for (final currency in currencies) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                child: Text(currency, style: theme.textTheme.labelLarge),
              ),
              FinancialSummaryCard(
                currency: currency,
                rows: [
                  (
                    l10n.statusUnbilled,
                    totalsByCurrency[currency]!.unbilled,
                    false,
                  ),
                  (
                    l10n.statusInvoiced,
                    totalsByCurrency[currency]!.invoiced,
                    false,
                  ),
                  (l10n.statusPaid, totalsByCurrency[currency]!.paid, true),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.contact,
    required this.color,
    required this.roleChips,
  });

  final Contact contact;
  final Color color;
  final List<Widget> roleChips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.borderStrong),
          ),
          alignment: Alignment.center,
          child: Text(
            initialsOf(contact.name),
            style: TextStyle(
              fontFamily: displayFontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: workspaceForeground(color),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          contact.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        if (contact.organization?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Text(
            contact.organization!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ],
        if (roleChips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: roleChips,
          ),
        ],
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WorkspaceDot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.contact, required this.contactId});

  final Contact contact;
  final String contactId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.timer_outlined,
            label: l10n.logTimeAction,
            primary: true,
            onTap: () => context.push('/finance/new?contactId=$contactId'),
          ),
        ),
        if (contact.phone?.isNotEmpty == true) ...[
          const SizedBox(width: 9),
          Expanded(
            child: _ActionButton(
              icon: Icons.call_outlined,
              label: l10n.callAction,
              onTap: () => launchUrl(Uri(scheme: 'tel', path: contact.phone!)),
            ),
          ),
        ],
        if (contact.email?.isNotEmpty == true) ...[
          const SizedBox(width: 9),
          Expanded(
            child: _ActionButton(
              icon: Icons.mail_outline_rounded,
              label: l10n.emailLabel,
              onTap: () =>
                  launchUrl(Uri(scheme: 'mailto', path: contact.email!)),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = primary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    return Material(
      color: primary
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: primary
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tabular = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: tokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: tabular ? tabularFigures : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: actionLabel,
          actionIcon: onAction != null ? Icons.add_rounded : null,
          onAction: onAction,
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
        ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              l10n.nothingLinkedYet,
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...children,
      ],
    );
  }
}

/// "Antti Virtanen" -> "AV".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
