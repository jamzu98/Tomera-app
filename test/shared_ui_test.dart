import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/core/theme.dart';
import 'package:tomera/core/widgets/empty_state.dart';
import 'package:tomera/core/widgets/form_group.dart';
import 'package:tomera/core/widgets/quick_add_sheet.dart';
import 'package:tomera/core/widgets/status_ring.dart';
import 'package:tomera/core/widgets/workspace_switcher_pill.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/finance/billable_edit_screen.dart';
import 'package:tomera/features/projects/projects_screen.dart';
import 'package:tomera/features/tasks/tasks_screen.dart';
import 'package:tomera/l10n/app_localizations.dart';

Widget _app(Widget child, {Widget Function(Widget child)? withProviders}) {
  final app = MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
  return withProviders?.call(app) ?? ProviderScope(child: app);
}

Workspace _workspace({Set<ModuleKey>? modules}) => Workspace(
  id: 'workspace-1',
  createdAt: 1,
  updatedAt: 1,
  isDirty: false,
  name: 'Studio',
  color: 0xFF7C7FF2,
  icon: 'work',
  enabledModules: modules ?? {...ModuleKey.values},
  sortOrder: 0,
);

void main() {
  test('Work list preferences remain in session-scoped providers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(taskListSessionProvider.notifier)
        .setGroupMode(TaskGroupMode.dueDate);
    container.read(taskListSessionProvider.notifier).setOverdueOnly(true);
    container.read(projectListSessionProvider.notifier).setShowArchived(true);

    expect(
      container.read(taskListSessionProvider).groupMode,
      TaskGroupMode.dueDate,
    );
    expect(container.read(taskListSessionProvider).overdueOnly, isTrue);
    expect(container.read(projectListSessionProvider), isTrue);
  });

  testWidgets('SaveBar ignores reentrant taps while a save is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        SaveBar(
          label: 'Save',
          onPressed: () {
            calls++;
            return pending.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('EmptyState exposes primary, secondary, and retry actions', (
    tester,
  ) async {
    var primary = 0;
    var secondary = 0;
    var retries = 0;
    await tester.pumpWidget(
      _app(
        EmptyState(
          title: 'Nothing here',
          primaryAction: EmptyStateAction(
            label: 'Create',
            onPressed: () => primary++,
          ),
          secondaryAction: EmptyStateAction(
            label: 'Learn more',
            onPressed: () => secondary++,
          ),
          retryLabel: 'Retry',
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Learn more'));
    await tester.tap(find.text('Retry'));

    expect((primary, secondary, retries), (1, 1, 1));
    for (final label in ['Create', 'Learn more', 'Retry']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is FilledButton || widget is OutlinedButton,
        ),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('QuickAdd inherits context and disables unavailable modules', (
    tester,
  ) async {
    final workspace = _workspace(
      modules: {...ModuleKey.values}..remove(ModuleKey.notes),
    );
    QuickAddSelection? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showQuickAddSheet(
                context,
                creationContext: const CreationContext(
                  workspaceId: 'workspace-1',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
        withProviders: (child) => ProviderScope(
          overrides: [
            allWorkspacesProvider.overrideWith(
              (ref) => Stream.value([workspace]),
            ),
          ],
          child: child,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final noteTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'New note'),
    );
    expect(noteTile.enabled, isFalse);

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    expect(result?.action, QuickAddAction.task);
    expect(result?.context.workspaceId, 'workspace-1');
    expect(result?.destination.path, '/work/tasks/new');
    expect(result?.destination.queryParameters['workspaceId'], 'workspace-1');
  });

  testWidgets('QuickAdd from All requires an explicit workspace', (
    tester,
  ) async {
    final workspace = _workspace();
    await tester.pumpWidget(
      _app(
        const QuickAddSheet(),
        withProviders: (child) => ProviderScope(
          overrides: [
            allWorkspacesProvider.overrideWith(
              (ref) => Stream.value([workspace]),
            ),
          ],
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'New task'))
          .enabled,
      isFalse,
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'New task'))
          .enabled,
      isTrue,
    );
  });

  test('CreationContext carries related-record context to destinations', () {
    const context = CreationContext(
      workspaceId: 'workspace-1',
      projectId: 'project-1',
      contactId: 'contact-1',
    );

    final note = context.destinationFor(QuickAddAction.note);
    expect(note.path, '/work/notes/new');
    expect(note.queryParameters['parentType'], 'project');
    expect(note.queryParameters['parentId'], 'project-1');

    final timer = context.destinationFor(QuickAddAction.startTimer);
    expect(timer.path, '/finance');
    expect(timer.queryParameters['startTimer'], 'true');
  });

  testWidgets('compact interactive controls expose 48dp targets', (
    tester,
  ) async {
    final workspace = _workspace();
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WorkspaceSwitcherPill(compact: true),
            StatusRing(
              icon: Icons.check,
              color: Colors.green,
              size: 30,
              tooltip: 'Complete',
              onTap: () {},
            ),
          ],
        ),
        withProviders: (child) => ProviderScope(
          overrides: [
            allWorkspacesProvider.overrideWith(
              (ref) => Stream.value([workspace]),
            ),
          ],
          child: child,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(WorkspaceSwitcherPill)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(StatusRing)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('billable status uses a menu when the editor is narrow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    final workspace = _workspace();

    await tester.pumpWidget(
      _app(
        const BillableEditScreen(),
        withProviders: (child) => ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) => db),
            allWorkspacesProvider.overrideWith(
              (ref) => Stream.value([workspace]),
            ),
          ],
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<BillableStatus>), findsOneWidget);
    expect(find.byType(SegmentedButton<BillableStatus>), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
