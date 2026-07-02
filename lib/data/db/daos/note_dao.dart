import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'note_dao.g.dart';

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  SimpleSelectStatement<$NotesTable, Note> get _active =>
      select(notes)..where((n) => n.deletedAt.isNull());

  /// All live notes, newest first, optionally restricted to one workspace.
  Stream<List<Note>> watchAll({String? workspaceId}) {
    final query = _active;
    if (workspaceId != null) {
      query.where((n) => n.workspaceId.equals(workspaceId));
    }
    query.orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    return query.watch();
  }

  Future<Note?> getById(String id) =>
      (_active..where((n) => n.id.equals(id))).getSingleOrNull();

  Stream<Note?> watchById(String id) =>
      (_active..where((n) => n.id.equals(id))).watchSingleOrNull();

  Future<void> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  /// Writes [entry] to the row with [id], bumping `updatedAt`/`isDirty`.
  Future<void> updateNote(String id, NotesCompanion entry) =>
      (update(notes)..where((n) => n.id.equals(id))).write(
        entry.copyWith(
          updatedAt: Value(utcNowMs()),
          isDirty: const Value(true),
        ),
      );

  Future<void> softDelete(String id) =>
      updateNote(id, NotesCompanion(deletedAt: Value(utcNowMs())));
}
