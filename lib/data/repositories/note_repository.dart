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

  Stream<List<Note>> watchByParent(ParentType parentType, String parentId) =>
      _dao.watchByParent(parentType, parentId);

  Stream<List<NoteLink>> watchLinks(String noteId) => _dao.watchLinks(noteId);

  Stream<List<Note>> watchBacklinks(ParentType targetType, String targetId) =>
      _dao.watchBacklinks(targetType, targetId);

  /// Full-text search (spec §6.4). Raw user input is sanitized into quoted
  /// prefix terms so FTS5 operators in the input can't break the query.
  Stream<List<Note>> search(String rawQuery) {
    final terms = rawQuery
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('"', ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*')
        .toList();
    if (terms.isEmpty) return Stream.value(const []);
    return _dao.search(terms.join(' '));
  }

  Future<String> create({
    String? workspaceId,
    required String title,
    required String body,
    ParentType? parentType,
    String? parentId,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertNote(
      NotesCompanion.insert(
        id: id,
        workspaceId: Value.absentIfNull(workspaceId),
        title: title,
        body: body,
        parentType: Value.absentIfNull(parentType),
        parentId: Value.absentIfNull(parentId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// [workspaceId] takes a [Value] so callers can clear it (standalone note).
  Future<void> update(
    String id, {
    String? title,
    String? body,
    Value<String?> workspaceId = const Value.absent(),
    Value<ParentType?> parentType = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
  }) => _dao.updateNote(
    id,
    NotesCompanion(
      title: Value.absentIfNull(title),
      body: Value.absentIfNull(body),
      workspaceId: workspaceId,
      parentType: parentType,
      parentId: parentId,
    ),
  );

  Future<String> addLink(
    String noteId,
    ParentType targetType,
    String targetId,
  ) => _dao.addLink(noteId: noteId, targetType: targetType, targetId: targetId);

  Future<void> removeLink(
    String noteId,
    ParentType targetType,
    String targetId,
  ) => _dao.removeLink(
    noteId: noteId,
    targetType: targetType,
    targetId: targetId,
  );

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Clears a prior soft-delete, for snackbar undo.
  Future<void> restore(String id) => _dao.restore(id);
}
