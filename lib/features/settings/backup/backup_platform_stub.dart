import 'dart:typed_data';

import 'backup_platform_api.dart';

BackupPlatform createBackupPlatform() => const UnsupportedBackupPlatform();

class UnsupportedBackupPlatform implements BackupPlatform {
  const UnsupportedBackupPlatform();

  @override
  bool get isSupported => false;

  Never _unsupported() =>
      throw UnsupportedError('Portable backups are only available on Android.');

  @override
  Future<String> createWorkingDirectory() async => _unsupported();

  @override
  Future<String> databasePath() async => _unsupported();

  @override
  Future<void> deleteFile(String path) async => _unsupported();

  @override
  Future<void> deleteWorkingDirectory(String path) async => _unsupported();

  @override
  Future<bool> fileExists(String path) async => _unsupported();

  @override
  Future<String?> pickBackupFile() async => _unsupported();

  @override
  Future<Uint8List> readFile(String path) async => _unsupported();

  @override
  Future<void> replaceDatabase(String stagedDatabasePath) async =>
      _unsupported();

  @override
  Future<void> shareBackupFile(String path, String displayName) async =>
      _unsupported();

  @override
  Future<void> writeFile(String path, Uint8List bytes) async => _unsupported();
}
