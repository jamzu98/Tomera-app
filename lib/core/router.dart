import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/calendar/event_edit_screen.dart';
import '../features/contacts/contact_detail_screen.dart';
import '../features/contacts/contact_edit_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/finance/billable_edit_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/finance/timer_banner.dart';
import '../features/finance/timer_card.dart';
import '../features/finance/timer_session_detail_screen.dart';
import '../features/notes/note_edit_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/onboarding/setup_screen.dart';
import '../features/projects/add_instances_screen.dart';
import '../features/projects/project_detail_screen.dart';
import '../features/projects/project_edit_screen.dart';
import '../features/projects/project_providers.dart';
import '../features/projects/projects_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tasks/task_edit_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/today/today_screen.dart';
import '../features/workspaces/workspace_edit_screen.dart';
import '../features/workspaces/workspaces_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets/quick_add_sheet.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

String _withQuery(GoRouterState state, String path) => Uri(
  path: path,
  queryParameters: state.uri.queryParameters.isEmpty
      ? null
      : state.uri.queryParameters,
).toString();

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final redirectRefresh = ValueNotifier(0);
  ref.onDispose(redirectRefresh.dispose);
  ref.listen(allWorkspacesProvider, (previous, next) {
    redirectRefresh.value++;
  });
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    refreshListenable: redirectRefresh,
    redirect: (context, state) {
      final rows = ref.read(allWorkspacesProvider).value;
      if (rows == null) return null;
      if (rows.isEmpty && state.uri.path != '/setup') return '/setup';
      if (rows.isNotEmpty && state.uri.path == '/setup') return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
                routes: [
                  // Editors are displayed above the shell, hiding its bottom
                  // navigation while retaining the calendar URL hierarchy.
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => EventEditScreen(
                      initialStartMs: int.tryParse(
                        state.uri.queryParameters['start'] ?? '',
                      ),
                      initialWorkspaceId:
                          state.uri.queryParameters['workspaceId'],
                      initialContactId: state.uri.queryParameters['contactId'],
                      initialProjectId: state.uri.queryParameters['projectId'],
                    ),
                  ),
                  // Legacy project URLs continue to resolve to Work.
                  GoRoute(
                    path: 'projects',
                    redirect: (context, state) =>
                        state.uri.path == '/calendar/projects'
                        ? _withQuery(state, '/work/projects')
                        : null,
                    routes: [
                      GoRoute(
                        path: 'new',
                        redirect: (context, state) =>
                            _withQuery(state, '/work/projects/new'),
                      ),
                      GoRoute(
                        path: ':projectId',
                        redirect: (context, state) {
                          if (state.uri.path.endsWith('/edit') ||
                              state.uri.path.endsWith('/instances')) {
                            return null;
                          }
                          return _withQuery(
                            state,
                            '/work/projects/${state.pathParameters['projectId']}',
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'edit',
                            redirect: (context, state) => _withQuery(
                              state,
                              '/work/projects/${state.pathParameters['projectId']}/edit',
                            ),
                          ),
                          GoRoute(
                            path: 'instances',
                            redirect: (context, state) => _withQuery(
                              state,
                              '/work/projects/${state.pathParameters['projectId']}/instances',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        EventEditScreen(eventId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/work/tasks',
            routes: [
              GoRoute(
                path: '/work/tasks',
                builder: (context, state) => const TasksScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => TaskEditScreen(
                      initialWorkspaceId:
                          state.uri.queryParameters['workspaceId'],
                      initialContactId: state.uri.queryParameters['contactId'],
                      initialProjectId: state.uri.queryParameters['projectId'],
                      initialTitle: state.uri.queryParameters['title'],
                      initialDescription:
                          state.uri.queryParameters['description'],
                      sourceNoteId: state.uri.queryParameters['sourceNoteId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        TaskEditScreen(taskId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: '/work/projects',
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProjectEditScreen(),
                  ),
                  GoRoute(
                    path: ':projectId',
                    builder: (context, state) => ProjectDetailScreen(
                      projectId: state.pathParameters['projectId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => ProjectEditScreen(
                          projectId: state.pathParameters['projectId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'instances',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => AddInstancesScreen(
                          projectId: state.pathParameters['projectId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/work/notes',
                builder: (context, state) => const NotesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => NoteEditScreen(
                      initialWorkspaceId:
                          state.uri.queryParameters['workspaceId'],
                      parentType: state.uri.queryParameters['parentType'],
                      parentId: state.uri.queryParameters['parentId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        NoteEditScreen(noteId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ContactEditScreen(
                      initialWorkspaceId:
                          state.uri.queryParameters['workspaceId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ContactDetailScreen(
                      contactId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => ContactEditScreen(
                          contactId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => BillableEditScreen(
                      initialContactId: state.uri.queryParameters['contactId'],
                      initialWorkspaceId:
                          state.uri.queryParameters['workspaceId'],
                      initialTitle: state.uri.queryParameters['title'],
                      initialDurationMinutes: int.tryParse(
                        state.uri.queryParameters['duration'] ?? '',
                      ),
                      initialProjectId: state.uri.queryParameters['projectId'],
                      initialTimerSessionId:
                          state.uri.queryParameters['timerSessionId'],
                      initialTaskId: state.uri.queryParameters['taskId'],
                      initialEventId: state.uri.queryParameters['eventId'],
                    ),
                  ),
                  GoRoute(
                    path: 'timers/:timerId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => TimerSessionDetailScreen(
                      timerId: state.pathParameters['timerId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => BillableEditScreen(
                      billableId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Query-preserving redirects for pre-cohesion Work links.
      GoRoute(
        path: '/tasks',
        redirect: (context, state) => state.uri.path == '/tasks'
            ? _withQuery(state, '/work/tasks')
            : null,
        routes: [
          GoRoute(
            path: 'new',
            redirect: (context, state) => _withQuery(state, '/work/tasks/new'),
          ),
          GoRoute(
            path: ':id',
            redirect: (context, state) =>
                _withQuery(state, '/work/tasks/${state.pathParameters['id']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/notes',
        redirect: (context, state) => state.uri.path == '/notes'
            ? _withQuery(state, '/work/notes')
            : null,
        routes: [
          GoRoute(
            path: 'new',
            redirect: (context, state) => _withQuery(state, '/work/notes/new'),
          ),
          GoRoute(
            path: ':id',
            redirect: (context, state) =>
                _withQuery(state, '/work/notes/${state.pathParameters['id']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/workspaces',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WorkspacesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const WorkspaceEditScreen(),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                WorkspaceEditScreen(workspaceId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  CreationContext _creationContext(BuildContext context, WidgetRef ref) {
    final selectedWorkspaceId = ref.watch(selectedWorkspaceIdProvider);
    final segments = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.pathSegments;
    final projectId =
        segments.length >= 3 &&
            segments[0] == 'work' &&
            segments[1] == 'projects'
        ? segments[2]
        : null;
    if (projectId != null) {
      final project = ref.watch(projectByIdProvider(projectId)).value;
      if (project != null) {
        return CreationContext(
          workspaceId: project.workspaceId,
          projectId: project.id,
          contactId: project.contactId,
        );
      }
    }

    final contactId = segments.length >= 2 && segments[0] == 'contacts'
        ? segments[1]
        : null;
    return CreationContext(
      workspaceId: selectedWorkspaceId,
      contactId: contactId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final creationContext = _creationContext(context, ref);
    return Scaffold(
      body: shell,
      floatingActionButton: SizedBox.square(
        dimension: 54,
        child: FloatingActionButton(
          heroTag: 'shell-quick-add',
          tooltip: l10n.quickAdd,
          onPressed: () async {
            final router = GoRouter.of(context);
            final selection = await showQuickAddSheet(
              context,
              creationContext: creationContext,
            );
            if (selection == null) return;
            if (selection.action == QuickAddAction.startTimer) {
              if (!context.mounted) return;
              await showStartTimerSheet(
                context,
                workspaceId: selection.context.workspaceId,
                contactId: selection.context.contactId,
                projectId: selection.context.projectId,
              );
              return;
            }
            router.go(selection.destination.toString());
          },
          child: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TimerBanner(),
          _EditorialBottomDock(shell: shell),
        ],
      ),
    );
  }
}

class _EditorialBottomDock extends StatelessWidget {
  const _EditorialBottomDock({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.dockBackground,
          borderRadius: BorderRadius.circular(36),
          boxShadow: editorialShadow(context, strong: true),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(36),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.today_outlined),
                selectedIcon: const Icon(Icons.today_rounded),
                label: l10n.tabToday,
                tooltip: l10n.tabToday,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month_rounded),
                label: l10n.tabCalendar,
                tooltip: l10n.tabCalendar,
              ),
              NavigationDestination(
                icon: const Icon(Icons.work_outline_rounded),
                selectedIcon: const Icon(Icons.work_rounded),
                label: l10n.tabWork,
                tooltip: l10n.tabWork,
              ),
              NavigationDestination(
                icon: const Icon(Icons.group_outlined),
                selectedIcon: const Icon(Icons.group_rounded),
                label: l10n.tabContacts,
                tooltip: l10n.tabContacts,
              ),
              NavigationDestination(
                icon: const Icon(Icons.euro_outlined),
                selectedIcon: const Icon(Icons.euro_rounded),
                label: l10n.tabFinance,
                tooltip: l10n.tabFinance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
