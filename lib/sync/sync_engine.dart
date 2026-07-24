import 'dart:async';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db/database.dart';

const syncTableOrder = <String>[
  'workspaces',
  'contacts',
  'workspace_contacts',
  'projects',
  'event_series',
  'event_series_contacts',
  'events',
  'event_contacts',
  'task_series',
  'tasks',
  'notes',
  'note_links',
  'timer_sessions',
  'billable_items',
  'reminders',
];

class SyncEngine {
  SyncEngine({
    required this.database,
    required this.client,
    required this.userId,
  });

  final AppDatabase database;
  final SupabaseClient client;
  final String userId;
  final Map<String, List<String>> _columns = {};

  Future<bool> hasCloudData() async {
    final result = await client.rpc<dynamic>('sync_has_data');
    return result == true;
  }

  Future<bool> hasLocalData() async {
    for (final table in syncTableOrder) {
      final row = await database
          .customSelect('SELECT 1 AS present FROM "$table" LIMIT 1')
          .getSingleOrNull();
      if (row != null) return true;
    }
    return false;
  }

  Future<void> importAll() async {
    for (final table in syncTableOrder) {
      var offset = 0;
      while (true) {
        final rows = await database
            .customSelect(
              'SELECT * FROM "$table" ORDER BY created_at, id LIMIT 200 OFFSET ?',
              variables: [Variable<int>(offset)],
            )
            .get();
        if (rows.isEmpty) break;
        await _pushMaps(
          table,
          rows.map((row) => row.data).toList(),
          applyCanonical: false,
        );
        offset += rows.length;
      }
    }
  }

  Future<void> synchronize() async {
    await _pushDirty();
    await _pullChanges();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await database.customStatement(
      'INSERT INTO sync_states '
      '(id, last_pulled_version, last_successful_sync_at, last_error) '
      "VALUES ('default', COALESCE((SELECT last_pulled_version FROM sync_states "
      "WHERE id = 'default'), 0), ?, NULL) "
      'ON CONFLICT(id) DO UPDATE SET last_successful_sync_at = excluded.last_successful_sync_at, '
      'last_error = NULL',
      [now],
    );
  }

  Future<void> recordError(Object error) => database.customStatement(
    'INSERT INTO sync_states (id, last_error) VALUES (?, ?) '
    'ON CONFLICT(id) DO UPDATE SET last_error = excluded.last_error',
    ['default', error.toString()],
  );

  Future<int> pendingCount() async {
    var count = 0;
    for (final table in syncTableOrder) {
      final row = await database
          .customSelect(
            'SELECT COUNT(*) AS amount FROM "$table" WHERE is_dirty = 1',
          )
          .getSingle();
      count += row.read<int>('amount');
    }
    return count;
  }

  Future<void> _pushDirty() async {
    for (final table in syncTableOrder) {
      final rows = await database
          .customSelect(
            'SELECT * FROM "$table" WHERE is_dirty = 1 '
            'ORDER BY created_at, id LIMIT 200',
          )
          .get();
      if (rows.isEmpty) continue;
      await _pushMaps(table, rows.map((row) => row.data).toList());
    }
  }

  Future<void> _pushMaps(
    String table,
    List<Map<String, Object?>> localRows, {
    bool applyCanonical = true,
  }) async {
    final payload = [
      for (final local in localRows)
        {
          for (final entry in local.entries)
            if (entry.key != 'is_dirty') entry.key: _jsonValue(entry.value),
          'owner_id': userId,
        },
    ];
    final response = await client.rpc<dynamic>(
      'sync_push',
      params: {'p_table': table, 'p_rows': payload},
    );
    if (response is! List) {
      throw const FormatException('sync_push returned an invalid response.');
    }
    if (!applyCanonical) return;
    final byId = {for (final row in localRows) row['id'] as String: row};
    await database.transaction(() async {
      for (final item in response) {
        final result = Map<String, Object?>.from(item as Map);
        final canonicalValue = result['row_data'] ?? result['row'];
        if (canonicalValue is! Map) continue;
        final canonical = Map<String, Object?>.from(canonicalValue);
        final id = canonical['id'] as String?;
        if (id == null) continue;
        final pushed = byId[id];
        if (pushed == null) continue;
        final current = await database
            .customSelect(
              'SELECT updated_at, is_dirty FROM "$table" WHERE id = ?',
              variables: [Variable<String>(id)],
            )
            .getSingleOrNull();
        if (current == null) continue;
        final currentUpdated = current.read<int>('updated_at');
        final pushedUpdated = (pushed['updated_at'] as num).toInt();
        // A write that happened while this request was in flight must remain
        // dirty, even when the server's canonical row has a later timestamp.
        if (currentUpdated != pushedUpdated) continue;
        await _upsertLocal(table, canonical, dirty: false);
      }
    });
  }

  Future<void> _pullChanges() async {
    var cursor = await _readCursor();
    while (true) {
      final response = await client.rpc<dynamic>(
        'sync_pull',
        params: {'p_after_version': cursor, 'p_limit': 500},
      );
      if (response is! List) {
        throw const FormatException('sync_pull returned an invalid response.');
      }
      if (response.isEmpty) break;
      await database.transaction(() async {
        for (final item in response) {
          final change = Map<String, Object?>.from(item as Map);
          final table = change['table_name'] as String?;
          final rowValue = change['row_data'] ?? change['payload'];
          final version = (change['version'] as num?)?.toInt();
          if (table == null ||
              !syncTableOrder.contains(table) ||
              rowValue is! Map ||
              version == null) {
            throw const FormatException('Malformed sync change.');
          }
          final remote = Map<String, Object?>.from(rowValue);
          await _mergeRemote(table, remote);
          if (version > cursor) cursor = version;
        }
        await _writeCursor(cursor);
      });
      if (response.length < 500) break;
    }
  }

  Future<void> _mergeRemote(String table, Map<String, Object?> remote) async {
    final id = remote['id'] as String;
    final current = await database
        .customSelect(
          'SELECT updated_at, is_dirty FROM "$table" WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (current != null && current.read<bool>('is_dirty')) {
      final localUpdated = current.read<int>('updated_at');
      final remoteUpdated = (remote['updated_at'] as num).toInt();
      if (localUpdated > remoteUpdated) return;
    }
    await _upsertLocal(table, remote, dirty: false);
  }

  Future<void> _upsertLocal(
    String table,
    Map<String, Object?> row, {
    required bool dirty,
  }) async {
    final allowed = await _columnsFor(table);
    final values = <String, Object?>{
      for (final entry in row.entries)
        if (allowed.contains(entry.key)) entry.key: _sqliteValue(entry.value),
      'is_dirty': dirty ? 1 : 0,
    };
    final columns = values.keys.toList();
    final quoted = columns.map((column) => '"$column"').join(', ');
    final placeholders = List.filled(columns.length, '?').join(', ');
    final updates = columns
        .where((column) => column != 'id')
        .map((column) => '"$column" = excluded."$column"')
        .join(', ');
    await database.customStatement(
      'INSERT INTO "$table" ($quoted) VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      [for (final column in columns) values[column]],
    );
  }

  Future<List<String>> _columnsFor(String table) async {
    final cached = _columns[table];
    if (cached != null) return cached;
    final rows = await database
        .customSelect('PRAGMA table_info("$table")')
        .get();
    final columns = rows.map((row) => row.read<String>('name')).toList();
    _columns[table] = columns;
    return columns;
  }

  Future<int> _readCursor() async {
    final row = await database
        .customSelect(
          "SELECT last_pulled_version FROM sync_states WHERE id = 'default'",
        )
        .getSingleOrNull();
    return row?.read<int>('last_pulled_version') ?? 0;
  }

  Future<void> _writeCursor(int cursor) => database.customStatement(
    'INSERT INTO sync_states (id, last_pulled_version) VALUES (?, ?) '
    'ON CONFLICT(id) DO UPDATE SET last_pulled_version = excluded.last_pulled_version',
    ['default', cursor],
  );
}

Object? _jsonValue(Object? value) => switch (value) {
  DateTime dateTime => dateTime.toUtc().millisecondsSinceEpoch,
  _ => value,
};

Object? _sqliteValue(Object? value) => switch (value) {
  bool flag => flag ? 1 : 0,
  _ => value,
};
