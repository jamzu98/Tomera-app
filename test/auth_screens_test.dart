import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/auth/auth_providers.dart';
import 'package:tomera/features/auth/auth_screens.dart';
import 'package:tomera/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('local account choice persists for later launches', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(accountControllerProvider.future);
    await first.read(accountControllerProvider.notifier).chooseLocal();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(accountControllerProvider.future);
    expect(restored.accountChoiceComplete, isTrue);
    expect(restored.mode, AccountMode.local);
  });

  testWidgets('email signup validates email and password before auth', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmailAuthScreen(initialSignUp: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsWidgets);

    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsWidgets);
  });
}
