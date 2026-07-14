import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/editorial.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

Future<void> showStartTimerSheet(
  BuildContext context, {
  String? workspaceId,
  String? contactId,
  String? projectId,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (context) => _StartTimerSheet(
    initialWorkspaceId: workspaceId,
    initialContactId: contactId,
    initialProjectId: projectId,
  ),
);

/// Featured work timer card for the Finance tab.
class TimerCard extends ConsumerWidget {
  const TimerCard({super.key});

  Future<void> _stop(
    BuildContext context,
    WidgetRef ref,
    TimerSession session,
  ) async {
    final elapsed = await ref.read(timerRepositoryProvider).stop(session);
    final rounding = await RoundingMinutesSetting.loadStored();
    final duration = roundedDurationMinutes(elapsed, rounding);
    if (!context.mounted) return;
    // Hand off to the billable editor pre-filled per spec §6.6; the user can
    // still edit duration and rate before saving.
    final query = Uri(
      queryParameters: {
        'workspaceId': session.workspaceId,
        if (session.contactId != null) 'contactId': session.contactId!,
        if (session.projectId != null) 'projectId': session.projectId!,
        'timerSessionId': session.id,
        if (session.description?.isNotEmpty == true)
          'title': session.description!,
        'duration': '$duration',
      },
    ).query;
    await context.push('/finance/new?$query');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runningTimerProvider).value;
    return EditorialFeaturedCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: session == null
          ? _IdleTimer(
              onStart: () => showStartTimerSheet(
                context,
                workspaceId: ref.read(selectedWorkspaceIdProvider),
              ),
            )
          : _RunningTimer(
              session: session,
              onStop: () => _stop(context, ref, session),
            ),
    );
  }
}

/// Quiet label row at the top of the timer card.
class _HeroLabel extends StatelessWidget {
  const _HeroLabel({required this.text, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(
          text,
          style: TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _IdleTimer extends StatelessWidget {
  const _IdleTimer({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroLabel(text: l10n.workTimer),
        Text(
          '0:00:00',
          style: TextStyle(
            fontFamily: displayFontFamily,
            fontSize: 40,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -0.35,
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: tabularFigures,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(l10n.startTimer),
            onPressed: onStart,
          ),
        ),
      ],
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
    final tokens = context.tokens;
    ref.watch(timerTickProvider);
    final elapsed = elapsedMs(
      startedAtMs: session.startedAt,
      nowMs: utcNowMs(),
    );
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    final projects = ref.watch(allProjectsForLookupProvider).value ?? [];
    final workspace = workspaces
        .where((w) => w.id == session.workspaceId)
        .firstOrNull;
    final contact = contacts
        .where((c) => c.id == session.contactId)
        .firstOrNull;
    final project = projects
        .where((candidate) => candidate.id == session.projectId)
        .firstOrNull;

    final contextParts = [
      if (session.description?.isNotEmpty == true) session.description!,
      if (project != null) project.name,
      if (contact != null) contact.name,
      workspace?.name ?? l10n.workTimer,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroLabel(
          text: l10n.timerRunning,
          leading: PulsingDot(size: 8, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Text(
          formatElapsed(elapsed),
          style: TextStyle(
            fontFamily: displayFontFamily,
            fontSize: 44,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: -0.35,
            color: theme.colorScheme.onSurface,
            fontFeatures: tabularFigures,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (workspace != null) ...[
              WorkspaceDot(color: Color(workspace.color), size: 9),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                contextParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.stop_rounded, size: 22),
            label: Text(l10n.stopTimer),
            onPressed: onStop,
          ),
        ),
      ],
    );
  }
}

class _StartTimerSheet extends ConsumerStatefulWidget {
  const _StartTimerSheet({
    this.initialWorkspaceId,
    this.initialContactId,
    this.initialProjectId,
  });

  final String? initialWorkspaceId;
  final String? initialContactId;
  final String? initialProjectId;

  @override
  ConsumerState<_StartTimerSheet> createState() => _StartTimerSheetState();
}

class _StartTimerSheetState extends ConsumerState<_StartTimerSheet> {
  final _descriptionController = TextEditingController();
  String? _workspaceId;
  String? _contactId;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.initialWorkspaceId;
    _contactId = widget.initialContactId;
    _projectId = widget.initialProjectId;
  }

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
    final workspaceName = workspaces
        .where((w) => w.id == workspaceId)
        .firstOrNull
        ?.name;
    try {
      await ref
          .read(timerRepositoryProvider)
          .start(
            workspaceId: workspaceId,
            contactId: _contactId,
            projectId: _projectId,
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
    final projects = ref.watch(allProjectsProvider).value ?? [];
    final initialProject = projects
        .where((project) => project.id == _projectId)
        .firstOrNull;
    _workspaceId ??= initialProject?.workspaceId;
    _contactId ??= initialProject?.contactId;
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider);
    final availableProjects = projects
        .where((project) => project.workspaceId == _workspaceId)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.startTimer,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('timer-workspace-$_workspaceId'),
            initialValue:
                workspaces.any((workspace) => workspace.id == _workspaceId)
                ? _workspaceId
                : null,
            decoration: InputDecoration(labelText: l10n.workspaceLabel),
            items: [
              for (final w in workspaces)
                DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    children: [
                      WorkspaceDot(color: Color(w.color), size: 11),
                      const SizedBox(width: 8),
                      Text(w.name),
                    ],
                  ),
                ),
            ],
            onChanged: (id) => setState(() {
              if (_workspaceId != id) {
                _contactId = null;
                _projectId = null;
              }
              _workspaceId = id;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('timer-project-$_workspaceId-$_projectId'),
            initialValue:
                availableProjects.any((project) => project.id == _projectId)
                ? _projectId
                : null,
            decoration: InputDecoration(labelText: l10n.projectLabel),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.noProject)),
              for (final project in availableProjects)
                DropdownMenuItem(value: project.id, child: Text(project.name)),
            ],
            onChanged: (id) => setState(() {
              _projectId = id;
              final project = availableProjects
                  .where((candidate) => candidate.id == id)
                  .firstOrNull;
              if (project?.contactId != null) _contactId = project!.contactId;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('timer-contact-$_workspaceId-$_contactId'),
            initialValue: contacts.any((contact) => contact.id == _contactId)
                ? _contactId
                : null,
            decoration: InputDecoration(labelText: l10n.contactLabel),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.noContact)),
              for (final contact in contacts)
                DropdownMenuItem(value: contact.id, child: Text(contact.name)),
            ],
            onChanged: (id) => setState(() => _contactId = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: l10n.descriptionLabel),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.startTimer),
            onPressed: workspaces.isEmpty ? null : _start,
          ),
        ],
      ),
    );
  }
}
