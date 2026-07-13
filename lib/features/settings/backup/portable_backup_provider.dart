import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers.dart';
import '../../onboarding/onboarding_providers.dart';
import '../settings_providers.dart';
import 'backup_archive.dart';
import 'backup_database_validator.dart';
import 'backup_platform.dart';
import 'portable_backup_service.dart';

final portableBackupServiceProvider = Provider<PortableBackupService>((ref) {
  final lifecycle = ref.watch(databaseLifecycleProvider);
  final platform = createBackupPlatform();
  return PortableBackupService(
    platform: platform,
    preferences: const SharedPreferencesBackupStore(),
    codec: BackupArchiveCodec(),
    currentSchemaVersion: ref.read(appDatabaseProvider).schemaVersion,
    snapshotDatabase: (path) =>
        ref.read(appDatabaseProvider).createSnapshot(path),
    closeDatabase: lifecycle.closeForReplacement,
    reopenDatabase: () async {
      lifecycle.reopen();
      ref.read(databaseRestoreEpochProvider.notifier).bump();
      ref.read(selectedWorkspaceIdProvider.notifier).select(null);
      ref.invalidate(themeModeSettingProvider);
      ref.invalidate(roundingMinutesSettingProvider);
      ref.invalidate(weekStartSettingProvider);
      ref.invalidate(timeFormatSettingProvider);
      ref.invalidate(onboardingProvider);
      try {
        await ref.read(eventRepositoryProvider).refreshRecurrenceHorizon();
        await ref.read(reminderCoordinatorProvider).reconcileFromDatabase();
      } on Object {
        // Restored data is durable even if the OS notification service is
        // temporarily unavailable; the next restore/startup can reconcile it.
      }
    },
    validateDatabase: (path, schemaVersion) => validateAndMigrateBackupDatabase(
      path,
      currentSchemaVersion: schemaVersion,
    ),
    loadMetadata: () async {
      final info = await PackageInfo.fromPlatform();
      return BackupAppMetadata(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    },
  );
});
