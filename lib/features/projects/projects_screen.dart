import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/work_section_switcher.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'project_providers.dart';

class ProjectListSession extends Notifier<bool> {
  @override
  bool build() => false;

  void setShowArchived(bool value) => state = value;
}

final projectListSessionProvider = NotifierProvider<ProjectListSession, bool>(
  ProjectListSession.new,
);

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showArchived = ref.watch(projectListSessionProvider);
    final projectsValue = ref.watch(visibleProjectsProvider(showArchived));
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled =
        selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.calendar);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      body: Column(
        children: [
          const WorkSectionSwitcher(selected: WorkSection.projects),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilterChip(
                label: Text(l10n.showArchived),
                selected: showArchived,
                onSelected: ref
                    .read(projectListSessionProvider.notifier)
                    .setShowArchived,
              ),
            ),
          ),
          Expanded(
            child: moduleDisabled
                ? EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: l10n.moduleDisabledTitle,
                    body: l10n.calendarModuleDisabled,
                    primaryAction: EmptyStateAction(
                      label: l10n.editWorkspace,
                      icon: Icons.tune_rounded,
                      onPressed: () =>
                          context.push('/workspaces/${selectedWorkspace.id}'),
                    ),
                  )
                : switch (projectsValue) {
                    AsyncValue(value: final projects?)
                        when projects.isNotEmpty =>
                      ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: projects.length,
                        itemBuilder: (context, index) => _ProjectTile(
                          project: projects[index],
                          workspaces: workspaces,
                        ),
                      ),
                    AsyncValue(isLoading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    AsyncValue(hasError: true) => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.unableToLoadTitle,
                      body: l10n.unableToLoadBody,
                      retryLabel: l10n.retry,
                      onRetry: () =>
                          ref.invalidate(visibleProjectsProvider(showArchived)),
                    ),
                    _ => EmptyState(
                      icon: Icons.layers_outlined,
                      title: l10n.emptyProjectsTitle,
                      body: l10n.emptyProjectsBody,
                      primaryAction: EmptyStateAction(
                        label: l10n.newProject,
                        icon: Icons.add_rounded,
                        onPressed: () => context.go('/work/projects/new'),
                      ),
                    ),
                  },
          ),
        ],
      ),
    );
  }
}

/// Effective display color: the project's own, else its workspace's.
int projectColor(Project project, List<Workspace> workspaces) =>
    project.color ??
    workspaces.where((w) => w.id == project.workspaceId).firstOrNull?.color ??
    0xFFB7AD9C;

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project, required this.workspaces});

  final Project project;
  final List<Workspace> workspaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = workspaces
        .where((w) => w.id == project.workspaceId)
        .firstOrNull;
    final subtitleParts = [
      if (workspace != null) workspace.name,
      if (project.archived) l10n.archivedLabel,
    ];
    final color = Color(projectColor(project, workspaces));
    return SoftTile(
      leading: WorkspaceAvatar(
        color: color,
        icon: Icons.layers_rounded,
        size: 38,
      ),
      title: Text(project.name),
      subtitle: subtitleParts.isNotEmpty
          ? Row(
              children: [
                if (workspace != null) ...[
                  WorkspaceDot(color: Color(workspace.color)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    subtitleParts.join(' · '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
      onTap: () => context.go('/work/projects/${project.id}'),
    );
  }
}
