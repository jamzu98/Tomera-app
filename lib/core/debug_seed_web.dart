import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import 'providers.dart';

@JS('tomeraSeed')
external set _tomeraSeed(JSFunction f);

/// Debug-web-only hook: `window.tomeraSeed()` seeds a workspace, a contact,
/// and two notes if the database is empty. Exists because browser-automation
/// tooling cannot reliably type into Flutter web text fields; only installed
/// from main() when kDebugMode && kIsWeb.
void installDebugSeedHook(ProviderContainer container) {
  _tomeraSeed = (() {
    unawaited(_seed(container));
  }).toJS;
}

Future<void> _seed(ProviderContainer container) async {
  final workspaces = container.read(workspaceRepositoryProvider);
  if ((await workspaces.watchAll().first).isNotEmpty) return;
  final workspaceId = await workspaces.create(
    name: 'DEV',
    color: 0xFF00696B,
    icon: 'code',
    enabledModules: {...ModuleKey.values},
  );
  await container.read(projectRepositoryProvider).create(
        workspaceId: workspaceId,
        name: 'Math 101',
        description: 'Autumn lecture course',
      );
  await container.read(contactRepositoryProvider).create(
        name: 'Anna Client',
        defaultHourlyRateCents: 6500,
      );
  final notes = container.read(noteRepositoryProvider);
  await notes.create(title: 'Meeting notes', body: 'discussed invoicing');
  await notes.create(title: 'Groceries', body: 'milk and bread');
}
