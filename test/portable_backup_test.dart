import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/features/settings/backup/backup_archive.dart';
import 'package:tomera/features/settings/backup/backup_platform_api.dart';
import 'package:tomera/features/settings/backup/portable_backup_service.dart';

void main() {
  late BackupArchiveCodec codec;

  setUp(() {
    // Production uses 19 MiB / 2 passes. Small parameters keep focused unit
    // tests fast while exercising the identical Argon2id/AES-GCM code path.
    codec = BackupArchiveCodec(
      argonMemoryKiB: 64,
      argonIterations: 1,
      minimumAcceptedMemoryKiB: 64,
    );
  });

  test(
    'encrypted archive round-trips database, preferences, and manifest',
    () async {
      final encrypted = await codec.encode(
        databaseBytes: Uint8List.fromList([0x53, 0x51, 0x4c, 0x69, 0x74, 0x65]),
        preferences: {
          'settings.themeMode': 'dark',
          'settings.roundingMinutes': 15,
          'onboarding.checklistDismissed': true,
          'settings.testDouble': 1.5,
          'settings.testList': ['one', 'two'],
        },
        schemaVersion: 5,
        appVersion: '1.2.3',
        appBuildNumber: '42',
        createdAtUtc: DateTime.utc(2026, 7, 13, 9, 30),
        password: 'correct horse battery staple',
      );

      final restored = await codec.decode(
        encryptedBytes: encrypted,
        password: 'correct horse battery staple',
      );

      expect(restored.databaseBytes, [0x53, 0x51, 0x4c, 0x69, 0x74, 0x65]);
      expect(restored.preferences['settings.themeMode'], 'dark');
      expect(restored.preferences['settings.roundingMinutes'], 15);
      expect(restored.preferences['settings.testList'], ['one', 'two']);
      expect(restored.manifest.schemaVersion, 5);
      expect(restored.manifest.appVersion, '1.2.3');
      expect(restored.manifest.appBuildNumber, '42');
      expect(restored.manifest.createdAtUtc, DateTime.utc(2026, 7, 13, 9, 30));
    },
  );

  test('wrong password fails authentication before archive parsing', () async {
    final encrypted = await _archive(codec);

    await expectLater(
      codec.decode(encryptedBytes: encrypted, password: 'wrong password'),
      throwsA(
        isA<BackupArchiveException>().having(
          (error) => error.error,
          'error',
          BackupArchiveError.authenticationFailed,
        ),
      ),
    );
  });

  test('ciphertext corruption fails authenticated decryption', () async {
    final encrypted = await _archive(codec);
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final ciphertext = base64Decode(envelope['ciphertext'] as String);
    ciphertext[ciphertext.length ~/ 2] ^= 0x01;
    envelope['ciphertext'] = base64Encode(ciphertext);

    await expectLater(
      codec.decode(
        encryptedBytes: Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        password: 'correct password',
      ),
      throwsA(
        isA<BackupArchiveException>().having(
          (error) => error.error,
          'error',
          BackupArchiveError.authenticationFailed,
        ),
      ),
    );
  });

  test('restore reports an unsupported archive envelope version', () async {
    final platform = _MemoryBackupPlatform();
    final envelope =
        jsonDecode(utf8.decode(await _archive(codec))) as Map<String, dynamic>;
    envelope['formatVersion'] = backupFormatVersion + 1;
    platform.files['/import.tomera-backup'] = Uint8List.fromList(
      utf8.encode(jsonEncode(envelope)),
    );
    platform.pickResult = '/import.tomera-backup';
    var validationCalled = false;
    final service = _service(
      platform: platform,
      codec: codec,
      currentSchemaVersion: 7,
      validateDatabase: (path, version) async => validationCalled = true,
    );

    final result = await service.restore(password: 'correct password');

    expect(result.status, BackupOperationStatus.unsupportedVersion);
    expect(validationCalled, isFalse);
    expect(platform.replacePaths, isEmpty);
  });

  test('restore rejects an archive from a newer database schema', () async {
    final platform = _MemoryBackupPlatform();
    platform.files['/import.tomera-backup'] = await _archive(
      codec,
      schemaVersion: 8,
    );
    platform.pickResult = '/import.tomera-backup';
    var validationCalled = false;
    final service = _service(
      platform: platform,
      codec: codec,
      currentSchemaVersion: 7,
      validateDatabase: (path, version) async => validationCalled = true,
    );

    final result = await service.restore(password: 'correct password');

    expect(result.status, BackupOperationStatus.newerSchema);
    expect(validationCalled, isFalse);
    expect(platform.replacePaths, isEmpty);
  });

  test(
    'service export and restore is transactional across DB and preferences',
    () async {
      final platform = _MemoryBackupPlatform();
      final prefs = _MemoryPreferences({
        'settings.themeMode': 'dark',
        'onboarding.version': 1,
      });
      var liveDatabase = Uint8List.fromList([1, 2, 3, 4]);
      var closed = false;
      var reopenCount = 0;
      final service = PortableBackupService(
        platform: platform,
        preferences: prefs,
        codec: codec,
        currentSchemaVersion: 5,
        snapshotDatabase: (destination) =>
            platform.writeFile(destination, Uint8List.fromList(liveDatabase)),
        closeDatabase: () async => closed = true,
        reopenDatabase: () async {
          closed = false;
          reopenCount++;
        },
        validateDatabase: (path, version) async {},
        loadMetadata: () async =>
            const BackupAppMetadata(version: '1.0.0', buildNumber: '1'),
        now: () => DateTime.utc(2026, 7, 13),
      );

      expect((await service.export('correct password')).isSuccess, isTrue);
      final exported = platform.sharedBytes!;

      liveDatabase = Uint8List.fromList([9, 9, 9]);
      prefs.values = {'settings.themeMode': 'light'};
      platform.files['/import.tomera-backup'] = exported;
      platform.pickResult = '/import.tomera-backup';
      platform.onReplace = (path) async {
        expect(closed, isTrue);
        liveDatabase = Uint8List.fromList(platform.files[path]!);
      };

      final result = await service.restore(password: 'correct password');

      expect(result.isSuccess, isTrue);
      expect(liveDatabase, [1, 2, 3, 4]);
      expect(prefs.values['settings.themeMode'], 'dark');
      expect(prefs.values['onboarding.version'], 1);
      expect(closed, isFalse);
      expect(reopenCount, 1);
    },
  );

  test(
    'restore rolls database and preferences back after replacement failure',
    () async {
      final platform = _MemoryBackupPlatform();
      final prefs = _MemoryPreferences({'settings.themeMode': 'light'})
        ..replaceFailuresRemaining = 1;
      var liveDatabase = Uint8List.fromList([9, 9, 9]);
      var reopened = false;
      platform.files['/import.tomera-backup'] = await _archive(codec);
      platform.pickResult = '/import.tomera-backup';
      platform.onReplace = (path) async {
        liveDatabase = Uint8List.fromList(platform.files[path]!);
      };
      final service = PortableBackupService(
        platform: platform,
        preferences: prefs,
        codec: codec,
        currentSchemaVersion: 5,
        snapshotDatabase: (destination) =>
            platform.writeFile(destination, Uint8List.fromList(liveDatabase)),
        closeDatabase: () async {},
        reopenDatabase: () async => reopened = true,
        validateDatabase: (path, version) async {},
        loadMetadata: () async =>
            const BackupAppMetadata(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.restore(password: 'correct password');

      expect(result.status, BackupOperationStatus.failed);
      expect(liveDatabase, [9, 9, 9]);
      expect(prefs.values, {'settings.themeMode': 'light'});
      expect(platform.replacePaths, hasLength(2));
      expect(reopened, isTrue);
    },
  );

  test(
    'native post-rename error still reinstalls the rollback snapshot',
    () async {
      final platform = _MemoryBackupPlatform();
      final prefs = _MemoryPreferences({'settings.themeMode': 'light'});
      var liveDatabase = Uint8List.fromList([9, 9, 9]);
      var reopened = false;
      platform.files['/import.tomera-backup'] = await _archive(codec);
      platform.pickResult = '/import.tomera-backup';
      platform.onReplace = (path) async {
        liveDatabase = Uint8List.fromList(platform.files[path]!);
        if (platform.replacePaths.length == 1) {
          throw StateError('directory fsync failed after rename');
        }
      };
      final service = PortableBackupService(
        platform: platform,
        preferences: prefs,
        codec: codec,
        currentSchemaVersion: 5,
        snapshotDatabase: (destination) =>
            platform.writeFile(destination, Uint8List.fromList(liveDatabase)),
        closeDatabase: () async {},
        reopenDatabase: () async => reopened = true,
        validateDatabase: (path, version) async {},
        loadMetadata: () async =>
            const BackupAppMetadata(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.restore(password: 'correct password');

      expect(result.status, BackupOperationStatus.failed);
      expect(liveDatabase, [9, 9, 9]);
      expect(prefs.values, {'settings.themeMode': 'light'});
      expect(platform.replacePaths, hasLength(2));
      expect(reopened, isTrue);
    },
  );

  test(
    'close failure reopens providers without touching the live file',
    () async {
      final platform = _MemoryBackupPlatform();
      final prefs = _MemoryPreferences({'settings.themeMode': 'light'});
      var reopened = false;
      platform.files['/import.tomera-backup'] = await _archive(codec);
      platform.pickResult = '/import.tomera-backup';
      final service = PortableBackupService(
        platform: platform,
        preferences: prefs,
        codec: codec,
        currentSchemaVersion: 5,
        snapshotDatabase: (destination) =>
            platform.writeFile(destination, Uint8List.fromList([9, 9, 9])),
        closeDatabase: () async => throw StateError('close failed'),
        reopenDatabase: () async => reopened = true,
        validateDatabase: (path, version) async {},
        loadMetadata: () async =>
            const BackupAppMetadata(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.restore(password: 'correct password');

      expect(result.status, BackupOperationStatus.failed);
      expect(platform.replacePaths, isEmpty);
      expect(prefs.values, {'settings.themeMode': 'light'});
      expect(reopened, isTrue);
    },
  );
}

PortableBackupService _service({
  required _MemoryBackupPlatform platform,
  required BackupArchiveCodec codec,
  required int currentSchemaVersion,
  required BackupDatabaseValidator validateDatabase,
}) => PortableBackupService(
  platform: platform,
  preferences: _MemoryPreferences(const {'settings.themeMode': 'system'}),
  codec: codec,
  currentSchemaVersion: currentSchemaVersion,
  snapshotDatabase: (destination) =>
      platform.writeFile(destination, Uint8List.fromList([9, 9, 9])),
  closeDatabase: () async {},
  reopenDatabase: () async {},
  validateDatabase: validateDatabase,
  loadMetadata: () async =>
      const BackupAppMetadata(version: '1.0.0', buildNumber: '1'),
);

Future<Uint8List> _archive(BackupArchiveCodec codec, {int schemaVersion = 5}) =>
    codec.encode(
      databaseBytes: Uint8List.fromList([1, 2, 3]),
      preferences: const {'settings.themeMode': 'system'},
      schemaVersion: schemaVersion,
      appVersion: '1.0.0',
      appBuildNumber: '1',
      createdAtUtc: DateTime.utc(2026, 7, 13),
      password: 'correct password',
    );

class _MemoryPreferences implements BackupPreferencesStore {
  _MemoryPreferences(this.values);

  Map<String, Object?> values;
  var replaceFailuresRemaining = 0;

  @override
  Future<Map<String, Object?>> readTomeraPreferences() async =>
      Map<String, Object?>.of(values);

  @override
  Future<void> replaceTomeraPreferences(
    Map<String, Object?> preferences,
  ) async {
    if (replaceFailuresRemaining > 0) {
      replaceFailuresRemaining--;
      throw StateError('injected preference failure');
    }
    values = Map<String, Object?>.of(preferences);
  }
}

class _MemoryBackupPlatform implements BackupPlatform {
  final files = <String, Uint8List>{};
  var _directoryCounter = 0;
  String? pickResult;
  Uint8List? sharedBytes;
  Future<void> Function(String path)? onReplace;
  final replacePaths = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<String> createWorkingDirectory() async =>
      '/working-${_directoryCounter++}';

  @override
  Future<String> databasePath() async => '/live/tomera.sqlite';

  @override
  Future<void> deleteFile(String path) async => files.remove(path);

  @override
  Future<void> deleteWorkingDirectory(String path) async {
    files.removeWhere((key, value) => key.startsWith('$path/'));
  }

  @override
  Future<bool> fileExists(String path) async => files.containsKey(path);

  @override
  Future<String?> pickBackupFile() async => pickResult;

  @override
  Future<Uint8List> readFile(String path) async =>
      Uint8List.fromList(files[path]!);

  @override
  Future<void> replaceDatabase(String stagedDatabasePath) async {
    replacePaths.add(stagedDatabasePath);
    await onReplace?.call(stagedDatabasePath);
  }

  @override
  Future<void> shareBackupFile(String path, String displayName) async {
    sharedBytes = Uint8List.fromList(files[path]!);
  }

  @override
  Future<void> writeFile(String path, Uint8List bytes) async {
    files[path] = Uint8List.fromList(bytes);
  }
}
