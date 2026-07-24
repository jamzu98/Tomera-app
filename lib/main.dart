import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/debug_seed_stub.dart'
    if (dart.library.js_interop) 'core/debug_seed_web.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/app_localizations.dart';
import 'sync/sync_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  configureInitialDataProfile(preferences.getString('account.activeProfileId'));
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  final container = ProviderContainer();
  if (kDebugMode && kIsWeb) installDebugSeedHook(container);
  try {
    await container.read(eventRepositoryProvider).refreshRecurrenceHorizon();
  } on Object {
    // A later resume retries horizon maintenance; launch remains available.
  }
  if (!kIsWeb) {
    // Android Auto Backup intentionally excludes notification plugin state.
    // Rebuild it from the restored database before mutable UI is available,
    // preventing a cold-start reconciliation from racing a quick user edit.
    try {
      await container.read(reminderCoordinatorProvider).reconcileFromDatabase();
    } on Object {
      // Device notification state can be repaired on the next cold start;
      // a temporarily unavailable OS service must not prevent app launch.
    }
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const TomeraApp()),
  );
}

class TomeraApp extends ConsumerStatefulWidget {
  const TomeraApp({super.key});

  @override
  ConsumerState<TomeraApp> createState() => _TomeraAppState();
}

class _TomeraAppState extends ConsumerState<TomeraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshRecurrence());
      unawaited(ref.read(syncCoordinatorProvider.notifier).syncNow());
    }
  }

  Future<void> _refreshRecurrence() async {
    try {
      final inserted = await ref
          .read(eventRepositoryProvider)
          .refreshRecurrenceHorizon();
      if (!kIsWeb) {
        await ref
            .read(reminderCoordinatorProvider)
            .syncMaterializedEventReminders(
              inserted.values.expand((ids) => ids),
            );
      }
    } on Object {
      // Maintenance is idempotent and retried on the next resume.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncCoordinatorProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeSettingProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
