import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';
import 'package:tomera/sync/sync_engine.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SyncEngine engine;

  setUp(() {
    database = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    engine = SyncEngine(
      database: database,
      client: SupabaseClient('https://example.supabase.co', 'test-key'),
      userId: '00000000-0000-4000-8000-000000000001',
    );
  });

  tearDown(() => database.close());

  test('profile names preserve guest storage and isolate account caches', () {
    expect(const DataProfile.guest().databaseName, 'tomera');
    expect(
      const DataProfile.user(
        '00000000-0000-4000-8000-000000000001',
      ).databaseName,
      'tomera_user_00000000000040008000000000000001',
    );
  });

  test(
    'local data and dirty rows are discoverable for import and sync',
    () async {
      expect(await engine.hasLocalData(), isFalse);
      expect(await engine.pendingCount(), 0);

      await WorkspaceRepository(database.workspaceDao).create(
        name: 'Local work',
        color: 0xFF7C7FF2,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );

      expect(await engine.hasLocalData(), isTrue);
      expect(await engine.pendingCount(), 1);
    },
  );

  test('account deletion clears domain data and its sync cursor', () async {
    await WorkspaceRepository(database.workspaceDao).create(
      name: 'Cloud work',
      color: 0xFF7C7FF2,
      icon: 'work',
      enabledModules: {...ModuleKey.values},
    );
    await database.customStatement(
      "INSERT INTO sync_states (id, last_pulled_version) VALUES ('default', 42)",
    );

    await database.clearProfileData();

    expect(await engine.hasLocalData(), isFalse);
    final state = await database
        .customSelect(
          "SELECT last_pulled_version FROM sync_states WHERE id = 'default'",
        )
        .getSingleOrNull();
    expect(state, null);
  });
}
