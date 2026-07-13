import 'backup_database_validator_stub.dart'
    if (dart.library.io) 'backup_database_validator_io.dart'
    as implementation;
export 'backup_database_validator_api.dart';

Future<void> validateAndMigrateBackupDatabase(
  String path, {
  required int currentSchemaVersion,
}) => implementation.validateAndMigrateBackupDatabase(
  path,
  currentSchemaVersion: currentSchemaVersion,
);
