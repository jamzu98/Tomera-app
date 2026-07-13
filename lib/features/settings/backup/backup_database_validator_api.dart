enum BackupDatabaseValidationError {
  invalidDatabase,
  newerSchema,
  integrityCheckFailed,
  foreignKeyCheckFailed,
}

class BackupDatabaseValidationException implements Exception {
  const BackupDatabaseValidationException(this.error, [this.cause]);

  final BackupDatabaseValidationError error;
  final Object? cause;
}
