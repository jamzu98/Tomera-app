import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/core/widgets/more_options_section.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/calendar/event_edit_screen.dart';
import 'package:tomera/features/contacts/contact_edit_screen.dart';
import 'package:tomera/features/finance/billable_edit_screen.dart';
import 'package:tomera/features/notes/note_edit_screen.dart';
import 'package:tomera/features/projects/add_instances_screen.dart';
import 'package:tomera/features/projects/project_edit_screen.dart';
import 'package:tomera/features/tasks/task_edit_screen.dart';
import 'package:tomera/features/workspaces/workspace_edit_screen.dart';
import 'package:tomera/l10n/app_localizations.dart';

Workspace _workspace() => Workspace(
  id: 'workspace-1',
  createdAt: 1,
  updatedAt: 1,
  isDirty: false,
  name: 'Studio',
  color: 0xFF7C7FF2,
  icon: 'work',
  enabledModules: {...ModuleKey.values},
  sortOrder: 0,
);

Widget _app(Widget editor, AppDatabase db) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWith((ref) => db),
    notificationServiceProvider.overrideWith(
      (ref) => const NoopNotificationService(),
    ),
    allWorkspacesProvider.overrideWith((ref) => Stream.value([_workspace()])),
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
    initialRoute: '/editor',
    routes: {
      '/': (_) => const Scaffold(body: Text('Home')),
      '/editor': (_) => editor,
    },
  ),
);

void main() {
  final editors = <({String name, Widget screen})>[
    (name: 'task', screen: const TaskEditScreen()),
    (name: 'event', screen: const EventEditScreen()),
    (name: 'note', screen: const NoteEditScreen()),
    (name: 'billable', screen: const BillableEditScreen()),
    (name: 'contact', screen: const ContactEditScreen()),
    (name: 'project', screen: const ProjectEditScreen()),
    (name: 'workspace', screen: const WorkspaceEditScreen()),
  ];

  for (final editor in editors) {
    testWidgets('${editor.name} editor confirms before discarding changes', (
      tester,
    ) async {
      final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      addTearDown(db.close);
      await tester.pumpWidget(_app(editor.screen, db));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Changed');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byWidget(editor.screen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  }

  testWidgets('reverting a task field to its baseline does not warn', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await tester.pumpWidget(_app(const TaskEditScreen(), db));
    await tester.pumpAndSettle();

    final title = find.byType(TextFormField).first;
    await tester.enterText(title, 'Changed');
    await tester.pump();
    await tester.enterText(title, '');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('more options is collapsed by default and can be disclosed', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: MoreOptionsSection(children: [Text('Optional field')]),
        ),
        db,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('More options'), findsOneWidget);
    expect(find.text('Optional field'), findsNothing);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Optional field'), findsOneWidget);
  });

  testWidgets('prefilled more options starts expanded', (tester) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: MoreOptionsSection(
            initiallyExpanded: true,
            children: [Text('Prefilled field')],
          ),
        ),
        db,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prefilled field'), findsOneWidget);
  });

  testWidgets('add instances confirms before discarding changes', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await db.workspaceDao.insertWorkspace(
      WorkspacesCompanion.insert(
        id: 'workspace-1',
        createdAt: 1,
        updatedAt: 1,
        name: 'Studio',
        color: 0xFF7C7FF2,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      ),
    );
    await db.projectDao.insertProject(
      ProjectsCompanion.insert(
        id: 'project-1',
        createdAt: 1,
        updatedAt: 1,
        workspaceId: 'workspace-1',
        name: 'Course',
      ),
    );
    await tester.pumpWidget(
      _app(const AddInstancesScreen(projectId: 'project-1'), db),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Changed course');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('task editor offers due-date shortcuts', (tester) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await tester.pumpWidget(_app(const TaskEditScreen(), db));
    await tester.pumpAndSettle();

    final tomorrowChip = find.widgetWithText(ActionChip, 'Tomorrow');
    await tester.scrollUntilVisible(
      tomorrowChip,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -140));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(tomorrowChip);
    await tester.pump();

    expect(find.text(DateFormat.yMMMEd().format(tomorrow)), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Today'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Next Monday'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('saving a dirty task exits without a discard prompt', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await db.workspaceDao.insertWorkspace(
      WorkspacesCompanion.insert(
        id: 'workspace-1',
        createdAt: 1,
        updatedAt: 1,
        name: 'Studio',
        color: 0xFF7C7FF2,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      ),
    );
    await tester.pumpWidget(_app(const TaskEditScreen(), db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Ship release');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
