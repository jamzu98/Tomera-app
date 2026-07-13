import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';
import 'backup/portable_backup_provider.dart';
import 'backup/portable_backup_service.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeSettingProvider);
    final rounding = ref.watch(roundingMinutesSettingProvider);
    final weekStart = ref.watch(weekStartSettingProvider);
    final timeFormat = ref.watch(timeFormatSettingProvider);

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
          SectionHeader(title: l10n.weekStartLabel),
          _SettingsCard(
            child: RadioGroup<WeekStart>(
              groupValue: weekStart,
              onChanged: (value) {
                if (value != null) {
                  ref.read(weekStartSettingProvider.notifier).set(value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<WeekStart>(
                    title: Text(l10n.weekStartMonday),
                    value: WeekStart.monday,
                  ),
                  RadioListTile<WeekStart>(
                    title: Text(l10n.weekStartSunday),
                    value: WeekStart.sunday,
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l10n.timeFormatLabel),
          _SettingsCard(
            child: RadioGroup<TimeFormat>(
              groupValue: timeFormat,
              onChanged: (value) {
                if (value != null) {
                  ref.read(timeFormatSettingProvider.notifier).set(value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<TimeFormat>(
                    title: Text(l10n.timeFormatSystem),
                    value: TimeFormat.system,
                  ),
                  RadioListTile<TimeFormat>(
                    title: Text(l10n.timeFormat12),
                    value: TimeFormat.hour12,
                  ),
                  RadioListTile<TimeFormat>(
                    title: Text(l10n.timeFormat24),
                    value: TimeFormat.hour24,
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
                      title: Text(
                        minutes == 0
                            ? l10n.roundingNone
                            : l10n.roundingOption(minutes),
                      ),
                      value: minutes,
                    ),
                ],
              ),
            ),
          ),
          SectionHeader(title: l10n.dataSafetyTitle),
          const _BackupSettingsCard(),
        ],
      ),
    );
  }
}

class _BackupSettingsCard extends ConsumerStatefulWidget {
  const _BackupSettingsCard();

  @override
  ConsumerState<_BackupSettingsCard> createState() =>
      _BackupSettingsCardState();
}

class _BackupSettingsCardState extends ConsumerState<_BackupSettingsCard> {
  var _working = false;

  Future<void> _export() async {
    final service = ref.read(portableBackupServiceProvider);
    if (!service.platform.isSupported) {
      _showResult(
        const BackupOperationResult(BackupOperationStatus.unsupported),
      );
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _BackupPasswordDialog(confirm: true),
    );
    if (password == null || !mounted) return;
    setState(() => _working = true);
    final result = await service.export(password);
    if (!mounted) return;
    setState(() => _working = false);
    _showResult(result);
  }

  Future<void> _restore() async {
    final service = ref.read(portableBackupServiceProvider);
    if (!service.platform.isSupported) {
      _showResult(
        const BackupOperationResult(BackupOperationStatus.unsupported),
      );
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _BackupPasswordDialog(confirm: false),
    );
    if (password == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreBackupConfirmTitle),
        content: Text(l10n.restoreBackupConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreBackupConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    final result = await service.restore(password: password);
    if (!mounted) return;
    setState(() => _working = false);
    _showResult(result);
  }

  void _showResult(BackupOperationResult result) {
    if (result.status == BackupOperationStatus.cancelled) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (result.status) {
      BackupOperationStatus.success =>
        result.manifest == null ? l10n.backupExported : l10n.backupRestored,
      BackupOperationStatus.unsupported => l10n.backupUnsupported,
      BackupOperationStatus.authenticationFailed =>
        l10n.backupAuthenticationFailed,
      BackupOperationStatus.invalidArchive => l10n.backupInvalidArchive,
      BackupOperationStatus.unsupportedVersion => l10n.backupUnsupportedVersion,
      BackupOperationStatus.newerSchema => l10n.backupNewerSchema,
      BackupOperationStatus.corrupted => l10n.backupCorrupted,
      BackupOperationStatus.failed => l10n.backupFailed,
      BackupOperationStatus.cancelled => '',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsCard(
      child: Column(
        children: [
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(l10n.exportBackupTitle),
            subtitle: Text(l10n.exportBackupSubtitle),
            trailing: const Icon(Icons.ios_share_rounded),
            enabled: !_working,
            onTap: _working ? null : _export,
          ),
          const Divider(height: 1),
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: Text(l10n.restoreBackupTitle),
            subtitle: Text(l10n.restoreBackupSubtitle),
            trailing: const Icon(Icons.folder_open_rounded),
            enabled: !_working,
            onTap: _working ? null : _restore,
          ),
          if (_working) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (_password.text.length < 8) {
      setState(() => _error = l10n.backupPasswordTooShort);
      return;
    }
    if (widget.confirm && _password.text != _confirmation.text) {
      setState(() => _error = l10n.backupPasswordsDoNotMatch);
      return;
    }
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.backupPasswordTitle),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: widget.confirm
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: widget.confirm ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.backupPasswordLabel,
                errorText: _error,
              ),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.backupPasswordConfirmLabel,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.confirm ? l10n.backupExportAction : l10n.continueAction,
          ),
        ),
      ],
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
