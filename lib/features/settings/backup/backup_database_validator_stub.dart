Future<void> validateAndMigrateBackupDatabase(
  String path, {
  required int currentSchemaVersion,
}) =>
    throw UnsupportedError('SQLite backup validation is not available on web.');
