import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
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
        actions: const [WorkspaceFilterButton()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newProject,
        onPressed: () => context.go('/calendar/projects/new'),
        child: const Icon(Icons.add),
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
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: projects.length,
                  itemBuilder: (context, index) => _ProjectTile(
                    project: projects[index],
                    workspaces: workspaces,
                  ),
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.emptyProjectsTitle,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(l10n.emptyProjectsBody,
                            textAlign: TextAlign.center),
                      ],
                    ),
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
    0xFF888888;

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
    return ListTile(
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: Color(projectColor(project, workspaces)),
        child: const Icon(Icons.topic_outlined, size: 16, color: Colors.white),
      ),
      title: Text(project.name),
      subtitle:
          subtitleParts.isNotEmpty ? Text(subtitleParts.join(' · ')) : null,
      onTap: () => context.go('/calendar/projects/${project.id}'),
    );
  }
}
