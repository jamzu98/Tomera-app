import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Android implementation over flutter_local_notifications: exact alarms
/// where permitted, gracefully falling back to inexact scheduling when the
/// user denies the exact-alarm permission (spec §6.3).
class LocalNotificationService implements NotificationService {
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
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

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
      scheduledDate:
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, fireAtMs),
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
  Future<void> cancel(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }
}
