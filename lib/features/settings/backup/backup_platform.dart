import 'backup_platform_api.dart';
import 'backup_platform_stub.dart'
    if (dart.library.io) 'backup_platform_io.dart'
    as implementation;

export 'backup_platform_api.dart';

BackupPlatform createBackupPlatform() => implementation.createBackupPlatform();
