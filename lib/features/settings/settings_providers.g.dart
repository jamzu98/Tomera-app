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
    r'ee66580810451946d440fcff0001f92151e820c0';

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
