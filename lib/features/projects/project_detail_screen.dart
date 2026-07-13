import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/financial_summary_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../connected/connected_timeline.dart';
import '../connected/connected_timeline_section.dart';
import '../contacts/contact_providers.dart';
import '../finance/billable_math.dart';
import '../finance/finance_screen.dart' show billableStatusLabel;
import '../notes/note_providers.dart';
import '../settings/date_time_format.dart';
import 'project_providers.dart';
import 'projects_screen.dart' show projectColor;

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
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
    final parentedNotes =
        ref.watch(notesForProjectProvider(projectId)).value ?? [];
    final backlinkNotes =
        ref
            .watch(
              noteBacklinksProvider((type: ParentType.project, id: projectId)),
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
        ref.watch(billablesForProjectProvider(projectId)).value ?? [];
    final timers = ref.watch(timersForProjectProvider(projectId)).value ?? [];
    final totalsByCurrency =
        ref.watch(projectTotalsByCurrencyProvider(projectId)).value ?? {};
    final timeline = buildConnectedTimeline(
      events: events,
      tasks: tasks,
      notes: notes,
      timers: timers,
      billables: billables,
    );
    final currencies = totalsByCurrency.keys.toList()..sort();

    final workspace = workspaces
        .where((w) => w.id == project.workspaceId)
        .firstOrNull;
    final contact = contacts
        .where((c) => c.id == project.contactId)
        .firstOrNull;
    final color = Color(projectColor(project, workspaces));
    final dateFormat = DateFormat.MMMEd();
    final timeFormat = appTimeFormat(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editProject,
            onPressed: () => context.push('/work/projects/$projectId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
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
                  avatar: WorkspaceDot(size: 12, color: color),
                  label: Text(workspace.name),
                ),
              if (contact != null)
                Chip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 16),
                  label: Text(contact.name),
                ),
              if (project.archived) Chip(label: Text(l10n.archivedLabel)),
            ],
          ),
          if (project.description?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                project.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.tokens.ink2,
                ),
              ),
            ),
          ConnectedTimelineSection(activities: timeline),
          _Section(
            title: l10n.linkedEvents,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: Text(l10n.addInstances),
                  onPressed: () =>
                      context.push('/work/projects/$projectId/instances'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.newEvent),
                  onPressed: () =>
                      context.push('/calendar/new?projectId=$projectId'),
                ),
              ],
            ),
            children: [
              for (final event in events)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: WorkspaceDot(size: 10, color: color),
                  title: Text(event.title),
                  subtitle: Text(
                    '${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}'
                    ' ${timeFormat.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt, isUtc: true).toLocal())}',
                  ),
                  onTap: () => context.push('/calendar/${event.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedTasks,
            action: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.newTask),
              onPressed: () =>
                  context.push('/work/tasks/new?projectId=$projectId'),
            ),
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
                        ? context.tokens.success
                        : context.tokens.ink3,
                  ),
                  title: Text(task.title),
                  onTap: () => context.push('/work/tasks/${task.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedNotes,
            action: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.addNoteAction),
              onPressed: () => context.push(
                Uri(
                  path: '/work/notes/new',
                  queryParameters: {
                    'workspaceId': project.workspaceId,
                    'parentType': ParentType.project.dbValue,
                    'parentId': projectId,
                  },
                ).toString(),
              ),
            ),
            children: [
              for (final note in notes)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: context.tokens.ink2,
                  ),
                  title: Text(note.title),
                  onTap: () => context.push('/work/notes/${note.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedBillables,
            action: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.newBillable),
              onPressed: () =>
                  context.push('/finance/new?projectId=$projectId'),
            ),
            children: [
              for (final item in billables)
                SoftTile(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: context.tokens.ink2,
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
          padding: const EdgeInsets.fromLTRB(6, 20, 0, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    color: context.tokens.ink3,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
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
