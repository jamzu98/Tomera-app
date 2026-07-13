import 'dart:typed_data';

abstract interface class BackupPlatform {
  bool get isSupported;

  Future<String> createWorkingDirectory();

  Future<void> deleteWorkingDirectory(String path);

  Future<Uint8List> readFile(String path);

  Future<void> writeFile(String path, Uint8List bytes);

  Future<bool> fileExists(String path);

  Future<void> deleteFile(String path);

  Future<String?> pickBackupFile();

  Future<void> shareBackupFile(String path, String displayName);

  Future<String> databasePath();

  /// Atomically installs a closed, validated SQLite file over the live one.
  Future<void> replaceDatabase(String stagedDatabasePath);
}
