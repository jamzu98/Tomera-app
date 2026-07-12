import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'project_providers.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsValue = ref.watch(visibleProjectsProvider(_showArchived));
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-projects',
        tooltip: l10n.newProject,
        onPressed: () => context.go('/calendar/projects/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilterChip(
                label: Text(l10n.showArchived),
                selected: _showArchived,
                onSelected: (selected) =>
                    setState(() => _showArchived = selected),
              ),
            ),
          ),
          Expanded(
            child: switch (projectsValue) {
              AsyncValue(value: final projects?) when projects.isNotEmpty =>
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  itemCount: projects.length,
                  itemBuilder: (context, index) => _ProjectTile(
                    project: projects[index],
                    workspaces: workspaces,
                  ),
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => EmptyState(
                  icon: Icons.layers_outlined,
                  title: l10n.emptyProjectsTitle,
                  body: l10n.emptyProjectsBody,
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
    final workspace =
        workspaces.where((w) => w.id == project.workspaceId).firstOrNull;
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
                  child: Text(subtitleParts.join(' · '),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            )
          : null,
      onTap: () => context.go('/calendar/projects/${project.id}'),
    );
  }
}
