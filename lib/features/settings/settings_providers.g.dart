// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Theme mode, persisted in shared preferences. Starts at the default and
/// updates once the stored value loads — a brief flash of the default theme
/// on cold start is acceptable.

@ProviderFor(ThemeModeSetting)
final themeModeSettingProvider = ThemeModeSettingProvider._();

/// Theme mode, persisted in shared preferences. Starts at the default and
/// updates once the stored value loads — a brief flash of the default theme
/// on cold start is acceptable.
final class ThemeModeSettingProvider
    extends $NotifierProvider<ThemeModeSetting, ThemeMode> {
  /// Theme mode, persisted in shared preferences. Starts at the default and
  /// updates once the stored value loads — a brief flash of the default theme
  /// on cold start is acceptable.
  ThemeModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeSettingHash() => r'8277bc50cb1c61811e11750d9abcf8874dabb92b';

/// Theme mode, persisted in shared preferences. Starts at the default and
/// updates once the stored value loads — a brief flash of the default theme
/// on cold start is acceptable.

abstract class _$ThemeModeSetting extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Work-timer duration rounding in minutes, round up; 0 disables rounding.

@ProviderFor(RoundingMinutesSetting)
final roundingMinutesSettingProvider = RoundingMinutesSettingProvider._();

/// Work-timer duration rounding in minutes, round up; 0 disables rounding.
final class RoundingMinutesSettingProvider
    extends $NotifierProvider<RoundingMinutesSetting, int> {
  /// Work-timer duration rounding in minutes, round up; 0 disables rounding.
  RoundingMinutesSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roundingMinutesSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roundingMinutesSettingHash();

  @$internal
  @override
  RoundingMinutesSetting create() => RoundingMinutesSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$roundingMinutesSettingHash() =>
    r'20e1f9cad369fa89fbc1ca3d270f8c8383b9fa97';

/// Work-timer duration rounding in minutes, round up; 0 disables rounding.

abstract class _$RoundingMinutesSetting extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// First day displayed by week-based calendar surfaces.

@ProviderFor(WeekStartSetting)
final weekStartSettingProvider = WeekStartSettingProvider._();

/// First day displayed by week-based calendar surfaces.
final class WeekStartSettingProvider
    extends $NotifierProvider<WeekStartSetting, WeekStart> {
  /// First day displayed by week-based calendar surfaces.
  WeekStartSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekStartSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekStartSettingHash();

  @$internal
  @override
  WeekStartSetting create() => WeekStartSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekStart value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekStart>(value),
    );
  }
}

String _$weekStartSettingHash() => r'655810623d0ff97a2d097286d20f2b5b5d3fbc49';

/// First day displayed by week-based calendar surfaces.

abstract class _$WeekStartSetting extends $Notifier<WeekStart> {
  WeekStart build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WeekStart, WeekStart>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WeekStart, WeekStart>,
              WeekStart,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Clock format used by date/time labels and editors.

@ProviderFor(TimeFormatSetting)
final timeFormatSettingProvider = TimeFormatSettingProvider._();

/// Clock format used by date/time labels and editors.
final class TimeFormatSettingProvider
    extends $NotifierProvider<TimeFormatSetting, TimeFormat> {
  /// Clock format used by date/time labels and editors.
  TimeFormatSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeFormatSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeFormatSettingHash();

  @$internal
  @override
  TimeFormatSetting create() => TimeFormatSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeFormat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeFormat>(value),
    );
  }
}

String _$timeFormatSettingHash() => r'8a94f42fc7593b588f1d6306144b004c42b53d61';

/// Clock format used by date/time labels and editors.

abstract class _$TimeFormatSetting extends $Notifier<TimeFormat> {
  TimeFormat build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TimeFormat, TimeFormat>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimeFormat, TimeFormat>,
              TimeFormat,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
