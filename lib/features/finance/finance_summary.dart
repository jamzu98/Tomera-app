import '../../data/db/enums.dart';
import 'billable_math.dart';

/// Facts needed to summarize one billable item, decoupled from Drift rows so
/// the aggregation stays pure and unit-testable.
typedef BillableFacts = ({
  String workspaceId,
  String? contactId,
  BillableType type,
  BillableStatus status,
  int? rateCents,
  int? durationMinutes,
  int? amountCents,
  int createdAtMs,
});

/// Spec §6.6 summary values for one group (overall, a workspace, or a
/// contact): hours this month, outstanding unbilled and invoiced-but-unpaid
/// totals (all-time), and the total paid this month. Money in cents.
class GroupSummary {
  int minutesThisMonth = 0;
  int unbilledCents = 0;
  int invoicedUnpaidCents = 0;
  int paidThisMonthCents = 0;
}

class FinanceSummary {
  FinanceSummary(this.overall, this.byWorkspace, this.byContact);

  final GroupSummary overall;
  final Map<String, GroupSummary> byWorkspace;

  /// Only items linked to a contact contribute here.
  final Map<String, GroupSummary> byContact;
}

bool _inMonth(int epochMs, int year, int month) {
  final local =
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
  return local.year == year && local.month == month;
}

/// Aggregates billables for the local-time month ([year], [month]).
FinanceSummary summarizeBillables(
    Iterable<BillableFacts> items, int year, int month) {
  final overall = GroupSummary();
  final byWorkspace = <String, GroupSummary>{};
  final byContact = <String, GroupSummary>{};

  for (final item in items) {
    final total = billableTotalCents(
      type: item.type,
      rateCents: item.rateCents,
      durationMinutes: item.durationMinutes,
      amountCents: item.amountCents,
    );
    final inMonth = _inMonth(item.createdAtMs, year, month);
    final groups = [
      overall,
      byWorkspace.putIfAbsent(item.workspaceId, GroupSummary.new),
      if (item.contactId != null)
        byContact.putIfAbsent(item.contactId!, GroupSummary.new),
    ];
    for (final group in groups) {
      if (inMonth && item.type == BillableType.hourly) {
        group.minutesThisMonth += item.durationMinutes ?? 0;
      }
      switch (item.status) {
        case BillableStatus.unbilled:
          group.unbilledCents += total;
        case BillableStatus.invoiced:
          group.invoicedUnpaidCents += total;
        case BillableStatus.paid:
          if (inMonth) group.paidThisMonthCents += total;
      }
    }
  }
  return FinanceSummary(overall, byWorkspace, byContact);
}

/// "3h 45m" display for a minute count.
String formatMinutesAsHours(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';
