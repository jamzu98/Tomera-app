import 'package:drift/drift.dart';

import '../../core/utils.dart';
import '../../features/finance/billable_math.dart';
import '../db/daos/billable_dao.dart';
import '../db/database.dart';

/// The only layer finance widgets talk to (via providers).
class BillableRepository {
  BillableRepository(this._dao);

  final BillableDao _dao;

  Stream<List<BillableItem>> watchAll({
    String? workspaceId,
    String? contactId,
    String? projectId,
    String? eventId,
    String? taskId,
    String? timerSessionId,
  }) => _dao.watchAll(
    workspaceId: workspaceId,
    contactId: contactId,
    projectId: projectId,
    eventId: eventId,
    taskId: taskId,
    timerSessionId: timerSessionId,
  );

  Stream<BillableItem?> watchById(String id) => _dao.watchById(id);

  Future<int?> resolveHourlyRateCents({
    required String workspaceId,
    String? contactId,
    String? projectId,
  }) => _dao.resolveHourlyRateCents(
    workspaceId: workspaceId,
    contactId: contactId,
    projectId: projectId,
  );

  /// Per-status totals for one contact (contact detail screen, spec §6.5).
  Stream<BillableTotals> watchTotalsForContact(String contactId) =>
      _totals(_dao.watchAll(contactId: contactId));

  /// Per-status totals for one project (project detail screen).
  Stream<BillableTotals> watchTotalsForProject(String projectId) =>
      _totals(_dao.watchAll(projectId: projectId));

  Stream<Map<String, BillableTotals>> watchTotalsByCurrencyForContact(
    String contactId,
  ) => _totalsByCurrency(_dao.watchAll(contactId: contactId));

  Stream<Map<String, BillableTotals>> watchTotalsByCurrencyForProject(
    String projectId,
  ) => _totalsByCurrency(_dao.watchAll(projectId: projectId));

  Stream<BillableTotals> _totals(Stream<List<BillableItem>> source) =>
      source.map(
        (items) => sumBillableTotals([
          for (final item in items)
            (
              type: item.type,
              status: item.status,
              rateCents: item.rateCents,
              durationMinutes: item.durationMinutes,
              amountCents: item.amountCents,
            ),
        ]),
      );

  Stream<Map<String, BillableTotals>> _totalsByCurrency(
    Stream<List<BillableItem>> source,
  ) => source.map(
    (items) => sumBillableTotalsByCurrency([
      for (final item in items)
        (
          currency: item.currency,
          type: item.type,
          status: item.status,
          rateCents: item.rateCents,
          durationMinutes: item.durationMinutes,
          amountCents: item.amountCents,
        ),
    ]),
  );

  Future<String> create({
    required String workspaceId,
    String? contactId,
    String? eventId,
    String? taskId,
    String? timerSessionId,
    String? projectId,
    required BillableType type,
    required String title,
    String? description,
    int? rateCents,
    int? durationMinutes,
    int? amountCents,
    String currency = 'EUR',
    BillableStatus status = BillableStatus.unbilled,
  }) async {
    final id = newId();
    final now = utcNowMs();
    await _dao.insertBillable(
      BillableItemsCompanion.insert(
        id: id,
        workspaceId: workspaceId,
        contactId: Value.absentIfNull(contactId),
        eventId: Value.absentIfNull(eventId),
        taskId: Value.absentIfNull(taskId),
        timerSessionId: Value.absentIfNull(timerSessionId),
        projectId: Value.absentIfNull(projectId),
        type: type,
        title: title,
        description: Value.absentIfNull(description),
        rateCents: Value.absentIfNull(rateCents),
        durationMinutes: Value.absentIfNull(durationMinutes),
        amountCents: Value.absentIfNull(amountCents),
        currency: Value(currency),
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Converts a stopped timer into one billable. The database-enforced timer
  /// provenance makes this idempotent across retries and concurrent callers.
  Future<String> createFromTimer({
    required TimerSession session,
    required String title,
    String? description,
    int? rateCents,
    int? durationMinutes,
    String currency = 'EUR',
    BillableStatus status = BillableStatus.unbilled,
  }) async {
    final stoppedAt = session.stoppedAt;
    if (stoppedAt == null) {
      throw StateError('Stop the timer before converting it');
    }
    final effectiveRate =
        rateCents ??
        await resolveHourlyRateCents(
          workspaceId: session.workspaceId,
          contactId: session.contactId,
          projectId: session.projectId,
        );
    final elapsedMs = (stoppedAt - session.startedAt).clamp(0, 1 << 62);
    final effectiveDuration =
        durationMinutes ??
        (elapsedMs + Duration.millisecondsPerMinute - 1) ~/
            Duration.millisecondsPerMinute;
    final id = newId();
    final now = utcNowMs();
    return _dao.insertFromTimer(
      session.id,
      BillableItemsCompanion.insert(
        id: id,
        workspaceId: session.workspaceId,
        contactId: Value.absentIfNull(session.contactId),
        projectId: Value.absentIfNull(session.projectId),
        timerSessionId: Value(session.id),
        type: BillableType.hourly,
        title: title,
        description: Value.absentIfNull(description),
        rateCents: Value.absentIfNull(effectiveRate),
        durationMinutes: Value(effectiveDuration),
        currency: Value(currency),
        status: Value(status),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Nullable columns take a [Value] so callers can distinguish "leave
  /// unchanged" (absent) from "clear" (Value(null)).
  Future<void> update(
    String id, {
    String? workspaceId,
    BillableType? type,
    String? title,
    String? currency,
    BillableStatus? status,
    Value<String?> contactId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<int?> rateCents = const Value.absent(),
    Value<int?> durationMinutes = const Value.absent(),
    Value<int?> amountCents = const Value.absent(),
  }) => _dao.updateBillable(
    id,
    BillableItemsCompanion(
      workspaceId: Value.absentIfNull(workspaceId),
      type: Value.absentIfNull(type),
      title: Value.absentIfNull(title),
      currency: Value.absentIfNull(currency),
      status: Value.absentIfNull(status),
      contactId: contactId,
      projectId: projectId,
      eventId: eventId,
      taskId: taskId,
      description: description,
      rateCents: rateCents,
      durationMinutes: durationMinutes,
      amountCents: amountCents,
    ),
  );

  /// One-tap status progression: unbilled → invoiced → paid → unbilled.
  Future<void> cycleStatus(BillableItem item) {
    final next = switch (item.status) {
      BillableStatus.unbilled => BillableStatus.invoiced,
      BillableStatus.invoiced => BillableStatus.paid,
      BillableStatus.paid => BillableStatus.unbilled,
    };
    return update(item.id, status: next);
  }

  Future<void> delete(String id) => _dao.softDelete(id);

  /// Clears a prior soft-delete, for snackbar undo.
  Future<void> restore(String id) => _dao.restore(id);
}
