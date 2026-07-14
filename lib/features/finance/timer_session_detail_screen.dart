import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../notes/note_backlinks_section.dart';
import '../projects/project_providers.dart';
import '../settings/date_time_format.dart';
import 'billable_math.dart';
import 'finance_providers.dart';
import 'finance_screen.dart' show billableStatusLabel;
import 'recoverable_timer_list.dart';
import 'timer_math.dart';

class TimerSessionDetailScreen extends ConsumerWidget {
  const TimerSessionDetailScreen({super.key, required this.timerId});

  final String timerId;

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    TimerSession session,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeTimerTitle),
        content: Text(l10n.removeTimerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeUnconvertedTime),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(timerRepositoryProvider);
    try {
      final removed = await repository.deleteUnconverted(session.id);
      if (!context.mounted) return;
      if (!removed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.timerRemovalFailed)),
        );
        return;
      }
      context.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.timerRemoved),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => repository.restore(session.id),
            ),
          ),
        );
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.timerRemovalFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sessionValue = ref.watch(timerSessionByIdProvider(timerId));
    final session = sessionValue.value;
    if (sessionValue.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workTimer)),
        body: Center(child: Text(l10n.timerSessionNotFound)),
      );
    }

    final billableValue = ref.watch(timerBillableProvider(timerId));
    final billable = billableValue.value;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    final projects = ref.watch(allProjectsForLookupProvider).value ?? [];
    final workspace = workspaces
        .where((item) => item.id == session.workspaceId)
        .firstOrNull;
    final contact = contacts
        .where((item) => item.id == session.contactId)
        .firstOrNull;
    final project = projects
        .where((item) => item.id == session.projectId)
        .firstOrNull;
    if (session.stoppedAt == null) ref.watch(timerTickProvider);
    final end = session.stoppedAt ?? utcNowMs();
    final elapsed = (end - session.startedAt).clamp(0, 1 << 62);
    final started = DateTime.fromMillisecondsSinceEpoch(
      session.startedAt,
      isUtc: true,
    ).toLocal();
    final stopped = session.stoppedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            session.stoppedAt!,
            isUtc: true,
          ).toLocal();
    final date = DateFormat.yMMMEd();
    final time = appTimeFormat(context, ref);
    String moment(DateTime value) =>
        '${date.format(value)} ${time.format(value)}';
    final canRemove =
        billableValue.hasValue && billable == null && session.stoppedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timerSessionTitle),
        actions: [
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.removeUnconvertedTime,
              onPressed: () => _remove(context, ref, session),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Icon(
            Icons.timer_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            session.description?.trim().isNotEmpty == true
                ? session.description!.trim()
                : l10n.workTimer,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            formatElapsed(elapsed),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontFeatures: tabularFigures),
          ),
          SectionHeader(
            title: l10n.formGroupDetails,
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          ),
          SoftTile(
            leading: const Icon(Icons.play_circle_outline_rounded),
            title: Text(l10n.startsLabel),
            trailing: Text(moment(started)),
          ),
          const SizedBox(height: 8),
          SoftTile(
            leading: Icon(
              stopped == null
                  ? Icons.radio_button_checked_rounded
                  : Icons.stop_circle_outlined,
            ),
            title: Text(stopped == null ? l10n.timerRunning : l10n.endsLabel),
            trailing: stopped == null ? null : Text(moment(stopped)),
          ),
          if (workspace != null) ...[
            const SizedBox(height: 8),
            SoftTile(
              leading: WorkspaceDot(color: Color(workspace.color), size: 12),
              title: Text(l10n.workspaceLabel),
              trailing: Text(workspace.name),
              onTap: () => context.push('/workspaces/${workspace.id}'),
            ),
          ],
          if (project != null) ...[
            const SizedBox(height: 8),
            SoftTile(
              leading: const Icon(Icons.layers_outlined),
              title: Text(l10n.projectLabel),
              trailing: Text(project.name),
              onTap: () => context.push('/work/projects/${project.id}'),
            ),
          ],
          if (contact != null) ...[
            const SizedBox(height: 8),
            SoftTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(l10n.contactLabel),
              trailing: Text(contact.name),
              onTap: () => context.push('/contacts/${contact.id}'),
            ),
          ],
          SectionHeader(
            title: l10n.linkedBillables,
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          ),
          if (billable != null)
            SoftTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(billable.title),
              subtitle: Text(billableStatusLabel(l10n, billable.status)),
              trailing: Text(
                '${formatCents(billableTotalCents(type: billable.type, rateCents: billable.rateCents, durationMinutes: billable.durationMinutes, amountCents: billable.amountCents))} ${billable.currency}',
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                ),
              ),
              onTap: () => context.push('/finance/${billable.id}'),
            )
          else if (session.stoppedAt != null)
            RecoverableTimerList(sessions: [session])
          else
            Text(
              l10n.timerRunning,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          NoteBacklinksSection(
            targetType: ParentType.timerSession,
            targetId: session.id,
            workspaceId: session.workspaceId,
          ),
        ],
      ),
    );
  }
}
