import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/today/today_providers.dart';
import 'package:tomera/features/today/today_screen.dart';
import 'package:tomera/l10n/app_localizations.dart';

void main() {
  testWidgets('a failed Today section does not blank healthy sections', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final note = Note(
      id: 'note-1',
      createdAt: 1,
      updatedAt: 2,
      isDirty: false,
      title: 'Healthy note section',
      body: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allWorkspacesProvider.overrideWith((ref) => Stream.value([])),
          todayActiveTimerProvider.overrideWith((ref) => Stream.value(null)),
          todayRecoverableTimerSessionsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          todayEventProvider.overrideWith(
            (ref) => Stream.error(StateError('calendar unavailable')),
          ),
          todayTasksProvider.overrideWith((ref) => Stream.value([])),
          todayUnbilledSummaryProvider.overrideWith(
            (ref) => Stream.value(UnbilledSummary.empty),
          ),
          todayRecentNotesProvider.overrideWith((ref) => Stream.value([note])),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Try again in a moment.'), findsOneWidget);
    final noteFinder = find.text('Healthy note section');
    await tester.scrollUntilVisible(
      noteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(noteFinder, findsOneWidget);
  });
}
