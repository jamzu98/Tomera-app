import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/money.dart';
import 'package:tomera/data/db/enums.dart';
import 'package:tomera/features/finance/billable_math.dart';

void main() {
  group('billableTotalCents', () {
    test('hourly: rate × minutes ÷ 60', () {
      expect(
        billableTotalCents(
            type: BillableType.hourly, rateCents: 5000, durationMinutes: 90),
        7500,
      );
    });

    test('hourly rounds half-up to the cent', () {
      // 1 cent/h for 90 min = 1.5 cents → 2.
      expect(
        billableTotalCents(
            type: BillableType.hourly, rateCents: 1, durationMinutes: 90),
        2,
      );
      // 1 cent/h for 89 min = 1.483 → 1.
      expect(
        billableTotalCents(
            type: BillableType.hourly, rateCents: 1, durationMinutes: 89),
        1,
      );
    });

    test('hourly with missing components is zero', () {
      expect(billableTotalCents(type: BillableType.hourly, rateCents: 5000), 0);
      expect(
          billableTotalCents(type: BillableType.hourly, durationMinutes: 60), 0);
    });

    test('fixed uses the amount', () {
      expect(
        billableTotalCents(type: BillableType.fixed, amountCents: 12345),
        12345,
      );
      expect(billableTotalCents(type: BillableType.fixed), 0);
    });
  });

  group('sumBillableTotals', () {
    test('groups totals by status', () {
      final totals = sumBillableTotals([
        (
          type: BillableType.hourly,
          status: BillableStatus.unbilled,
          rateCents: 6000,
          durationMinutes: 60,
          amountCents: null,
        ),
        (
          type: BillableType.fixed,
          status: BillableStatus.unbilled,
          rateCents: null,
          durationMinutes: null,
          amountCents: 1000,
        ),
        (
          type: BillableType.fixed,
          status: BillableStatus.invoiced,
          rateCents: null,
          durationMinutes: null,
          amountCents: 2500,
        ),
        (
          type: BillableType.fixed,
          status: BillableStatus.paid,
          rateCents: null,
          durationMinutes: null,
          amountCents: 999,
        ),
      ]);
      expect(totals.unbilled, 7000);
      expect(totals.invoiced, 2500);
      expect(totals.paid, 999);
    });
  });

  group('parseCents', () {
    test('accepts euros with dot, comma, or no decimals', () {
      expect(parseCents('12.34'), 1234);
      expect(parseCents('12,34'), 1234);
      expect(parseCents('12'), 1200);
      expect(parseCents('12.5'), 1250);
      expect(parseCents(' 7.00 '), 700);
      expect(parseCents('0.01'), 1);
    });

    test('rejects invalid input', () {
      expect(parseCents(''), isNull);
      expect(parseCents('abc'), isNull);
      expect(parseCents('12.345'), isNull);
      expect(parseCents('-5'), isNull);
      expect(parseCents('1.2.3'), isNull);
    });
  });

  group('formatCents', () {
    test('formats with two decimals', () {
      expect(formatCents(1234), '12.34');
      expect(formatCents(700), '7.00');
      expect(formatCents(1), '0.01');
      expect(formatCents(-1234), '-12.34');
    });

    test('round-trips with parseCents', () {
      for (final cents in [0, 1, 99, 100, 12345]) {
        expect(parseCents(formatCents(cents)), cents);
      }
    });
  });
}
