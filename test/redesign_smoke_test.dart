import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/router.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/data/repositories/billable_repository.dart';
import 'package:tomera/data/repositories/contact_repository.dart';
import 'package:tomera/data/repositories/event_repository.dart';
import 'package:tomera/data/repositories/note_repository.dart';
import 'package:tomera/data/repositories/project_repository.dart';
import 'package:tomera/data/repositories/task_repository.dart';
import 'package:tomera/data/repositories/workspace_repository.dart';
import 'package:tomera/main.dart';

/// Boots the full app against a seeded in-memory database and walks every
/// tab plus the root-level screens, so render exceptions, overflows, and
/// theme-token wiring break the build in both dark and light mode.
Future<({String projectId, String workspaceId})> _seed(AppDatabase db) async {
  final workspaces = WorkspaceRepository(db.workspaceDao);
  final workspaceId = await workspaces.create(
    name: 'Freelance',
    color: 0xFF7C7FF2,
    icon: 'work',
    enabledModules: {...ModuleKey.values},
  );
  final secondWorkspaceId = await workspaces.create(
    name: 'Teaching',
    color: 0xFFE4AB3C,
    icon: 'school',
    enabledModules: {...ModuleKey.values},
  );

  final projectId = await ProjectRepository(db.projectDao).create(
    workspaceId: workspaceId,
    name: 'Website relaunch',
    description: 'Client project',
  );

  final contacts = ContactRepository(db.contactDao);
  final contactId = await contacts.create(
    name: 'Anna Client',
    email: 'anna@example.com',
    phone: '+3712345678',
    organization: 'Acme',
    defaultHourlyRateCents: 6500,
  );
  await contacts.setRole(contactId, workspaceId, 'Client');

  final now = DateTime.now();
  final tasks = TaskRepository(db.taskDao);
  await tasks.create(
    workspaceId: workspaceId,
    title: 'Overdue invoice reminder',
    priority: TaskPriority.high,
    dueAt: now.subtract(const Duration(days: 2)).toUtc().millisecondsSinceEpoch,
    contactId: contactId,
  );
  await tasks.create(
    workspaceId: secondWorkspaceId,
    title: 'Prepare lecture slides',
    dueAt: now.add(const Duration(days: 3)).toUtc().millisecondsSinceEpoch,
    projectId: null,
  );

  final startOfHour = DateTime(now.year, now.month, now.day, 10);
  await EventRepository(db.eventDao).create(
    workspaceId: workspaceId,
    title: 'Design review',
    location: 'Zoom',
    startsAt: startOfHour.toUtc().millisecondsSinceEpoch,
    endsAt: startOfHour
        .add(const Duration(hours: 1))
        .toUtc()
        .millisecondsSinceEpoch,
    projectId: projectId,
  );

  final notes = NoteRepository(db.noteDao);
  await notes.create(
    title: 'Meeting notes',
    body: '# Agenda\n- invoicing\n- **next steps**',
  );

  final billables = BillableRepository(db.billableDao);
  await billables.create(
    workspaceId: workspaceId,
    contactId: contactId,
    projectId: projectId,
    type: BillableType.hourly,
    title: 'Design work',
    rateCents: 6500,
    durationMinutes: 90,
  );
  await billables.create(
    workspaceId: workspaceId,
    contactId: contactId,
    type: BillableType.fixed,
    title: 'Hosting setup',
    amountCents: 12000,
    status: BillableStatus.paid,
  );
  return (projectId: projectId, workspaceId: workspaceId);
}

Future<void> _walkApp(WidgetTester tester, ThemeMode mode) async {
  SharedPreferences.setMockInitialValues({'settings.themeMode': mode.name});
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  await _seed(db);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWith((ref) => db)],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TomeraApp()),
  );
  // Let streams emit and the calendar lay out.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));

  final router = container.read(routerProvider);
  const routes = [
    '/tasks',
    '/notes',
    '/contacts',
    '/finance',
    '/workspaces',
    '/settings',
    '/calendar',
  ];
  for (final route in routes) {
    router.go(route);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Unmount everything so widget-owned timers/animations are disposed.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));

  container.dispose();
  // Disposing drift stream providers schedules zero-duration cleanup timers;
  // pump so they fire before the binding's pending-timer check. The
  // in-memory database is intentionally not closed: drift's close()
  // deadlocks under the test binding's fake-async zone, and the isolate
  // exits right after the test anyway.
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editorial dock reaches all destinations on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'settings.themeMode': ThemeMode.light.name,
    });
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    await _seed(db);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TomeraApp()),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final destinations = <(String, String)>[
      ('Today', '/today'),
      ('Calendar', '/calendar'),
      ('Work', '/work/tasks'),
      ('Contacts', '/contacts'),
      ('Finance', '/finance'),
    ];
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final (index, (label, path)) in destinations.indexed) {
      final destination = find.byWidgetPredicate(
        (widget) => widget is NavigationDestination && widget.label == label,
      );
      expect(destination, findsOneWidget);
      await tester.tap(destination);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        path,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(tester.takeException(), isNull, reason: label);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('all main screens render in dark mode', (tester) async {
    await _walkApp(tester, ThemeMode.dark);
  });

  testWidgets('all main screens render in light mode', (tester) async {
    await _walkApp(tester, ThemeMode.light);
  });

  testWidgets('legacy Work links preserve query for canonical routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    await _seed(db);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TomeraApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final router = container.read(routerProvider);
    router.go('/tasks/new?source=legacy-link');
    await tester.pump(const Duration(milliseconds: 300));

    final location = router.routerDelegate.currentConfiguration.uri;
    expect(location.path, '/work/tasks/new');
    expect(location.queryParameters['source'], 'legacy-link');

    router.go('/notes?query=meeting');
    await tester.pump(const Duration(milliseconds: 300));
    final notesLocation = router.routeInformationProvider.value.uri;
    expect(notesLocation.path, '/work/notes');
    expect(notesLocation.queryParameters['query'], 'meeting');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shell quick-add inherits project route context', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final seed = await _seed(db);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TomeraApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final router = container.read(routerProvider);
    router.go('/work/projects/${seed.projectId}');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Quick add'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final noteActionFinder = find.widgetWithText(ListTile, 'New note');
    final noteAction = tester.widget<ListTile>(noteActionFinder);
    expect(noteAction.enabled, isTrue);
    await tester.tap(noteActionFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Quick add'), findsNothing);
    expect(tester.takeException(), isNull);

    final location = router.routerDelegate.currentConfiguration.uri;
    expect(location.path, '/work/notes/new');
    expect(location.queryParameters['workspaceId'], seed.workspaceId);
    expect(location.queryParameters['projectId'], seed.projectId);
    expect(location.queryParameters['parentType'], 'project');
    expect(location.queryParameters['parentId'], seed.projectId);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('empty databases are gated through first-workspace setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TomeraApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final router = container.read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, '/setup');
    expect(find.text('Set up your first workspace'), findsOneWidget);

    await WorkspaceRepository(db.workspaceDao).create(
      name: 'Studio',
      color: 0xFF7C7FF2,
      icon: 'work',
      enabledModules: {...ModuleKey.values},
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routeInformationProvider.value.uri.path, '/today');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('deleting the last workspace redirects safely to setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final workspaceId = await WorkspaceRepository(db.workspaceDao).create(
      name: 'Only workspace',
      color: 0xFF7C7FF2,
      icon: 'work',
      enabledModules: {...ModuleKey.values},
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) => db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TomeraApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final router = container.read(routerProvider);
    router.go('/workspaces/$workspaceId');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/workspaces/$workspaceId',
    );
    await tester.tap(find.byTooltip('Delete'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/setup');
    expect(find.text('Set up your first workspace'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });
}
