import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/finance/finance_providers.dart';
import 'package:tomera/features/finance/finance_screen.dart';
import 'package:tomera/features/finance/recoverable_timer_list.dart';
import 'package:tomera/features/finance/timer_card.dart';
import 'package:tomera/features/finance/timer_session_detail_screen.dart';
import 'package:tomera/features/notes/note_edit_screen.dart';
import 'package:tomera/features/today/today_providers.dart';
import 'package:tomera/l10n/app_localizations.dart';

Widget _testApp(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildLightTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

Widget _routerTestApp(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildLightTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

ProviderContainer _container(AppDatabase db) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) => db),
    notificationServiceProvider.overrideWith(
      (ref) => const NoopNotificationService(),
    ),
  ],
);

Future<void> _pumpStreams(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<String> _workspace(ProviderContainer container, String name) => container
    .read(workspaceRepositoryProvider)
    .create(
      name: name,
      color: 0xFF445566,
      icon: 'work',
      enabledModules: {...ModuleKey.values},
      defaultHourlyRateCents: 5000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('timer session detail exposes recovery then converted billable', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final workspaceId = await _workspace(container, 'Studio');
    await container
        .read(timerRepositoryProvider)
        .start(
          workspaceId: workspaceId,
          description: 'Implementation',
          notificationTitle: 'Implementation',
        );
    final running = await container.read(timerRepositoryProvider).getRunning();
    await container.read(timerRepositoryProvider).stop(running!);
    final stopped = await container
        .read(timerRepositoryProvider)
        .getById(running.id);

    await tester.pumpWidget(
      _testApp(container, TimerSessionDetailScreen(timerId: running.id)),
    );
    await _pumpStreams(tester);

    expect(find.text('Timer session'), findsOneWidget);
    expect(find.text('Implementation'), findsWidgets);
    expect(find.text('Convert to billable'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => container
          .read(billableRepositoryProvider)
          .createFromTimer(session: stopped!, title: 'Implementation'),
    );
    await tester.pumpWidget(
      _testApp(container, TimerSessionDetailScreen(timerId: running.id)),
    );
    await _pumpStreams(tester);

    expect(find.text('Convert to billable'), findsNothing);
    expect(find.text('Unbilled'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('recoverable timer swipes to trash and can be restored', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final workspaceId = await _workspace(container, 'Studio');
    await container
        .read(timerRepositoryProvider)
        .start(
          workspaceId: workspaceId,
          description: 'Discard me',
          notificationTitle: 'Discard me',
        );
    final running = await container.read(timerRepositoryProvider).getRunning();
    await container.read(timerRepositoryProvider).stop(running!);

    await tester.pumpWidget(
      _testApp(
        container,
        Consumer(
          builder: (context, ref, child) {
            final sessions = ref.watch(recoverableTimerSessionsProvider);
            return sessions.when(
              data: (items) => RecoverableTimerList(sessions: items),
              error: (error, stackTrace) => Text('$error'),
              loading: () => const CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
    await _pumpStreams(tester);

    expect(find.text('Discard me'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await _pumpStreams(tester);

    expect(find.text('Discard me'), findsNothing);
    expect(find.text('Unconverted time removed.'), findsOneWidget);
    expect(
      await container.read(timerRepositoryProvider).getById(running.id),
      isNull,
    );

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await _pumpStreams(tester);

    expect(find.text('Discard me'), findsOneWidget);
    expect(
      await container.read(timerRepositoryProvider).getById(running.id),
      isNotNull,
    );
  });

  testWidgets('timer detail offers confirmed removal', (tester) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final workspaceId = await _workspace(container, 'Studio');
    await container
        .read(timerRepositoryProvider)
        .start(
          workspaceId: workspaceId,
          description: 'Remove from detail',
          notificationTitle: 'Remove from detail',
        );
    final session = await container.read(timerRepositoryProvider).getRunning();
    await container.read(timerRepositoryProvider).stop(session!);

    final router = GoRouter(
      initialLocation: '/finance/timers/${session.id}',
      routes: [
        GoRoute(
          path: '/finance',
          builder: (context, state) => const Scaffold(body: Text('Finance')),
          routes: [
            GoRoute(
              path: 'timers/:timerId',
              builder: (context, state) => TimerSessionDetailScreen(
                timerId: state.pathParameters['timerId']!,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerTestApp(container, router));
    await _pumpStreams(tester);

    final removeButton = find.byTooltip('Remove unconverted time');
    expect(removeButton, findsOneWidget);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('Remove unconverted time?'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Remove unconverted time'),
    );
    await _pumpStreams(tester);

    expect(find.text('Finance'), findsOneWidget);
    expect(
      await container.read(timerRepositoryProvider).getById(session.id),
      isNull,
    );
  });

  testWidgets('Finance uses one scroll for unconverted and billable content', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final workspaceId = await _workspace(container, 'Studio');
    for (var i = 0; i < 4; i++) {
      await container
          .read(timerRepositoryProvider)
          .start(
            workspaceId: workspaceId,
            description: 'Session $i',
            notificationTitle: 'Session $i',
          );
      final running = await container
          .read(timerRepositoryProvider)
          .getRunning();
      await container.read(timerRepositoryProvider).stop(running!);
    }

    await tester.pumpWidget(_testApp(container, const FinanceScreen()));
    await _pumpStreams(tester);

    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    final actionRect = tester.getRect(find.text('New billable item'));
    expect(actionRect.top, greaterThanOrEqualTo(0));
    expect(actionRect.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer detail Add note opens editor with a timer reference', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final workspaceId = await _workspace(container, 'Studio');
    await container
        .read(timerRepositoryProvider)
        .start(
          workspaceId: workspaceId,
          description: 'Implementation',
          notificationTitle: 'Implementation',
        );
    final session = await container.read(timerRepositoryProvider).getRunning();
    await container.read(timerRepositoryProvider).stop(session!);

    final router = GoRouter(
      initialLocation: '/finance/timers/${session.id}',
      routes: [
        GoRoute(
          path: '/finance/timers/:timerId',
          builder: (context, state) => TimerSessionDetailScreen(
            timerId: state.pathParameters['timerId']!,
          ),
        ),
        GoRoute(
          path: '/work/notes/new',
          builder: (context, state) => NoteEditScreen(
            initialWorkspaceId: state.uri.queryParameters['workspaceId'],
            parentType: state.uri.queryParameters['parentType'],
            parentId: state.uri.queryParameters['parentId'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerTestApp(container, router));
    await _pumpStreams(tester);
    await tester.scrollUntilVisible(
      find.text('Add note'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.text('Add note'));
    await _pumpStreams(tester);

    expect(find.byType(NoteEditScreen), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    expect(find.byType(InputChip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.text('Implementation'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'recoverable timer conversion is project-aware and duplicate-safe',
    (tester) async {
      final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      final container = _container(db);
      final workspaceId = await _workspace(container, 'Studio');
      final projectId = await container
          .read(projectRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            name: 'Launch',
            hourlyRateCents: 7500,
          );
      await container
          .read(timerRepositoryProvider)
          .start(
            workspaceId: workspaceId,
            projectId: projectId,
            description: 'Implementation',
            notificationTitle: 'Implementation',
          );
      final running = await container
          .read(timerRepositoryProvider)
          .getRunning();
      await container.read(timerRepositoryProvider).stop(running!);
      final stopped = await container
          .read(timerRepositoryProvider)
          .getById(running.id);

      await tester.pumpWidget(
        _testApp(
          container,
          Consumer(
            builder: (context, ref, child) {
              final sessions = ref.watch(recoverableTimerSessionsProvider);
              return sessions.when(
                data: (items) => RecoverableTimerList(sessions: items),
                error: (error, stackTrace) => Text('$error'),
                loading: () => const CircularProgressIndicator(),
              );
            },
          ),
        ),
      );
      await _pumpStreams(tester);

      expect(find.text('Implementation'), findsOneWidget);
      expect(find.textContaining('Launch'), findsOneWidget);
      await tester.tap(find.text('Convert to billable'));
      await _pumpStreams(tester);

      await tester.runAsync(() async {
        final items = await container
            .read(billableRepositoryProvider)
            .watchAll()
            .first;
        expect(items, hasLength(1));
        expect(items.single.timerSessionId, running.id);
        expect(items.single.projectId, projectId);
        expect(items.single.rateCents, 7500);

        final retryId = await container
            .read(billableRepositoryProvider)
            .createFromTimer(session: stopped!, title: 'Retry');
        expect(retryId, items.single.id);
        expect(
          await container.read(billableRepositoryProvider).watchAll().first,
          hasLength(1),
        );
      });

      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 10));
    },
  );

  testWidgets('start timer sheet preserves project creation context', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    final workspaceId = await _workspace(container, 'Studio');
    final projectId = await container
        .read(projectRepositoryProvider)
        .create(workspaceId: workspaceId, name: 'Launch');

    await tester.pumpWidget(
      _testApp(
        container,
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showStartTimerSheet(
              context,
              workspaceId: workspaceId,
              projectId: projectId,
            ),
            child: const Text('Open timer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open timer'));
    await _pumpStreams(tester);

    expect(find.text('Launch'), findsOneWidget);
    await tester.tap(find.text('Start timer').last);
    await _pumpStreams(tester);
    expect(
      (await container.read(timerRepositoryProvider).getRunning())?.projectId,
      projectId,
    );

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  test(
    'Today recovery provider follows workspace finance visibility',
    () async {
      final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      final container = _container(db);
      addTearDown(container.dispose);
      final visibleId = await _workspace(container, 'Visible');
      final hiddenId = await container
          .read(workspaceRepositoryProvider)
          .create(
            name: 'Hidden',
            color: 0xFF999999,
            icon: 'work',
            enabledModules: {ModuleKey.tasks},
          );
      final workspaceListener = container.listen(
        allWorkspacesProvider,
        (previous, next) {},
      );
      addTearDown(workspaceListener.close);
      await container.read(allWorkspacesProvider.future);

      for (final workspaceId in [visibleId, hiddenId]) {
        await container
            .read(timerRepositoryProvider)
            .start(workspaceId: workspaceId, notificationTitle: 'Timer');
        final session = await container
            .read(timerRepositoryProvider)
            .getRunning();
        await container.read(timerRepositoryProvider).stop(session!);
      }

      final listener = container.listen(
        todayRecoverableTimerSessionsProvider,
        (previous, next) {},
      );
      addTearDown(listener.close);
      expect(
        (await container.read(
          todayRecoverableTimerSessionsProvider.future,
        )).map((session) => session.workspaceId),
        [visibleId],
      );

      container.read(selectedWorkspaceIdProvider.notifier).select(hiddenId);
      expect(
        await container.read(todayRecoverableTimerSessionsProvider.future),
        isEmpty,
      );
    },
  );
}
