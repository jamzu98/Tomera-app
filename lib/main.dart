import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug_seed_stub.dart'
    if (dart.library.js_interop) 'core/debug_seed_web.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/app_localizations.dart';

void main() {
  final container = ProviderContainer();
  if (kDebugMode && kIsWeb) installDebugSeedHook(container);
  runApp(UncontrolledProviderScope(
    container: container,
    child: const TomeraApp(),
  ));
}

class TomeraApp extends ConsumerWidget {
  const TomeraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
