import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_providers.g.dart';

const _themeModeKey = 'settings.themeMode';
const _roundingKey = 'settings.roundingMinutes';

/// Allowed duration rounding steps in minutes; 0 = no rounding (spec §6.6).
const roundingOptions = [0, 5, 15, 30];

/// Theme mode, persisted in shared preferences. Starts at the default and
/// updates once the stored value loads — a brief flash of the default theme
/// on cold start is acceptable.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_themeModeKey);
    final stored =
        ThemeMode.values.where((m) => m.name == name).firstOrNull;
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_roundingKey);
    if (stored != null && roundingOptions.contains(stored)) state = stored;
  }

  Future<void> set(int minutes) async {
    assert(roundingOptions.contains(minutes));
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_roundingKey, minutes);
  }
}
