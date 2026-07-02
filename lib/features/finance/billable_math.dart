import '../../data/db/enums.dart';

/// Computed total of a billable item in integer cents (spec §4):
/// hourly → rate × duration ÷ 60 (rounded half-up to the cent),
/// fixed → amount. Missing components count as zero.
int billableTotalCents({
  required BillableType type,
  int? rateCents,
  int? durationMinutes,
  int? amountCents,
}) =>
    switch (type) {
      BillableType.hourly =>
        ((rateCents ?? 0) * (durationMinutes ?? 0) + 30) ~/ 60,
      BillableType.fixed => amountCents ?? 0,
    };

/// Per-status totals for a set of billables, in cents.
typedef BillableTotals = ({int unbilled, int invoiced, int paid});

BillableTotals sumBillableTotals(
    Iterable<({BillableType type, BillableStatus status, int? rateCents, int? durationMinutes, int? amountCents})>
        items) {
  var unbilled = 0, invoiced = 0, paid = 0;
  for (final item in items) {
    final total = billableTotalCents(
      type: item.type,
      rateCents: item.rateCents,
      durationMinutes: item.durationMinutes,
      amountCents: item.amountCents,
    );
    switch (item.status) {
      case BillableStatus.unbilled:
        unbilled += total;
      case BillableStatus.invoiced:
        invoiced += total;
      case BillableStatus.paid:
        paid += total;
    }
  }
  return (unbilled: unbilled, invoiced: invoiced, paid: paid);
}
