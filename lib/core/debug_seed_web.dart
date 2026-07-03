import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import 'providers.dart';

@JS('tomeraSeed')
external set _tomeraSeed(JSFunction f);

@JS('tomeraSeedResult')
external set _tomeraSeedResult(JSString value);

/// Debug-web-only hook: `window.tomeraSeed()` seeds a workspace, a contact,
/// and two notes if the database is empty. Exists because browser-automation
/// tooling cannot reliably type into Flutter web text fields; only installed
/// from main() when kDebugMode && kIsWeb.
void installDebugSeedHook(ProviderContainer container) {
  _tomeraSeed = (() {
    unawaited(_seed(container).then(
      (_) => _tomeraSeedResult = 'ok'.toJS,
      onError: (Object error, StackTrace stack) =>
          _tomeraSeedResult = '$error\n$stack'.toJS,
    ));
  }).toJS;
}

/// Idempotent per entity kind: preview browser profiles are sometimes
/// reused, so a partially seeded database must be topped up, not skipped.
Future<void> _seed(ProviderContainer container) async {
  final workspaces = container.read(workspaceRepositoryProvider);
  final existing = await workspaces.watchAll().first;
  final workspaceId = existing.isNotEmpty
      ? existing.first.id
      : await workspaces.create(
          name: 'DEV',
          color: 0xFF00696B,
          icon: 'code',
          enabledModules: {...ModuleKey.values},
        );

  final projects = container.read(projectRepositoryProvider);
  if ((await projects.watchAll().first).isEmpty) {
    await projects.create(
      workspaceId: workspaceId,
      name: 'Math 101',
      description: 'Autumn lecture course',
    );
  }

  final contacts = container.read(contactRepositoryProvider);
  if ((await contacts.watchAll().first).isEmpty) {
    await contacts.create(name: 'Anna Client', defaultHourlyRateCents: 6500);
  }

  final notes = container.read(noteRepositoryProvider);
  if ((await notes.watchAll().first).isEmpty) {
    await notes.create(title: 'Meeting notes', body: 'discussed invoicing');
    await notes.create(title: 'Groceries', body: 'milk and bread');
  }
}
