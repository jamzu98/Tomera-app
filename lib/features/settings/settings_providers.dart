import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_providers.g.dart';

const _themeModeKey = 'settings.themeMode';
const _roundingKey = 'settings.roundingMinutes';
const _weekStartKey = 'settings.weekStart';
const _timeFormatKey = 'settings.timeFormat';

/// Allowed duration rounding steps in minutes; 0 = no rounding (spec §6.6).
const roundingOptions = [0, 5, 15, 30];

/// Supported calendar week starts. Syncfusion uses 1 for Monday and 7 for
/// Sunday, exposed here so calendar consumers don't duplicate that mapping.
enum WeekStart {
  monday(1),
  sunday(7);

  const WeekStart(this.calendarDay);

  final int calendarDay;
}

/// User override for clock formatting. [system] follows the platform's
/// `alwaysUse24HourFormat` value supplied by the calling widget.
enum TimeFormat {
  system,
  hour12,
  hour24;

  bool resolveUses24Hour({required bool systemUses24Hour}) => switch (this) {
    TimeFormat.system => systemUses24Hour,
    TimeFormat.hour12 => false,
    TimeFormat.hour24 => true,
  };
}

/// Theme mode, persisted in shared preferences. Starts at the default and
/// updates once the stored value loads — a brief flash of the default theme
/// on cold start is acceptable.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeModeKey);
    final stored = ThemeMode.values.where((m) => m.name == name).firstOrNull;
    if (stored != null) state = stored;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}

/// Work-timer duration rounding in minutes, round up; 0 disables rounding.
@Riverpod(keepAlive: true)
class RoundingMinutesSetting extends _$RoundingMinutesSetting {
  @override
  int build() {
    _load();
    return 0;
  }

  /// The stored value, awaited. Use this where the answer must be correct
  /// even if the provider was created a moment ago (e.g. stopping the timer
  /// right after a cold start) — [build] returns the default until the
  /// async load lands.
  static Future<int> loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_roundingKey);
    return (stored != null && roundingOptions.contains(stored)) ? stored : 0;
  }

  Future<void> _load() async {
    state = await loadStored();
  }

  Future<void> set(int minutes) async {
    assert(roundingOptions.contains(minutes));
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_roundingKey, minutes);
  }
}

/// First day displayed by week-based calendar surfaces.
@Riverpod(keepAlive: true)
class WeekStartSetting extends _$WeekStartSetting {
  var _revision = 0;

  @override
  WeekStart build() {
    _load();
    return WeekStart.monday;
  }

  static Future<WeekStart> loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_weekStartKey);
    return WeekStart.values.where((value) => value.name == name).firstOrNull ??
        WeekStart.monday;
  }

  Future<void> _load() async {
    final revision = _revision;
    final stored = await loadStored();
    if (revision == _revision) state = stored;
  }

  Future<void> set(WeekStart value) async {
    _revision++;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weekStartKey, value.name);
  }
}

/// Clock format used by date/time labels and editors.
@Riverpod(keepAlive: true)
class TimeFormatSetting extends _$TimeFormatSetting {
  var _revision = 0;

  @override
  TimeFormat build() {
    _load();
    return TimeFormat.system;
  }

  static Future<TimeFormat> loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_timeFormatKey);
    return TimeFormat.values.where((value) => value.name == name).firstOrNull ??
        TimeFormat.system;
  }

  Future<void> _load() async {
    final revision = _revision;
    final stored = await loadStored();
    if (revision == _revision) state = stored;
  }

  Future<void> set(TimeFormat value) async {
    _revision++;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeFormatKey, value.name);
  }
}
