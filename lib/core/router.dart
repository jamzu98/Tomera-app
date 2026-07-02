import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/calendar/event_edit_screen.dart';
import '../features/contacts/contact_detail_screen.dart';
import '../features/contacts/contact_edit_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/finance/billable_edit_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/notes/note_edit_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/tasks/task_edit_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/workspaces/workspace_edit_screen.dart';
import '../features/workspaces/workspaces_screen.dart';
import '../l10n/app_localizations.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) => GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/calendar',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => EventEditScreen(
                      initialStartMs: int.tryParse(
                          state.uri.queryParameters['start'] ?? ''),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => EventEditScreen(
                      eventId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const TaskEditScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => TaskEditScreen(
                      taskId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/notes',
                builder: (context, state) => const NotesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => NoteEditScreen(
                      parentType: state.uri.queryParameters['parentType'],
                      parentId: state.uri.queryParameters['parentId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => NoteEditScreen(
                      noteId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ContactEditScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ContactDetailScreen(
                      contactId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => ContactEditScreen(
                          contactId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => BillableEditScreen(
                      initialContactId:
                          state.uri.queryParameters['contactId'],
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => BillableEditScreen(
                      billableId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
        // Workspace management lives above the tab shell (spec Phase 2
        // navigation decision: 5 tabs, workspaces via app bar icon).
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
              builder: (context, state) => WorkspaceEditScreen(
                workspaceId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l10n.tabCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.check_circle_outline),
            selectedIcon: const Icon(Icons.check_circle),
            label: l10n.tabTasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notes_outlined),
            selectedIcon: const Icon(Icons.notes),
            label: l10n.tabNotes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.tabContacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.euro_outlined),
            selectedIcon: const Icon(Icons.euro),
            label: l10n.tabFinance,
          ),
        ],
      ),
    );
  }
}
