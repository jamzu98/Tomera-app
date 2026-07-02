/// Pure work-timer math (spec §6.6/§8). Elapsed time is always computed
/// from the persisted `started_at` — never from a running isolate — so the
/// timer survives process death.
library;

int elapsedMs({required int startedAtMs, required int nowMs}) =>
    nowMs > startedAtMs ? nowMs - startedAtMs : 0;

/// Billable duration for an elapsed span: rounded up to whole minutes
/// (minimum 1), then up to the next multiple of [roundingMinutes]
/// (0 = no step rounding). Spec: "none / 5 / 15 / 30 min, round up".
int roundedDurationMinutes(int elapsedMs, int roundingMinutes) {
  var minutes = (elapsedMs + 59999) ~/ 60000;
  if (minutes < 1) minutes = 1;
  if (roundingMinutes <= 0) return minutes;
  return ((minutes + roundingMinutes - 1) ~/ roundingMinutes) *
      roundingMinutes;
}

/// "H:MM:SS" display for a running timer.
String formatElapsed(int elapsedMs) {
  final totalSeconds = elapsedMs ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String pad(int n) => n.toString().padLeft(2, '0');
  return '$hours:${pad(minutes)}:${pad(seconds)}';
}
