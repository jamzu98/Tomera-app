import 'package:drift/drift.dart';

import '../../../core/utils.dart';
import '../database.dart';
import '../tables.dart';

part 'reminder_dao.g.dart';

@DriftAccessor(tables: [Reminders])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);

  Future<Reminder?> getActiveByParent(
          ParentType parentType, String parentId) =>
      (select(reminders)
            ..where((r) =>
                r.parentType.equalsValue(parentType) &
                r.parentId.equals(parentId) &
                r.deletedAt.isNull()))
          .getSingleOrNull();

  Stream<Reminder?> watchActiveByParent(
          ParentType parentType, String parentId) =>
      (select(reminders)
            ..where((r) =>
                r.parentType.equalsValue(parentType) &
                r.parentId.equals(parentId) &
                r.deletedAt.isNull()))
          .watchSingleOrNull();

  /// One active reminder per parent (v1): update it if present, else insert.
  Future<void> upsertForParent(
      ParentType parentType, String parentId, int fireAt) async {
    final now = utcNowMs();
    final existing = await getActiveByParent(parentType, parentId);
    if (existing != null) {
      await (update(reminders)..where((r) => r.id.equals(existing.id)))
          .write(RemindersCompanion(
        fireAt: Value(fireAt),
        delivered: const Value(false),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));
    } else {
      await into(reminders).insert(RemindersCompanion.insert(
        id: newId(),
        parentType: parentType,
        parentId: parentId,
        fireAt: fireAt,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  /// Soft-deletes the active reminder for a parent, if any.
  Future<void> removeForParent(ParentType parentType, String parentId) async {
    final now = utcNowMs();
    await (update(reminders)
          ..where((r) =>
              r.parentType.equalsValue(parentType) &
              r.parentId.equals(parentId) &
              r.deletedAt.isNull()))
        .write(RemindersCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      isDirty: const Value(true),
    ));
  }
}
