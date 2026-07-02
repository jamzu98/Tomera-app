import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/enums.dart';
import 'package:tomera/features/finance/finance_summary.dart';

BillableFacts fact({
  String workspaceId = 'w1',
  String? contactId,
  BillableType type = BillableType.fixed,
  BillableStatus status = BillableStatus.unbilled,
  int? rateCents,
  int? durationMinutes,
  int? amountCents = 1000,
  required DateTime createdAt,
}) =>
    (
      workspaceId: workspaceId,
      contactId: contactId,
      type: type,
      status: status,
      rateCents: rateCents,
      durationMinutes: durationMinutes,
      amountCents: amountCents,
      createdAtMs: createdAt.toUtc().millisecondsSinceEpoch,
    );

void main() {
  final july = DateTime(2026, 7, 15);
  final june = DateTime(2026, 6, 15);

  test('hours count only hourly items created in the month', () {
    final summary = summarizeBillables([
      fact(
        type: BillableType.hourly,
        rateCents: 6000,
        durationMinutes: 90,
        amountCents: null,
        createdAt: july,
      ),
      fact(
        type: BillableType.hourly,
        rateCents: 6000,
        durationMinutes: 60,
        amountCents: null,
        createdAt: june,
      ),
      fact(createdAt: july), // fixed: no hours
    ], 2026, 7);
    expect(summary.overall.minutesThisMonth, 90);
  });

  test('unbilled and invoiced are all-time, paid is month-scoped', () {
    final summary = summarizeBillables([
      fact(status: BillableStatus.unbilled, createdAt: june),
      fact(status: BillableStatus.invoiced, createdAt: june),
      fact(status: BillableStatus.paid, createdAt: june),
      fact(status: BillableStatus.paid, createdAt: july),
    ], 2026, 7);
    expect(summary.overall.unbilledCents, 1000);
    expect(summary.overall.invoicedUnpaidCents, 1000);
    expect(summary.overall.paidThisMonthCents, 1000); // july only
  });

  test('splits by workspace and by contact (contactless items excluded from'
      ' byContact)', () {
    final summary = summarizeBillables([
      fact(workspaceId: 'w1', contactId: 'c1', createdAt: july),
      fact(workspaceId: 'w2', createdAt: july),
    ], 2026, 7);
    expect(summary.byWorkspace.keys, containsAll(['w1', 'w2']));
    expect(summary.byWorkspace['w1']!.unbilledCents, 1000);
    expect(summary.byContact.keys, ['c1']);
    expect(summary.overall.unbilledCents, 2000);
  });

  test('formatMinutesAsHours', () {
    expect(formatMinutesAsHours(0), '0h 0m');
    expect(formatMinutesAsHours(90), '1h 30m');
    expect(formatMinutesAsHours(600), '10h 0m');
  });
}
