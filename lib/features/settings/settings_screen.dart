import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/section_header.dart';
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader(title: l10n.themeLabel),
          _SettingsCard(
            child: RadioGroup<ThemeMode>(
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
          ),
          SectionHeader(title: l10n.roundingLabel),
          _SettingsCard(
            child: RadioGroup<int>(
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
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Material (not a decorated Container) so ListTile ink renders on it.
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: child,
        ),
      ),
    );
  }
}
