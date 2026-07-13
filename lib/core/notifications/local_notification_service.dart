import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Android implementation over flutter_local_notifications: exact alarms
/// where permitted, gracefully falling back to inexact scheduling when the
/// user denies the exact-alarm permission (spec §6.3).
class LocalNotificationService implements NotificationService {
  LocalNotificationService({this.onAction});

  static const stopTimerAction = 'stop_timer';

  /// Invoked with the notification action id when the user taps an action
  /// while the app is alive. After process death the tap merely opens the
  /// app — correctness never depends on this callback (spec §6.6).
  final void Function(String actionId)? onAction;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  Future<void> _ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // Keep the package default (UTC) if the platform lookup fails; the
      // fire instant is absolute either way.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId;
        if (actionId != null) onAction?.call(actionId);
      },
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required int fireAtMs,
  }) async {
    if (fireAtMs <= DateTime.now().millisecondsSinceEpoch) return;
    await _ensureInitialized();

    final android = _android;
    await android?.requestNotificationsPermission();
    var exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    if (!exactAllowed) {
      await android?.requestExactAlarmsPermission();
      exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local,
        fireAtMs,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'Task and event reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> showOngoingTimer({
    required int id,
    required String title,
    required int startedAtMs,
  }) async {
    await _ensureInitialized();
    await _android?.requestNotificationsPermission();
    await _plugin.show(
      id: id,
      title: title,
      body: null,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'timer',
          'Work timer',
          channelDescription: 'Running work timer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          usesChronometer: true,
          showWhen: true,
          when: startedAtMs,
          actions: const [AndroidNotificationAction(stopTimerAction, 'Stop')],
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
