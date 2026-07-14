import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/core/widgets/financial_summary_card.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/connected/connected_timeline.dart';
import 'package:tomera/features/connected/connected_timeline_section.dart';
import 'package:tomera/features/contacts/contact_edit_screen.dart';
import 'package:tomera/features/notes/note_edit_screen.dart';
import 'package:tomera/features/tasks/task_edit_screen.dart';
import 'package:tomera/l10n/app_localizations.dart';

Widget _app(Widget screen, AppDatabase db) => ProviderScope(
  overrides: [
    appDatabaseProvider.overrideWith((ref) => db),
    notificationServiceProvider.overrideWith(
      (ref) => const NoopNotificationService(),
    ),
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
      '/editor': (_) => screen,
    },
  ),
);

Future<void> _insertWorkspace(AppDatabase db) =>
    db.workspaceDao.insertWorkspace(
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

Future<void> _insertProject(AppDatabase db) => db.projectDao.insertProject(
  ProjectsCompanion.insert(
    id: 'project-1',
    createdAt: 2,
    updatedAt: 2,
    workspaceId: 'workspace-1',
    name: 'Project Alpha',
  ),
);

Future<void> _pumpStreams(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('note editor reparents and saves typed reference chips', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await _insertWorkspace(db);
    await _insertProject(db);
    await db.taskDao.insertTask(
      TasksCompanion.insert(
        id: 'task-1',
        createdAt: 3,
        updatedAt: 3,
        workspaceId: 'workspace-1',
        title: 'Task Alpha',
      ),
    );
    await db.noteDao.insertNote(
      NotesCompanion.insert(
        id: 'note-1',
        createdAt: 4,
        updatedAt: 4,
        workspaceId: const Value('workspace-1'),
        title: 'Meeting notes',
        body: 'Follow up',
      ),
    );

    await tester.pumpWidget(_app(const NoteEditScreen(noteId: 'note-1'), db));
    await _pumpStreams(tester);

    await tester.tap(find.text('No parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project · Project Alpha').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task Alpha').last);
    await tester.pumpAndSettle();
    expect(find.text('Task Alpha'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final note = await db.noteDao.getById('note-1');
    expect(note?.parentType, ParentType.project);
    expect(note?.parentId, 'project-1');
    final links = await db.select(db.noteLinks).get();
    expect(links, hasLength(1));
    expect(links.single.targetType, ParentType.task);
    expect(links.single.targetId, 'task-1');
  });

  testWidgets('task created from selected note context writes backlink', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await _insertWorkspace(db);
    await db.noteDao.insertNote(
      NotesCompanion.insert(
        id: 'note-1',
        createdAt: 2,
        updatedAt: 2,
        workspaceId: const Value('workspace-1'),
        title: 'Source note',
        body: 'Ship the release',
      ),
    );

    await tester.pumpWidget(
      _app(
        const TaskEditScreen(
          initialWorkspaceId: 'workspace-1',
          initialTitle: 'Ship the release',
          sourceNoteId: 'note-1',
        ),
        db,
      ),
    );
    await _pumpStreams(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final tasks = await db.select(db.tasks).get();
    expect(tasks.single.title, 'Ship the release');
    final links = await db.select(db.noteLinks).get();
    expect(links.single.noteId, 'note-1');
    expect(links.single.targetType, ParentType.task);
    expect(links.single.targetId, tasks.single.id);
  });

  testWidgets('typed activity and currency cards render independently', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ConnectedTimelineSection(
                activities: [
                  ConnectedActivity(
                    type: ConnectedActivityType.completedTask,
                    id: 'task-1',
                    title: 'Completed work',
                    timestamp: 30,
                    route: '/work/tasks/task-1',
                  ),
                ],
              ),
              FinancialSummaryCard(
                currency: 'EUR',
                rows: [('Unbilled', 1000, false)],
              ),
              SizedBox(height: 8),
              FinancialSummaryCard(
                currency: 'USD',
                rows: [('Unbilled', 500, false)],
              ),
            ],
          ),
        ),
        db,
      ),
    );
    await _pumpStreams(tester);

    expect(find.byType(ConnectedTimelineSection), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Completed work'), findsOneWidget);
    expect(find.byType(FinancialSummaryCard), findsNWidgets(2));
    expect(find.text('10.00 EUR'), findsWidgets);
    expect(find.text('5.00 USD'), findsWidgets);
  });

  testWidgets('contact editor persists a workspace-specific rate', (
    tester,
  ) async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await _insertWorkspace(db);
    await db.contactDao.insertContact(
      ContactsCompanion.insert(
        id: 'contact-1',
        createdAt: 2,
        updatedAt: 2,
        name: 'Ada',
      ),
    );
    await db.contactDao.upsertRole('contact-1', 'workspace-1', 'Client');

    await tester.pumpWidget(
      _app(const ContactEditScreen(contactId: 'contact-1'), db),
    );
    await _pumpStreams(tester);

    final rate = find.widgetWithText(TextFormField, 'Workspace rate (€)');
    await tester.scrollUntilVisible(
      rate,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(rate, '75.00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final roles = await db.contactDao.getRoles('contact-1');
    expect(roles.single.hourlyRateCents, 7500);
  });
}
