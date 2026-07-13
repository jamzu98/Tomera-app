import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/soft_tile.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';
import 'timer_math.dart';

/// A durable list of stopped timer sessions which have not yet produced a
/// billable. Conversion uses the timer-session provenance API, so retries and
/// simultaneous calls converge on the same billable row.
class RecoverableTimerList extends ConsumerWidget {
  const RecoverableTimerList({
    super.key,
    required this.sessions,
    this.maxItems,
  });

  final List<TimerSession> sessions;
  final int? maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = maxItems == null
        ? sessions
        : sessions.take(maxItems!).toList(growable: false);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final projects = ref.watch(allProjectsForLookupProvider).value ?? [];

    return Column(
      children: [
        for (final session in visible)
          _RecoverableTimerTile(
            key: ValueKey('recoverable-timer-${session.id}'),
            session: session,
            contextLabel: _contextLabel(session, workspaces, projects),
          ),
      ],
    );
  }

  String _contextLabel(
    TimerSession session,
    List<Workspace> workspaces,
    List<Project> projects,
  ) {
    final workspace = workspaces
        .where((item) => item.id == session.workspaceId)
        .firstOrNull;
    final project = projects
        .where((item) => item.id == session.projectId)
        .firstOrNull;
    final duration = formatElapsed(
      (session.stoppedAt! - session.startedAt).clamp(0, 1 << 62),
    );
    return [
      if (workspace != null) workspace.name,
      if (project != null) project.name,
      duration,
    ].join(' · ');
  }
}

class _RecoverableTimerTile extends ConsumerWidget {
  const _RecoverableTimerTile({
    super.key,
    required this.session,
    required this.contextLabel,
  });

  final TimerSession session;
  final String contextLabel;

  Future<bool> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(timerRepositoryProvider);
    try {
      final removed = await repository.deleteUnconverted(session.id);
      if (!context.mounted) return removed;
      if (!removed) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.timerRemovalFailed)));
        return false;
      }
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
      return true;
    } catch (_) {
      if (context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.timerRemovalFailed)));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismissible-recoverable-timer-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _remove(context, ref),
      background: Semantics(
        label: l10n.removeUnconvertedTime,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
        ),
      ),
      child: SoftTile(
        margin: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.history_toggle_off_rounded),
        title: Text(
          session.description?.trim().isNotEmpty == true
              ? session.description!.trim()
              : l10n.workTimer,
        ),
        subtitle: Text(
          contextLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _ConvertTimerButton(session: session),
        onTap: () => context.push('/finance/timers/${session.id}'),
      ),
    );
  }
}

class _ConvertTimerButton extends ConsumerStatefulWidget {
  const _ConvertTimerButton({required this.session});

  final TimerSession session;

  @override
  ConsumerState<_ConvertTimerButton> createState() =>
      _ConvertTimerButtonState();
}

class _ConvertTimerButtonState extends ConsumerState<_ConvertTimerButton> {
  bool _converting = false;

  Future<void> _convert() async {
    if (_converting) return;
    setState(() => _converting = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final session = widget.session;
    try {
      final rounding = await RoundingMinutesSetting.loadStored();
      final elapsed = (session.stoppedAt! - session.startedAt).clamp(
        0,
        1 << 62,
      );
      await ref
          .read(billableRepositoryProvider)
          .createFromTimer(
            session: session,
            title: session.description?.trim().isNotEmpty == true
                ? session.description!.trim()
                : l10n.workTimer,
            durationMinutes: roundedDurationMinutes(elapsed, rounding),
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.timerConverted)));
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.timerConversionFailed)));
      setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.convertToBillable,
      child: FilledButton.tonal(
        onPressed: _converting ? null : _convert,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: _converting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.convertToBillable),
      ),
    );
  }
}
