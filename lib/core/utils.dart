import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Client-side UUID v4, used as the primary key for every row (spec §5).
String newId() => _uuid.v4();

/// Current time as UTC epoch milliseconds — the only timestamp format the
/// data layer stores. Convert to local time in the UI only.
int utcNowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
