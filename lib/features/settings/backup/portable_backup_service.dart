import 'package:shared_preferences/shared_preferences.dart';

import 'backup_archive.dart';
import 'backup_database_validator_api.dart';
import 'backup_platform.dart';

const _maximumBackupBytes = 128 * 1024 * 1024;

enum BackupOperationStatus {
  success,
  cancelled,
  unsupported,
  authenticationFailed,
  invalidArchive,
  unsupportedVersion,
  newerSchema,
  corrupted,
  failed,
}

class BackupOperationResult {
  const BackupOperationResult(this.status, {this.manifest});

  final BackupOperationStatus status;
  final BackupManifest? manifest;

  bool get isSuccess => status == BackupOperationStatus.success;
}

class BackupAppMetadata {
  const BackupAppMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

abstract interface class BackupPreferencesStore {
  Future<Map<String, Object?>> readTomeraPreferences();

  Future<void> replaceTomeraPreferences(Map<String, Object?> preferences);
}

class SharedPreferencesBackupStore implements BackupPreferencesStore {
  const SharedPreferencesBackupStore();

  static bool _isTomeraKey(String key) =>
      key.startsWith('settings.') || key.startsWith('onboarding.');

  @override
  Future<Map<String, Object?>> readTomeraPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      for (final key in prefs.getKeys().where(_isTomeraKey))
        key: _copyPreferenceValue(prefs.get(key)),
    };
  }

  @override
  Future<void> replaceTomeraPreferences(
    Map<String, Object?> preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    for (final key in prefs.getKeys().where(_isTomeraKey)) {
      await prefs.remove(key);
    }
    for (final entry in preferences.entries) {
      if (!_isTomeraKey(entry.key)) continue;
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List<Object?> &&
          value.every((item) => item is String)) {
        await prefs.setStringList(entry.key, value.cast<String>());
      } else if (value != null) {
        throw StateError('Unsupported preference value for ${entry.key}.');
      }
    }
  }
}

Object? _copyPreferenceValue(Object? value) => switch (value) {
  List<String>() => List<String>.of(value),
  _ => value,
};

typedef BackupSnapshot = Future<void> Function(String destinationPath);
typedef BackupDatabaseClose = Future<void> Function();
typedef BackupDatabaseReopen = Future<void> Function();
typedef BackupDatabaseValidator =
    Future<void> Function(String path, int currentSchemaVersion);
typedef BackupMetadataLoader = Future<BackupAppMetadata> Function();

class PortableBackupService {
  PortableBackupService({
    required this.platform,
    required this.preferences,
    required this.codec,
    required this.currentSchemaVersion,
    required this.snapshotDatabase,
    required this.closeDatabase,
    required this.reopenDatabase,
    required this.validateDatabase,
    required this.loadMetadata,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final BackupPlatform platform;
  final BackupPreferencesStore preferences;
  final BackupArchiveCodec codec;
  final int currentSchemaVersion;
  final BackupSnapshot snapshotDatabase;
  final BackupDatabaseClose closeDatabase;
  final BackupDatabaseReopen reopenDatabase;
  final BackupDatabaseValidator validateDatabase;
  final BackupMetadataLoader loadMetadata;
  final DateTime Function() _now;

  Future<BackupOperationResult> export(String password) async {
    if (!platform.isSupported) {
      return const BackupOperationResult(BackupOperationStatus.unsupported);
    }
    String? workingDirectory;
    try {
      workingDirectory = await platform.createWorkingDirectory();
      final snapshotPath = '$workingDirectory/database.sqlite';
      await platform.deleteFile(snapshotPath);
      await snapshotDatabase(snapshotPath);
      final databaseBytes = await platform.readFile(snapshotPath);
      final storedPreferences = await preferences.readTomeraPreferences();
      final metadata = await loadMetadata();
      final createdAt = _now().toUtc();
      final encrypted = await codec.encode(
        databaseBytes: databaseBytes,
        preferences: storedPreferences,
        schemaVersion: currentSchemaVersion,
        appVersion: metadata.version,
        appBuildNumber: metadata.buildNumber,
        createdAtUtc: createdAt,
        password: password,
      );
      final timestamp = createdAt
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final displayName = 'Tomera-$timestamp.$backupFileExtension';
      final archivePath = '$workingDirectory/$displayName';
      await platform.writeFile(archivePath, encrypted);
      await platform.shareBackupFile(archivePath, displayName);
      return const BackupOperationResult(BackupOperationStatus.success);
    } on BackupArchiveException catch (error) {
      return BackupOperationResult(_archiveStatus(error.error));
    } on Object {
      return const BackupOperationResult(BackupOperationStatus.failed);
    } finally {
      if (workingDirectory != null) {
        try {
          await platform.deleteWorkingDirectory(workingDirectory);
        } on Object {
          // Temporary-file cleanup must not replace the operation result.
        }
      }
    }
  }

  Future<BackupOperationResult> restore({
    required String password,
    String? archivePath,
  }) async {
    if (!platform.isSupported) {
      return const BackupOperationResult(BackupOperationStatus.unsupported);
    }
    String? workingDirectory;
    String? pickedArchivePath;
    var closeAttempted = false;
    var databaseClosed = false;
    Map<String, Object?>? previousPreferences;
    String? rollbackPath;
    try {
      final selectedPath = archivePath ?? await platform.pickBackupFile();
      if (selectedPath == null) {
        return const BackupOperationResult(BackupOperationStatus.cancelled);
      }
      if (archivePath == null) pickedArchivePath = selectedPath;
      final encrypted = await platform.readFile(selectedPath);
      if (encrypted.isEmpty || encrypted.length > _maximumBackupBytes) {
        return const BackupOperationResult(
          BackupOperationStatus.invalidArchive,
        );
      }
      final contents = await codec.decode(
        encryptedBytes: encrypted,
        password: password,
      );
      if (contents.manifest.schemaVersion > currentSchemaVersion) {
        return const BackupOperationResult(BackupOperationStatus.newerSchema);
      }

      workingDirectory = await platform.createWorkingDirectory();
      final stagedPath = '$workingDirectory/restored.sqlite';
      await platform.writeFile(stagedPath, contents.databaseBytes);
      await validateDatabase(stagedPath, currentSchemaVersion);

      // The rollback is also a SQLite-owned snapshot, never a copy of the live
      // file. It captures every committed row before any replacement begins.
      rollbackPath = '$workingDirectory/rollback.sqlite';
      await platform.deleteFile(rollbackPath);
      await snapshotDatabase(rollbackPath);
      previousPreferences = await preferences.readTomeraPreferences();

      closeAttempted = true;
      await closeDatabase();
      databaseClosed = true;
      await platform.replaceDatabase(stagedPath);
      await preferences.replaceTomeraPreferences(contents.preferences);
      await reopenDatabase();
      databaseClosed = false;
      return BackupOperationResult(
        BackupOperationStatus.success,
        manifest: contents.manifest,
      );
    } on BackupArchiveException catch (error) {
      return BackupOperationResult(_archiveStatus(error.error));
    } on BackupDatabaseValidationException catch (error) {
      return BackupOperationResult(switch (error.error) {
        BackupDatabaseValidationError.newerSchema =>
          BackupOperationStatus.newerSchema,
        BackupDatabaseValidationError.integrityCheckFailed ||
        BackupDatabaseValidationError.foreignKeyCheckFailed =>
          BackupOperationStatus.corrupted,
        BackupDatabaseValidationError.invalidDatabase =>
          BackupOperationStatus.invalidArchive,
      });
    } on Object {
      if (closeAttempted) {
        // The native rename may have succeeded even if its durability fsync
        // reported an error. Reinstalling the consistent rollback snapshot is
        // safe whether or not the staged database reached the live path.
        if (databaseClosed && rollbackPath != null) {
          try {
            await platform.replaceDatabase(rollbackPath);
          } on Object {
            // Reopening below still gives Drift a chance to surface the fatal
            // storage error rather than leaving every provider closed.
          }
        }
        if (databaseClosed && previousPreferences != null) {
          try {
            await preferences.replaceTomeraPreferences(previousPreferences);
          } on Object {
            // Best-effort preference rollback; the database is authoritative.
          }
        }
        await reopenDatabase();
      }
      return const BackupOperationResult(BackupOperationStatus.failed);
    } finally {
      if (workingDirectory != null) {
        try {
          await platform.deleteWorkingDirectory(workingDirectory);
        } on Object {
          // Temporary-file cleanup must not replace the operation result.
        }
      }
      if (pickedArchivePath != null) {
        try {
          await platform.deleteFile(pickedArchivePath);
        } on Object {
          // The picker copy lives in cache and is safe to clean up later.
        }
      }
    }
  }
}

BackupOperationStatus _archiveStatus(BackupArchiveError error) =>
    switch (error) {
      BackupArchiveError.authenticationFailed =>
        BackupOperationStatus.authenticationFailed,
      BackupArchiveError.invalidFormat => BackupOperationStatus.invalidArchive,
      BackupArchiveError.unsupportedVersion =>
        BackupOperationStatus.unsupportedVersion,
      BackupArchiveError.corrupted => BackupOperationStatus.corrupted,
    };
