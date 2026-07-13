/// Platform-agnostic notification scheduling (spec §6.3).
///
/// Implementations: [LocalNotificationService] wraps
/// flutter_local_notifications on Android; a no-op serves web (spec Phase 4:
/// no reminders on web) and tests.
abstract interface class NotificationService {
  /// Schedules (or replaces) a notification. Times in the past are ignored.
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required int fireAtMs,
  });

  /// Shows a persistent (ongoing) notification with a live chronometer
  /// counting from [startedAtMs] and a stop action (spec §6.6 work timer).
  Future<void> showOngoingTimer({
    required int id,
    required String title,
    required int startedAtMs,
  });

  Future<void> cancel(int id);

  /// Clears Tomera's scheduled reminders and ongoing timer before rebuilding
  /// platform state from a restored database.
  Future<void> cancelAll();
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required int fireAtMs,
  }) async {}

  @override
  Future<void> showOngoingTimer({
    required int id,
    required String title,
    required int startedAtMs,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Deterministic 31-bit notification id from an entity key (FNV-1a). Stable
/// across launches and platforms so a reminder can be cancelled without
/// storing the id. Kept positive to fit Android's int32 notification ids.
int notificationIdFor(String key) {
  var hash = 0x811C9DC5;
  for (final code in key.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
