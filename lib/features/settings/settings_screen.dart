import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeSettingProvider);
    final rounding = ref.watch(roundingMinutesSettingProvider);

    String themeLabel(ThemeMode mode) => switch (mode) {
          ThemeMode.system => l10n.themeSystem,
          ThemeMode.light => l10n.themeLight,
          ThemeMode.dark => l10n.themeDark,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.themeLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeSettingProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    title: Text(themeLabel(mode)),
                    value: mode,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              l10n.roundingLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          RadioGroup<int>(
            groupValue: rounding,
            onChanged: (value) {
              if (value != null) {
                ref.read(roundingMinutesSettingProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                for (final minutes in roundingOptions)
                  RadioListTile<int>(
                    title: Text(minutes == 0
                        ? l10n.roundingNone
                        : l10n.roundingOption(minutes)),
                    value: minutes,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
