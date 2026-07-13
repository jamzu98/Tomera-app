import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_platform_api.dart';

const _channel = MethodChannel('fi.makkonen.tomera/portable_backup');

BackupPlatform createBackupPlatform() => const IoBackupPlatform();

class IoBackupPlatform implements BackupPlatform {
  const IoBackupPlatform();

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<String> createWorkingDirectory() async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}/tomera_backup_${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    return directory.path;
  }

  @override
  Future<void> deleteWorkingDirectory(String path) async {
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<Uint8List> readFile(String path) => File(path).readAsBytes();

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String?> pickBackupFile() =>
      _channel.invokeMethod<String>('pickBackupFile');

  @override
  Future<void> shareBackupFile(String path, String displayName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/octet-stream')],
        fileNameOverrides: [displayName],
        subject: 'Tomera backup',
      ),
    );
  }

  @override
  Future<String> databasePath() async {
    final path = await _channel.invokeMethod<String>('databasePath');
    if (path == null || path.isEmpty) {
      throw StateError('Android did not return the Tomera database path.');
    }
    return path;
  }

  @override
  Future<void> replaceDatabase(String stagedDatabasePath) =>
      _channel.invokeMethod<void>('replaceDatabase', {
        'stagedPath': stagedDatabasePath,
      });
}
