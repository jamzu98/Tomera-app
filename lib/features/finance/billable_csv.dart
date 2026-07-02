import '../../core/money.dart';
import '../../data/db/database.dart';
import 'billable_math.dart';

/// RFC-4180-style field escaping: quote when the value contains a comma,
/// quote, or newline; double any inner quotes.
String csvEscape(String value) {
  if (value.contains(RegExp(r'[",\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

const csvHeader = 'workspace,contact,type,title,description,rate,'
    'duration_minutes,amount,total,currency,status,created_at';

/// CSV of billable items (spec §6.6). [workspaceName]/[contactName] resolve
/// ids to display names; money columns are decimal euros.
String billablesToCsv(
  List<BillableItem> items, {
  required String Function(String workspaceId) workspaceName,
  required String Function(String? contactId) contactName,
}) {
  final buffer = StringBuffer(csvHeader)..write('\r\n');
  for (final item in items) {
    final total = billableTotalCents(
      type: item.type,
      rateCents: item.rateCents,
      durationMinutes: item.durationMinutes,
      amountCents: item.amountCents,
    );
    final fields = [
      workspaceName(item.workspaceId),
      contactName(item.contactId),
      item.type.dbValue,
      item.title,
      item.description ?? '',
      item.rateCents != null ? formatCents(item.rateCents!) : '',
      item.durationMinutes?.toString() ?? '',
      item.amountCents != null ? formatCents(item.amountCents!) : '',
      formatCents(total),
      item.currency,
      item.status.dbValue,
      DateTime.fromMillisecondsSinceEpoch(item.createdAt, isUtc: true)
          .toIso8601String(),
    ];
    buffer
      ..write(fields.map(csvEscape).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}
