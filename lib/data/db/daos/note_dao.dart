import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'note_dao.g.dart';

@DriftAccessor(tables: [Notes, NoteLinks])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  SimpleSelectStatement<$NotesTable, Note> get _active =>
      select(notes)
        ..where((n) => n.deletedAt.isNull() & _workspaceIsActiveOrAbsent(n));

  Expression<bool> _workspaceIsActiveOrAbsent($NotesTable note) {
    final parent = attachedDatabase.workspaces;
    return note.workspaceId.isNull() |
        existsQuery(
          select(parent)..where(
            (w) => w.id.equalsExp(note.workspaceId) & w.deletedAt.isNull(),
          ),
        );
  }

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

  Future<void> restore(String id) =>
      updateNote(id, const NotesCompanion(deletedAt: Value(null)));

  /// FTS5 matches for an already-sanitized MATCH expression, best first.
  Stream<List<Note>> search(String ftsQuery) => attachedDatabase
      .searchNotes(ftsQuery)
      .watch()
      .map((rows) => [for (final row in rows) row.n]);

  /// Live notes attached to a polymorphic parent, newest first.
  Stream<List<Note>> watchByParent(ParentType parentType, String parentId) {
    final query = _active
      ..where(
        (n) =>
            n.parentType.equalsValue(parentType) & n.parentId.equals(parentId),
      )
      ..where((_) => _parentExists(parentType, parentId))
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    return query.watch();
  }

  /// Active typed references owned by [noteId]. Links to deleted targets are
  /// retained for sync/history but excluded from normal reads.
  Stream<List<NoteLink>> watchLinks(String noteId) {
    final query = select(noteLinks)
      ..where((l) => l.noteId.equals(noteId) & l.deletedAt.isNull())
      ..where((_) => existsQuery(_active..where((n) => n.id.equals(noteId))))
      ..where(_targetExistsExpression)
      ..orderBy([(l) => OrderingTerm.desc(l.updatedAt)]);
    return query.watch();
  }

  /// Active notes referencing a typed target, newest note first.
  Stream<List<Note>> watchBacklinks(ParentType targetType, String targetId) {
    final query =
        select(notes).join([
            innerJoin(
              noteLinks,
              noteLinks.noteId.equalsExp(notes.id) &
                  noteLinks.targetType.equalsValue(targetType) &
                  noteLinks.targetId.equals(targetId) &
                  noteLinks.deletedAt.isNull(),
            ),
          ])
          ..where(notes.deletedAt.isNull() & _workspaceIsActiveOrAbsent(notes))
          ..where(noteLinks.deletedAt.isNull())
          ..where(_parentExists(targetType, targetId))
          ..orderBy([OrderingTerm.desc(notes.updatedAt)]);
    return query.map((row) => row.readTable(notes)).watch();
  }

  /// Adds or restores a reference. Returns the stable link id and is
  /// idempotent when the active relationship already exists.
  Future<String> addLink({
    required String noteId,
    required ParentType targetType,
    required String targetId,
  }) => transaction(() async {
    if (await getById(noteId) == null ||
        !await _targetExistsNow(targetType, targetId)) {
      throw StateError('Cannot link a deleted or missing record');
    }

    final existing =
        await (select(noteLinks)
              ..where(
                (l) =>
                    l.noteId.equals(noteId) &
                    l.targetType.equalsValue(targetType) &
                    l.targetId.equals(targetId),
              )
              ..orderBy([(l) => OrderingTerm.desc(l.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (existing != null && existing.deletedAt == null) return existing.id;

    final now = utcNowMs();
    if (existing != null) {
      await (update(noteLinks)..where((l) => l.id.equals(existing.id))).write(
        NoteLinksCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      return existing.id;
    }

    final id = newId();
    await into(noteLinks).insert(
      NoteLinksCompanion.insert(
        id: id,
        noteId: noteId,
        targetType: targetType,
        targetId: targetId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  });

  Future<void> removeLink({
    required String noteId,
    required ParentType targetType,
    required String targetId,
  }) async {
    final now = utcNowMs();
    await (update(noteLinks)..where(
          (l) =>
              l.noteId.equals(noteId) &
              l.targetType.equalsValue(targetType) &
              l.targetId.equals(targetId) &
              l.deletedAt.isNull(),
        ))
        .write(
          NoteLinksCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
  }

  Expression<bool> _parentExists(ParentType type, String id) => switch (type) {
    ParentType.workspace => existsQuery(
      select(attachedDatabase.workspaces)
        ..where((w) => w.id.equals(id) & w.deletedAt.isNull()),
    ),
    ParentType.event => existsQuery(
      select(attachedDatabase.events)
        ..where((e) => e.id.equals(id) & _eventIsActive(e)),
    ),
    ParentType.task => existsQuery(
      select(attachedDatabase.tasks)
        ..where((t) => t.id.equals(id) & _taskIsActive(t)),
    ),
    ParentType.contact => existsQuery(
      select(attachedDatabase.contacts)
        ..where((c) => c.id.equals(id) & c.deletedAt.isNull()),
    ),
    ParentType.project => existsQuery(
      select(attachedDatabase.projects)
        ..where((p) => p.id.equals(id) & _projectIsActive(p)),
    ),
    ParentType.billable => existsQuery(
      select(attachedDatabase.billableItems)
        ..where((b) => b.id.equals(id) & _billableIsActive(b)),
    ),
    ParentType.timerSession => existsQuery(
      select(attachedDatabase.timerSessions)
        ..where((t) => t.id.equals(id) & _timerIsActive(t)),
    ),
  };

  Expression<bool> _targetExistsExpression($NoteLinksTable link) =>
      (link.targetType.equalsValue(ParentType.workspace) &
          existsQuery(
            select(attachedDatabase.workspaces)..where(
              (w) => w.id.equalsExp(link.targetId) & w.deletedAt.isNull(),
            ),
          )) |
      (link.targetType.equalsValue(ParentType.event) &
          existsQuery(
            select(attachedDatabase.events)
              ..where((e) => e.id.equalsExp(link.targetId) & _eventIsActive(e)),
          )) |
      (link.targetType.equalsValue(ParentType.task) &
          existsQuery(
            select(attachedDatabase.tasks)
              ..where((t) => t.id.equalsExp(link.targetId) & _taskIsActive(t)),
          )) |
      (link.targetType.equalsValue(ParentType.contact) &
          existsQuery(
            select(attachedDatabase.contacts)..where(
              (c) => c.id.equalsExp(link.targetId) & c.deletedAt.isNull(),
            ),
          )) |
      (link.targetType.equalsValue(ParentType.project) &
          existsQuery(
            select(attachedDatabase.projects)..where(
              (p) => p.id.equalsExp(link.targetId) & _projectIsActive(p),
            ),
          )) |
      (link.targetType.equalsValue(ParentType.billable) &
          existsQuery(
            select(attachedDatabase.billableItems)..where(
              (b) => b.id.equalsExp(link.targetId) & _billableIsActive(b),
            ),
          )) |
      (link.targetType.equalsValue(ParentType.timerSession) &
          existsQuery(
            select(attachedDatabase.timerSessions)
              ..where((t) => t.id.equalsExp(link.targetId) & _timerIsActive(t)),
          ));

  Future<bool> _targetExistsNow(ParentType type, String id) async {
    final row = switch (type) {
      ParentType.workspace =>
        await (select(attachedDatabase.workspaces)
              ..where((w) => w.id.equals(id) & w.deletedAt.isNull()))
            .getSingleOrNull(),
      ParentType.event => await (select(
        attachedDatabase.events,
      )..where((e) => e.id.equals(id) & _eventIsActive(e))).getSingleOrNull(),
      ParentType.task => await (select(
        attachedDatabase.tasks,
      )..where((t) => t.id.equals(id) & _taskIsActive(t))).getSingleOrNull(),
      ParentType.contact =>
        await (select(attachedDatabase.contacts)
              ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
            .getSingleOrNull(),
      ParentType.project => await (select(
        attachedDatabase.projects,
      )..where((p) => p.id.equals(id) & _projectIsActive(p))).getSingleOrNull(),
      ParentType.billable =>
        await (select(attachedDatabase.billableItems)
              ..where((b) => b.id.equals(id) & _billableIsActive(b)))
            .getSingleOrNull(),
      ParentType.timerSession => await (select(
        attachedDatabase.timerSessions,
      )..where((t) => t.id.equals(id) & _timerIsActive(t))).getSingleOrNull(),
    };
    return row != null;
  }

  Expression<bool> _eventIsActive($EventsTable event) =>
      event.deletedAt.isNull() & _hasActiveWorkspace(event.workspaceId);

  Expression<bool> _taskIsActive($TasksTable task) =>
      task.deletedAt.isNull() & _hasActiveWorkspace(task.workspaceId);

  Expression<bool> _projectIsActive($ProjectsTable project) =>
      project.deletedAt.isNull() & _hasActiveWorkspace(project.workspaceId);

  Expression<bool> _billableIsActive($BillableItemsTable billable) =>
      billable.deletedAt.isNull() & _hasActiveWorkspace(billable.workspaceId);

  Expression<bool> _timerIsActive($TimerSessionsTable timer) =>
      timer.deletedAt.isNull() & _hasActiveWorkspace(timer.workspaceId);

  Expression<bool> _hasActiveWorkspace(Expression<String> workspaceId) =>
      existsQuery(
        select(attachedDatabase.workspaces)
          ..where((w) => w.id.equalsExp(workspaceId) & w.deletedAt.isNull()),
      );
}
