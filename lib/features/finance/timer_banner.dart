import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../l10n/app_localizations.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

/// Slim running-timer banner above the navigation bar,
/// visible on every tab. Tapping it opens the Finance tab where the timer
/// can be stopped.
class TimerBanner extends ConsumerWidget {
  const TimerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runningTimerProvider).value;
    if (session == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    ref.watch(timerTickProvider);
    final elapsed = elapsedMs(
      startedAtMs: session.startedAt,
      nowMs: utcNowMs(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/finance'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                PulsingDot(color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.description?.isNotEmpty == true
                        ? session.description!
                        : l10n.timerRunning,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: bodyFontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatElapsed(elapsed),
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
