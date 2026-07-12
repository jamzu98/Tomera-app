import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../settings/settings_providers.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

/// Work timer hero on the Finance tab: a dark card with a living Bricolage
/// clock while running, and a calm start state when idle (spec §6.6).
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
    final session = ref.watch(runningTimerProvider).value;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.heroBackground,
            borderRadius: BorderRadius.circular(26),
            border:
                Border.all(color: tokens.heroInk.withValues(alpha: 0.06)),
          ),
          child: Stack(
            children: [
              // Orange radial glow rising from the top-right corner.
              Positioned(
                right: -40,
                top: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFEE7B3C)
                              .withValues(alpha: session == null ? 0.25 : 0.55),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: session == null
                    ? _IdleTimer(
                        onStart: () => _showStartSheet(context, ref))
                    : _RunningTimer(
                        session: session,
                        onStop: () => _stop(context, ref, session),
                      ),
              ),
            ],
          ),
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

/// Uppercase letter-spaced label row at the top of the hero card.
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
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: tokens.heroMutedInk,
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
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroLabel(text: l10n.workTimer),
        Text(
          '0:00:00',
          style: TextStyle(
            fontFamily: displayFontFamily,
            fontSize: 44,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.5,
            color: tokens.heroInk.withValues(alpha: 0.35),
            fontFeatures: tabularFigures,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(l10n.startTimer),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                fontFamily: bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    final tokens = context.tokens;
    ref.watch(timerTickProvider);
    final elapsed =
        elapsedMs(startedAtMs: session.startedAt, nowMs: utcNowMs());
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    final workspace =
        workspaces.where((w) => w.id == session.workspaceId).firstOrNull;
    final contact =
        contacts.where((c) => c.id == session.contactId).firstOrNull;

    final contextParts = [
      if (session.description?.isNotEmpty == true) session.description!,
      if (contact != null) contact.name,
      if (session.description?.isNotEmpty != true && contact == null)
        workspace?.name ?? l10n.workTimer,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroLabel(text: l10n.timerRunning, leading: const PulsingDot(size: 8)),
        const SizedBox(height: 10),
        Text(
          formatElapsed(elapsed),
          style: TextStyle(
            fontFamily: displayFontFamily,
            fontSize: 52,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: -0.5,
            color: tokens.heroInk,
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
                style: const TextStyle(
                  fontFamily: bodyFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEADFCB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            icon: const Icon(Icons.stop_rounded, size: 22),
            label: Text(l10n.stopTimer),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(
                fontFamily: bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onStop,
          ),
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
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workspaceId,
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
            onChanged: (id) => setState(() => _workspaceId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _contactId,
            decoration: InputDecoration(labelText: l10n.contactLabel),
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
