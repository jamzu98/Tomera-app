import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../l10n/app_localizations.dart';
import 'finance_providers.dart';
import 'timer_math.dart';

/// Slim floating running-timer banner riding above the navigation bar,
/// visible on every tab. Tapping it opens the Finance tab where the timer
/// can be stopped.
class TimerBanner extends ConsumerWidget {
  const TimerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(runningTimerProvider).value;
    if (session == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    ref.watch(timerTickProvider);
    final elapsed =
        elapsedMs(startedAtMs: session.startedAt, nowMs: utcNowMs());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: tokens.heroBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.heroInk.withValues(alpha: 0.06)),
        ),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/finance'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const PulsingDot(),
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
                      fontWeight: FontWeight.w600,
                      color: tokens.heroInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatElapsed(elapsed),
                  style: TextStyle(
                    fontFamily: bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: tokens.heroInk,
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
