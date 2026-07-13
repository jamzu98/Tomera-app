import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../data/db/database.dart';
import 'backup_database_validator_api.dart';

Future<void> validateAndMigrateBackupDatabase(
  String path, {
  required int currentSchemaVersion,
}) async {
  int sourceVersion;
  try {
    final raw = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    try {
      final rows = raw.select('PRAGMA user_version');
      sourceVersion = rows.first.values.first! as int;
    } finally {
      raw.close();
    }
  } on Object catch (error) {
    throw BackupDatabaseValidationException(
      BackupDatabaseValidationError.invalidDatabase,
      error,
    );
  }
  if (sourceVersion < 1) {
    throw const BackupDatabaseValidationException(
      BackupDatabaseValidationError.invalidDatabase,
    );
  }
  if (sourceVersion > currentSchemaVersion) {
    throw BackupDatabaseValidationException(
      BackupDatabaseValidationError.newerSchema,
      sourceVersion,
    );
  }

  final database = AppDatabase(NativeDatabase(File(path)));
  try {
    // The first query runs the same stepwise migrations used at app startup.
    final integrity = await database
        .customSelect('PRAGMA integrity_check')
        .get();
    if (integrity.length != 1 ||
        integrity.single.data.values.singleOrNull != 'ok') {
      throw BackupDatabaseValidationException(
        BackupDatabaseValidationError.integrityCheckFailed,
        integrity.map((row) => row.data).toList(),
      );
    }
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_check')
        .get();
    if (foreignKeys.isNotEmpty) {
      throw BackupDatabaseValidationException(
        BackupDatabaseValidationError.foreignKeyCheckFailed,
        foreignKeys.map((row) => row.data).toList(),
      );
    }
    final migratedVersion = await database
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    if (migratedVersion != currentSchemaVersion) {
      throw BackupDatabaseValidationException(
        BackupDatabaseValidationError.invalidDatabase,
        migratedVersion,
      );
    }
  } on BackupDatabaseValidationException {
    rethrow;
  } on Object catch (error) {
    throw BackupDatabaseValidationException(
      BackupDatabaseValidationError.invalidDatabase,
      error,
    );
  } finally {
    await database.close();
  }
}
