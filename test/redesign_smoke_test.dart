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
Future<void> _seed(AppDatabase db) async {
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
      title: 'Meeting notes', body: '# Agenda\n- invoicing\n- **next steps**');

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
}

Future<void> _walkApp(WidgetTester tester, ThemeMode mode) async {
  SharedPreferences.setMockInitialValues(
      {'settings.themeMode': mode.name});
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  await _seed(db);

  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWith((ref) => db),
  ]);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const TomeraApp(),
  ));
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

  testWidgets('all main screens render in dark mode', (tester) async {
    await _walkApp(tester, ThemeMode.dark);
  });

  testWidgets('all main screens render in light mode', (tester) async {
    await _walkApp(tester, ThemeMode.light);
  });
}
