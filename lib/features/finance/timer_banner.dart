import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils.dart';
import '../../l10n/app_localizations.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

/// Slim running-timer indicator above the navigation bar, visible on every
/// tab. Tapping it opens the Finance tab where the timer can be stopped.
class TimerBanner extends ConsumerWidget {
  const TimerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runningTimerProvider).value;
    if (session == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    ref.watch(timerTickProvider);
    final elapsed =
        elapsedMs(startedAtMs: session.startedAt, nowMs: utcNowMs());

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.go('/finance'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.timer,
                  size: 16, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.description?.isNotEmpty == true
                      ? session.description!
                      : l10n.timerRunning,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                formatElapsed(elapsed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
