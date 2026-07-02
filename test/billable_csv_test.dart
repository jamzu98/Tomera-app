import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/finance/billable_csv.dart';

BillableItem makeItem({
  required String title,
  String? description,
  BillableType type = BillableType.hourly,
  int? rateCents = 6000,
  int? durationMinutes = 90,
  int? amountCents,
}) =>
    BillableItem(
      id: 'b1',
      ownerId: null,
      createdAt: DateTime.utc(2026, 7, 2, 12).millisecondsSinceEpoch,
      updatedAt: 0,
      deletedAt: null,
      isDirty: true,
      workspaceId: 'w1',
      contactId: 'c1',
      eventId: null,
      type: type,
      title: title,
      description: description,
      rateCents: rateCents,
      durationMinutes: durationMinutes,
      amountCents: amountCents,
      currency: 'EUR',
      status: BillableStatus.unbilled,
    );

void main() {
  group('csvEscape', () {
    test('passes plain values through', () {
      expect(csvEscape('hello'), 'hello');
    });

    test('quotes commas, quotes, and newlines', () {
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('say "hi"'), '"say ""hi"""');
      expect(csvEscape('line1\nline2'), '"line1\nline2"');
    });
  });

  group('billablesToCsv', () {
    test('emits header, resolved names, computed total, ISO timestamp', () {
      final csv = billablesToCsv(
        [makeItem(title: 'Consulting')],
        workspaceName: (_) => 'DEV',
        contactName: (_) => 'Anna Client',
      );
      final lines = csv.trim().split('\r\n');
      expect(lines.first, csvHeader);
      expect(
        lines[1],
        'DEV,Anna Client,hourly,Consulting,,60.00,90,,90.00,EUR,unbilled,'
        '2026-07-02T12:00:00.000Z',
      );
    });

    test('escapes tricky fields', () {
      final csv = billablesToCsv(
        [makeItem(title: 'a,b', description: 'said "no"')],
        workspaceName: (_) => 'DEV',
        contactName: (_) => '',
      );
      expect(csv, contains('"a,b"'));
      expect(csv, contains('"said ""no"""'));
    });
  });
}
