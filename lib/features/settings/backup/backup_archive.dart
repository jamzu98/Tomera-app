import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

const backupFormatVersion = 1;
const backupFileExtension = 'tomera-backup';

const _magic = 'TOMERA_PORTABLE_BACKUP';
const _databaseEntry = 'database.sqlite';
const _preferencesEntry = 'preferences.json';
const _manifestEntry = 'manifest.json';
const _maximumDatabaseBytes = 120 * 1024 * 1024;
const _maximumPreferencesBytes = 4 * 1024 * 1024;
const _maximumManifestBytes = 128 * 1024;

enum BackupArchiveError {
  invalidFormat,
  unsupportedVersion,
  authenticationFailed,
  corrupted,
}

class BackupArchiveException implements Exception {
  const BackupArchiveException(this.error, [this.cause]);

  final BackupArchiveError error;
  final Object? cause;

  @override
  String toString() => 'BackupArchiveException($error, $cause)';
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.appBuildNumber,
    required this.createdAtUtc,
    required this.fileHashes,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final String appBuildNumber;
  final DateTime createdAtUtc;
  final Map<String, String> fileHashes;

  Map<String, Object> toJson() => {
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'appBuildNumber': appBuildNumber,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'hashAlgorithm': 'SHA-256',
    'files': fileHashes,
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    try {
      if (json['hashAlgorithm'] != 'SHA-256') {
        throw const BackupArchiveException(
          BackupArchiveError.unsupportedVersion,
        );
      }
      final files = json['files']! as Map<String, Object?>;
      return BackupManifest(
        formatVersion: json['formatVersion']! as int,
        schemaVersion: json['schemaVersion']! as int,
        appVersion: json['appVersion']! as String,
        appBuildNumber: json['appBuildNumber']! as String,
        createdAtUtc: DateTime.parse(json['createdAtUtc']! as String).toUtc(),
        fileHashes: files.map((key, value) => MapEntry(key, value! as String)),
      );
    } on BackupArchiveException {
      rethrow;
    } on Object catch (error) {
      throw BackupArchiveException(BackupArchiveError.invalidFormat, error);
    }
  }
}

class BackupArchiveContents {
  const BackupArchiveContents({
    required this.databaseBytes,
    required this.preferences,
    required this.manifest,
  });

  final Uint8List databaseBytes;
  final Map<String, Object?> preferences;
  final BackupManifest manifest;
}

/// Password-authenticated Tomera backup container.
///
/// The inner ZIP contains the SQLite snapshot, preferences JSON, and a
/// manifest. The complete ZIP is encrypted with AES-256-GCM using a key
/// derived with Argon2id. The unencrypted envelope only carries the version
/// and KDF/cipher parameters required to decrypt it.
class BackupArchiveCodec {
  BackupArchiveCodec({
    this.argonMemoryKiB = 19 * 1024,
    this.argonIterations = 2,
    this.argonParallelism = 1,
    this.minimumAcceptedMemoryKiB = 8 * 1024,
  });

  final int argonMemoryKiB;
  final int argonIterations;
  final int argonParallelism;
  final int minimumAcceptedMemoryKiB;

  final AesGcm _cipher = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();

  Future<Uint8List> encode({
    required Uint8List databaseBytes,
    required Map<String, Object?> preferences,
    required int schemaVersion,
    required String appVersion,
    required String appBuildNumber,
    required DateTime createdAtUtc,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const BackupArchiveException(
        BackupArchiveError.authenticationFailed,
      );
    }

    final preferencesBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(_sortedMap(preferences))),
    );
    final hashes = <String, String>{
      _databaseEntry: await _hash(databaseBytes),
      _preferencesEntry: await _hash(preferencesBytes),
    };
    final manifest = BackupManifest(
      formatVersion: backupFormatVersion,
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      appBuildNumber: appBuildNumber,
      createdAtUtc: createdAtUtc,
      fileHashes: hashes,
    );
    final manifestBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest.toJson())),
    );

    final archive = Archive()
      ..add(ArchiveFile.bytes(_databaseEntry, databaseBytes))
      ..add(ArchiveFile.bytes(_preferencesEntry, preferencesBytes))
      ..add(ArchiveFile.bytes(_manifestEntry, manifestBytes));
    final archiveBytes = ZipEncoder().encodeBytes(archive);

    final salt = randomBytes(16);
    final key = await _deriveKey(
      password: password,
      salt: salt,
      memoryKiB: argonMemoryKiB,
      iterations: argonIterations,
      parallelism: argonParallelism,
    );
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      archiveBytes,
      secretKey: key,
      nonce: nonce,
      aad: _aad,
    );

    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'magic': _magic,
          'formatVersion': backupFormatVersion,
          'kdf': {
            'name': 'Argon2id',
            'version': 19,
            'memoryKiB': argonMemoryKiB,
            'iterations': argonIterations,
            'parallelism': argonParallelism,
            'salt': base64Encode(salt),
          },
          'cipher': {
            'name': 'AES-256-GCM',
            'nonce': base64Encode(nonce),
            'mac': base64Encode(box.mac.bytes),
          },
          'ciphertext': base64Encode(box.cipherText),
        }),
      ),
    );
  }

  Future<BackupArchiveContents> decode({
    required Uint8List encryptedBytes,
    required String password,
  }) async {
    try {
      final envelope = jsonDecode(utf8.decode(encryptedBytes));
      if (envelope is! Map<String, Object?> || envelope['magic'] != _magic) {
        throw const BackupArchiveException(BackupArchiveError.invalidFormat);
      }
      final version = envelope['formatVersion'];
      if (version != backupFormatVersion) {
        throw const BackupArchiveException(
          BackupArchiveError.unsupportedVersion,
        );
      }
      final kdf = envelope['kdf']! as Map<String, Object?>;
      final cipher = envelope['cipher']! as Map<String, Object?>;
      if (kdf['name'] != 'Argon2id' ||
          kdf['version'] != 19 ||
          cipher['name'] != 'AES-256-GCM') {
        throw const BackupArchiveException(
          BackupArchiveError.unsupportedVersion,
        );
      }
      final memoryKiB = kdf['memoryKiB']! as int;
      final iterations = kdf['iterations']! as int;
      final parallelism = kdf['parallelism']! as int;
      if (memoryKiB < minimumAcceptedMemoryKiB ||
          memoryKiB > 256 * 1024 ||
          iterations < 1 ||
          iterations > 10 ||
          parallelism < 1 ||
          parallelism > 8) {
        throw const BackupArchiveException(BackupArchiveError.invalidFormat);
      }
      final key = await _deriveKey(
        password: password,
        salt: _decodeSizedBase64(kdf['salt'], 16),
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
      );
      final box = SecretBox(
        base64Decode(envelope['ciphertext']! as String),
        nonce: _decodeSizedBase64(cipher['nonce'], 12),
        mac: Mac(_decodeSizedBase64(cipher['mac'], 16)),
      );
      late final List<int> zipBytes;
      try {
        zipBytes = await _cipher.decrypt(box, secretKey: key, aad: _aad);
      } on SecretBoxAuthenticationError catch (error) {
        throw BackupArchiveException(
          BackupArchiveError.authenticationFailed,
          error,
        );
      }

      final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
      final databaseEntry = archive.find(_databaseEntry);
      final preferencesEntry = archive.find(_preferencesEntry);
      final manifestEntry = archive.find(_manifestEntry);
      if (archive.length != 3 ||
          databaseEntry == null ||
          databaseEntry.size > _maximumDatabaseBytes ||
          preferencesEntry == null ||
          preferencesEntry.size > _maximumPreferencesBytes ||
          manifestEntry == null ||
          manifestEntry.size > _maximumManifestBytes) {
        throw const BackupArchiveException(BackupArchiveError.invalidFormat);
      }
      final database = databaseEntry.content;
      final preferencesBytes = preferencesEntry.content;
      final manifestBytes = manifestEntry.content;
      final manifestJson = jsonDecode(utf8.decode(manifestBytes));
      if (manifestJson is! Map<String, Object?>) {
        throw const BackupArchiveException(BackupArchiveError.invalidFormat);
      }
      final manifest = BackupManifest.fromJson(manifestJson);
      if (manifest.formatVersion != backupFormatVersion) {
        throw const BackupArchiveException(
          BackupArchiveError.unsupportedVersion,
        );
      }
      if (manifest.fileHashes[_databaseEntry] != await _hash(database) ||
          manifest.fileHashes[_preferencesEntry] !=
              await _hash(preferencesBytes)) {
        throw const BackupArchiveException(BackupArchiveError.corrupted);
      }
      final preferencesJson = jsonDecode(utf8.decode(preferencesBytes));
      if (preferencesJson is! Map<String, Object?>) {
        throw const BackupArchiveException(BackupArchiveError.invalidFormat);
      }
      _validatePreferences(preferencesJson);
      return BackupArchiveContents(
        databaseBytes: Uint8List.fromList(database),
        preferences: preferencesJson,
        manifest: manifest,
      );
    } on BackupArchiveException {
      rethrow;
    } on Object catch (error) {
      throw BackupArchiveException(BackupArchiveError.invalidFormat, error);
    }
  }

  List<int> get _aad => utf8.encode('$_magic:$backupFormatVersion');

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
  }) => Argon2id(
    memory: memoryKiB,
    iterations: iterations,
    parallelism: parallelism,
    hashLength: 32,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  Future<String> _hash(List<int> bytes) async {
    final digest = await _sha256.hash(bytes);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

Map<String, Object?> _sortedMap(Map<String, Object?> source) {
  final result = <String, Object?>{};
  for (final key in source.keys.toList()..sort()) {
    result[key] = source[key];
  }
  return result;
}

void _validatePreferences(Map<String, Object?> preferences) {
  for (final value in preferences.values) {
    final valid =
        value == null ||
        value is bool ||
        value is int ||
        value is double ||
        value is String ||
        (value is List<Object?> && value.every((item) => item is String));
    if (!valid) {
      throw const BackupArchiveException(BackupArchiveError.invalidFormat);
    }
  }
}

List<int> _decodeSizedBase64(Object? encoded, int expectedLength) {
  if (encoded is! String) {
    throw const BackupArchiveException(BackupArchiveError.invalidFormat);
  }
  final bytes = base64Decode(encoded);
  if (bytes.length != expectedLength) {
    throw const BackupArchiveException(BackupArchiveError.invalidFormat);
  }
  return bytes;
}
