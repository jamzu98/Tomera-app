import 'package:flutter_timezone/flutter_timezone.dart';

/// Returns the platform's IANA timezone identifier. Tests and unsupported
/// platforms fall back to UTC, which remains a valid recurrence origin.
Future<String> localIanaTimezone() async {
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    return timezone.identifier;
  } on Object {
    return 'UTC';
  }
}
