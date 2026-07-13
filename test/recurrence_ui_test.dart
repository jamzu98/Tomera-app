import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/recurrence/recurrence_models.dart';
import 'package:tomera/data/recurrence/recurrence_rule.dart';
import 'package:tomera/features/calendar/event_edit_screen.dart';
import 'package:tomera/features/recurrence/recurrence_editor.dart';
import 'package:tomera/features/tasks/task_edit_screen.dart';
import 'package:tomera/l10n/app_localizations.dart';

Widget _app(Widget home, {ProviderContainer? container}) {
  final app = MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

ProviderContainer _container(AppDatabase db) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) => db),
    notificationServiceProvider.overrideWith(
      (ref) => const NoopNotificationService(),
    ),
  ],
);

Future<void> _pumpStreams(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timezoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (_) async => 'UTC');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
  });

  test('all-day recurrence duration uses local calendar days across DST', () {
    expect(
      recurrenceTemplateDuration(
        allDay: true,
        localStart: DateTime(2026, 10, 25),
        localEnd: DateTime(2026, 10, 25),
        startMs: 0,
        endMs: const Duration(hours: 25).inMilliseconds,
      ),
      const Duration(days: 1),
    );
  });

  testWidgets(
    'recurrence editor exposes custom rule and task anchor controls',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var value = RecurrenceEditorValue.disabled();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Form(
              child: ListView(
                children: [
                  StatefulBuilder(
                    builder: (context, setState) => RecurrenceEditor(
                      initialValue: value,
                      showTaskAnchor: true,
                      onChanged: (updated) => setState(() => value = updated),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pump();
      expect(find.text('FREQUENCY'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(7));

      await tester.ensureVisible(
        find.byKey(const ValueKey('recurrence-interval')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('recurrence-interval')),
        '2',
      );
      await tester.tap(find.byType(DropdownButton<RecurrenceEndMode>));
      await tester.pump();
      await tester.tap(find.text('After count').last);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('recurrence-count')),
        '6',
      );
      await tester.tap(find.text('From completion time'));
      await tester.pump();

      expect(value.enabled, isTrue);
      expect(value.rule.interval, 2);
      expect(value.rule.count, 6);
      expect(value.taskAnchor, TaskRepeatAnchor.completion);
    },
  );

  testWidgets('new task creates a repeating series from editor controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    final workspaceId = await container
        .read(workspaceRepositoryProvider)
        .create(
          name: 'Studio',
          color: 0xFF334455,
          icon: 'work',
          enabledModules: {...ModuleKey.values},
        );

    await tester.pumpWidget(
      _app(
        TaskEditScreen(initialWorkspaceId: workspaceId),
        container: container,
      ),
    );
    await _pumpStreams(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Weekly review');
    await tester.tap(find.widgetWithText(ActionChip, 'Today'));
    await tester.pump();
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(true);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _pumpStreams(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Enter a title'), findsNothing);
    expect(
      find.text('Choose a due date before enabling repeat.'),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.runAsync(() async {
      final series = await db.select(db.taskSeriesTable).get();
      final tasks = await db.select(db.tasks).get();
      expect((series.length, tasks.length), (1, 1));
      expect(tasks.single.taskSeriesId, series.single.id);
      expect(tasks.single.title, 'Weekly review');
    });

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('recurring event edit and delete require an explicit scope', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    final workspaceId = await container
        .read(workspaceRepositoryProvider)
        .create(
          name: 'Studio',
          color: 0xFF334455,
          icon: 'work',
          enabledModules: {...ModuleKey.values},
        );
    final creation = await container
        .read(eventRepositoryProvider)
        .createRecurring(
          template: EventSeriesTemplate(
            workspaceId: workspaceId,
            title: 'Stand-up',
            localStartsAt: DateTime.utc(2026, 8, 3, 9),
            duration: const Duration(minutes: 30),
            timezoneId: 'UTC',
          ),
          rule: RecurrenceRule(frequency: RecurrenceFrequency.weekly, count: 2),
          horizonUtcMs: DateTime.utc(2026, 8, 31).millisecondsSinceEpoch,
        );

    await tester.pumpWidget(
      _app(
        EventEditScreen(eventId: creation.occurrenceIds.first),
        container: container,
      ),
    );
    await _pumpStreams(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Edit recurring event'), findsOneWidget);
    expect(find.text('This occurrence'), findsOneWidget);
    expect(find.text('This and future occurrences'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    expect(find.text('Delete recurring event'), findsOneWidget);
    expect(find.text('Delete this occurrence'), findsOneWidget);
    expect(find.text('Delete this and future occurrences'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('recurring event creation warns about a future occurrence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    final workspaceId = await container
        .read(workspaceRepositoryProvider)
        .create(
          name: 'Studio',
          color: 0xFF334455,
          icon: 'work',
          enabledModules: {...ModuleKey.values},
        );
    final initialStartMs = DateTime.utc(2026, 8, 3, 9).millisecondsSinceEpoch;
    final displayed = DateTime.fromMillisecondsSinceEpoch(initialStartMs);
    final recurrenceStart = DateTime.utc(
      displayed.year,
      displayed.month,
      displayed.day,
      displayed.hour,
      displayed.minute,
    );
    final conflictStart = recurrenceStart.add(const Duration(days: 7));
    await container
        .read(eventRepositoryProvider)
        .create(
          workspaceId: workspaceId,
          title: 'Future conflict',
          startsAt: conflictStart.millisecondsSinceEpoch,
          endsAt: conflictStart
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        );

    await tester.pumpWidget(
      _app(
        EventEditScreen(
          initialWorkspaceId: workspaceId,
          initialStartMs: initialStartMs,
        ),
        container: container,
      ),
    );
    await _pumpStreams(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Weekly session');
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(true);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _pumpStreams(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Schedule conflict'), findsOneWidget);
    expect(find.textContaining('Future conflict'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('ended historical event series is occurrence-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = _container(db);
    final workspaceId = await container
        .read(workspaceRepositoryProvider)
        .create(
          name: 'Studio',
          color: 0xFF334455,
          icon: 'work',
          enabledModules: {...ModuleKey.values},
        );
    final repository = container.read(eventRepositoryProvider);
    final creation = await repository.createRecurring(
      template: EventSeriesTemplate(
        workspaceId: workspaceId,
        title: 'Original',
        localStartsAt: DateTime.utc(2026, 9, 1, 9),
        duration: const Duration(hours: 1),
        timezoneId: 'Europe/Helsinki',
      ),
      rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 4),
      horizonUtcMs: DateTime.utc(2026, 9, 10).millisecondsSinceEpoch,
    );
    final rows = <Event>[
      for (final id in creation.occurrenceIds) (await repository.getById(id))!,
    ];
    await repository.updateRecurrence(
      eventId: rows[2].id,
      scope: RecurrenceEditScope.currentAndFuture,
      currentAndFutureTemplate: EventSeriesTemplate(
        workspaceId: workspaceId,
        title: 'Changed',
        localStartsAt: DateTime.utc(2026, 9, 3, 10),
        duration: const Duration(hours: 1),
        timezoneId: 'Europe/Helsinki',
      ),
      currentAndFutureRule: RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 4,
      ),
      horizonUtcMs: DateTime.utc(2026, 9, 10).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      _app(EventEditScreen(eventId: rows.first.id), container: container),
    );
    await _pumpStreams(tester);
    expect(find.text('Time zone: Europe/Helsinki'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('This occurrence'), findsOneWidget);
    expect(find.text('This and future occurrences'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    expect(find.text('Delete this occurrence'), findsOneWidget);
    expect(find.text('Delete this and future occurrences'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });
}
