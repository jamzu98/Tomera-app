/// Money helpers. All amounts are integer cents (spec §4) — these convert
/// between cents and human-entered/display text only at the UI edge.
library;

/// Parses text like "12.34", "12,34", "12" into cents. Returns null for
/// invalid input. Negative amounts are rejected.
int? parseCents(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final euros = int.parse(match.group(1)!);
  final centsPart = (match.group(2) ?? '').padRight(2, '0');
  return euros * 100 + int.parse(centsPart);
}

/// Formats cents as "12.34" (no currency symbol, dot separator).
String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}
