import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/utils.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../settings/settings_providers.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

/// Work timer card on the Finance tab: start sheet when idle, ticking
/// elapsed display + stop when running (spec §6.6).
class TimerCard extends ConsumerWidget {
  const TimerCard({super.key});

  Future<void> _stop(BuildContext context, WidgetRef ref,
      TimerSession session) async {
    final elapsed = await ref.read(timerRepositoryProvider).stop(session);
    final rounding = await RoundingMinutesSetting.loadStored();
    final duration = roundedDurationMinutes(elapsed, rounding);
    if (!context.mounted) return;
    // Hand off to the billable editor pre-filled per spec §6.6; the user can
    // still edit duration and rate before saving.
    final query = Uri(queryParameters: {
      'workspaceId': session.workspaceId,
      if (session.contactId != null) 'contactId': session.contactId!,
      if (session.description?.isNotEmpty == true)
        'title': session.description!,
      'duration': '$duration',
    }).query;
    context.go('/finance/new?$query');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = ref.watch(runningTimerProvider).value;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: session == null
            ? Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.workTimer)),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.startTimer),
                    onPressed: () => _showStartSheet(context, ref),
                  ),
                ],
              )
            : _RunningTimer(
                session: session,
                onStop: () => _stop(context, ref, session),
              ),
      ),
    );
  }

  Future<void> _showStartSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _StartTimerSheet(),
    );
  }
}

class _RunningTimer extends ConsumerWidget {
  const _RunningTimer({required this.session, required this.onStop});

  final TimerSession session;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    ref.watch(timerTickProvider);
    final elapsed = elapsedMs(
        startedAtMs: session.startedAt, nowMs: utcNowMs());
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final workspace =
        workspaces.where((w) => w.id == session.workspaceId).firstOrNull;

    return Row(
      children: [
        Icon(Icons.timer, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.description?.isNotEmpty == true
                    ? session.description!
                    : (workspace?.name ?? l10n.workTimer),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatElapsed(elapsed),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.stop),
          label: Text(l10n.stopTimer),
          onPressed: onStop,
        ),
      ],
    );
  }
}

class _StartTimerSheet extends ConsumerStatefulWidget {
  const _StartTimerSheet();

  @override
  ConsumerState<_StartTimerSheet> createState() => _StartTimerSheetState();
}

class _StartTimerSheetState extends ConsumerState<_StartTimerSheet> {
  final _descriptionController = TextEditingController();
  String? _workspaceId;
  String? _contactId;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final description = _descriptionController.text.trim();
    final workspaces = ref.read(allWorkspacesProvider).value ?? [];
    final workspaceName =
        workspaces.where((w) => w.id == workspaceId).firstOrNull?.name;
    try {
      await ref.read(timerRepositoryProvider).start(
            workspaceId: workspaceId,
            contactId: _contactId,
            description: description.isEmpty ? null : description,
            notificationTitle: description.isEmpty
                ? (workspaceName ?? l10n.timerRunning)
                : description,
          );
    } on StateError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.timerAlreadyRunning)));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.startTimer,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workspaceId,
            decoration: InputDecoration(
              labelText: l10n.workspaceLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final w in workspaces)
                DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: Color(w.color)),
                      const SizedBox(width: 8),
                      Text(w.name),
                    ],
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _workspaceId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _contactId,
            decoration: InputDecoration(
              labelText: l10n.contactLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.noContact)),
              for (final contact in contacts)
                DropdownMenuItem(
                  value: contact.id,
                  child: Text(contact.name),
                ),
            ],
            onChanged: (id) => setState(() => _contactId = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.descriptionLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startTimer),
            onPressed: workspaces.isEmpty ? null : _start,
          ),
        ],
      ),
    );
  }
}
