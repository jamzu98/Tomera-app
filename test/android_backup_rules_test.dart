import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedIncludes = <String>{
    'root:app_flutter/tomera.sqlite',
    'sharedpref:FlutterSharedPreferences.xml',
  };

  test(
    'Android 11 backup rules require encryption and only allow app data',
    () {
      final rules = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();

      expect(rules, contains('<full-backup-content>'));
      final includes = _includeAttributes(rules);
      expect(includes, hasLength(expectedIncludes.length));
      expect(includes.map(_domainAndPath).toSet(), expectedIncludes);
      expect(
        includes.map((attributes) => attributes['requireFlags']).toSet(),
        const {'clientSideEncryption'},
      );
    },
  );

  test(
    'Android 12 rules encrypt cloud backup and allow-list both transports',
    () {
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      final cloud = _section(rules, 'cloud-backup');
      final transfer = _section(rules, 'device-transfer');
      expect(
        _openingTag(rules, 'cloud-backup'),
        contains('disableIfNoEncryptionCapabilities="true"'),
      );
      expect(_includeAttributes(cloud), hasLength(expectedIncludes.length));
      expect(
        _includeAttributes(cloud).map(_domainAndPath).toSet(),
        expectedIncludes,
      );
      expect(_includeAttributes(transfer), hasLength(expectedIncludes.length));
      expect(
        _includeAttributes(transfer).map(_domainAndPath).toSet(),
        expectedIncludes,
      );
    },
  );

  test('manifest enables and wires both Android backup rule formats', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="true"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });
}

List<Map<String, String>> _includeAttributes(String xml) => RegExp(
  r'<include\s+([^>]*)/?>',
  multiLine: true,
).allMatches(xml).map((match) => _attributes(match.group(1)!)).toList();

Map<String, String> _attributes(String source) => {
  for (final match in RegExp(r'([A-Za-z]+)="([^"]*)"').allMatches(source))
    match.group(1)!: match.group(2)!,
};

String _domainAndPath(Map<String, String> attributes) =>
    '${attributes['domain']}:${attributes['path']}';

String _section(String xml, String name) =>
    RegExp('<$name[^>]*>([\\s\\S]*?)</$name>').firstMatch(xml)!.group(1)!;

String _openingTag(String xml, String name) =>
    RegExp('<$name[^>]*>').firstMatch(xml)!.group(0)!;
