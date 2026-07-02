import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../db/daos/note_dao.dart';
import '../db/database.dart';

/// The only layer note widgets talk to (via providers).
class NoteRepository {
  NoteRepository(this._dao);

  final NoteDao _dao;

  Stream<List<Note>> watchAll({String? workspaceId}) =>
      _dao.watchAll(workspaceId: workspaceId);

  Stream<Note?> watchById(String id) => _dao.watchById(id);

  Future<String> create({
    String? workspaceId,
    required String title,
    required String body,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertNote(NotesCompanion.insert(
      id: id,
      workspaceId: Value.absentIfNull(workspaceId),
      title: title,
      body: body,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// [workspaceId] takes a [Value] so callers can clear it (standalone note).
  Future<void> update(
    String id, {
    String? title,
    String? body,
    Value<String?> workspaceId = const Value.absent(),
  }) =>
      _dao.updateNote(
        id,
        NotesCompanion(
          title: Value.absentIfNull(title),
          body: Value.absentIfNull(body),
          workspaceId: workspaceId,
        ),
      );

  Future<void> delete(String id) => _dao.softDelete(id);
}
