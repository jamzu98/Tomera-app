import 'dart:convert';

import 'package:drift/drift.dart';

import 'enums.dart';

/// Maps a [DbEnum] to its stable string representation.
class DbEnumConverter<T extends DbEnum> extends TypeConverter<T, String> {
  const DbEnumConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) => values.firstWhere((v) => v.dbValue == fromDb);

  @override
  String toSql(T value) => value.dbValue;
}

/// Stores a set of module keys as a JSON array of strings.
class ModuleSetConverter extends TypeConverter<Set<ModuleKey>, String> {
  const ModuleSetConverter();

  @override
  Set<ModuleKey> fromSql(String fromDb) => (jsonDecode(fromDb) as List<dynamic>)
      .map((e) => ModuleKey.values.firstWhere((m) => m.dbValue == e))
      .toSet();

  @override
  String toSql(Set<ModuleKey> value) =>
      jsonEncode([for (final m in ModuleKey.values) if (value.contains(m)) m.dbValue]);
}
