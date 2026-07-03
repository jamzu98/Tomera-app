import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../finance/billable_math.dart';
import '../finance/finance_screen.dart' show billableStatusLabel;
import 'project_providers.dart';
import 'projects_screen.dart' show projectColor;

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Project project) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProjectTitle),
        content: Text(l10n.deleteProjectBody(project.name)),
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
    await ref.read(projectRepositoryProvider).delete(project.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final projectValue = ref.watch(projectByIdProvider(projectId));
    final project = projectValue.value;
    if (projectValue.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (project == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    final events = ref.watch(eventsForProjectProvider(projectId)).value ?? [];
    final tasks = ref.watch(tasksForProjectProvider(projectId)).value ?? [];
    final notes = ref.watch(notesForProjectProvider(projectId)).value ?? [];
    final billables =
        ref.watch(billablesForProjectProvider(projectId)).value ?? [];
    final totals = ref.watch(projectTotalsProvider(projectId)).value;

    final workspace =
        workspaces.where((w) => w.id == project.workspaceId).firstOrNull;
    final contact =
        contacts.where((c) => c.id == project.contactId).firstOrNull;
    final color = Color(projectColor(project, workspaces));
    final dateFormat = DateFormat.MMMEd();
    final timeFormat = DateFormat.Hm();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editProject,
            onPressed: () => context.go('/calendar/projects/$projectId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _delete(context, ref, project),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (workspace != null)
                Chip(
                  avatar: Icon(Icons.circle, size: 12, color: color),
                  label: Text(workspace.name),
                ),
              if (contact != null)
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(contact.name),
                ),
              if (project.archived) Chip(label: Text(l10n.archivedLabel)),
            ],
          ),
          if (project.description?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(project.description!,
                  style: theme.textTheme.bodyMedium),
            ),
          _Section(
            title: l10n.linkedEvents,
            // The "Add instances" wizard hangs off this button (next step).
            action: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.newEvent),
              onPressed: () => context.go(
                  '/calendar/new?projectId=$projectId'),
            ),
            children: [
              for (final event in events)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 12, color: color),
                  title: Text(event.title),
                  subtitle: Text(
                    '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}'
                    ' ${timeFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}',
                  ),
                  onTap: () => context.go('/calendar/${event.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedTasks,
            action: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.newTask),
              onPressed: () =>
                  context.go('/tasks/new?projectId=$projectId'),
            ),
            children: [
              for (final task in tasks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    task.status == TaskStatus.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  title: Text(task.title),
                  onTap: () => context.go('/tasks/${task.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedNotes,
            action: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addNoteAction),
              onPressed: () => context.go(
                  '/notes/new?parentType=project&parentId=$projectId'),
            ),
            children: [
              for (final note in notes)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 18),
                  title: Text(note.title),
                  onTap: () => context.go('/notes/${note.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedBillables,
            action: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.newBillable),
              onPressed: () =>
                  context.go('/finance/new?projectId=$projectId'),
            ),
            children: [
              for (final item in billables)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long_outlined, size: 18),
                  title: Text(item.title),
                  subtitle: Text(billableStatusLabel(l10n, item.status)),
                  trailing: Text(
                    '${formatCents(billableTotalCents(
                      type: item.type,
                      rateCents: item.rateCents,
                      durationMinutes: item.durationMinutes,
                      amountCents: item.amountCents,
                    ))} ${item.currency}',
                  ),
                  onTap: () => context.go('/finance/${item.id}'),
                ),
            ],
          ),
          if (totals != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                l10n.financialSummary,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            _TotalRow(label: l10n.statusUnbilled, cents: totals.unbilled),
            _TotalRow(label: l10n.statusInvoiced, cents: totals.invoiced),
            _TotalRow(label: l10n.statusPaid, cents: totals.paid),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        if (children.isEmpty)
          Text(l10n.nothingLinkedYet, style: theme.textTheme.bodySmall)
        else
          ...children,
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${formatCents(cents)} EUR',
              style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
