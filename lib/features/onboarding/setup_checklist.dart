import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import 'demo_data.dart';
import 'onboarding_providers.dart';

final _onboardingTasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider).value;
    if (onboarding == null || onboarding.checklistDismissed) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final projects = ref.watch(allProjectsProvider).value ?? const <Project>[];
    final tasks = ref.watch(_onboardingTasksProvider).value ?? const <Task>[];
    final contacts = ref.watch(allContactsProvider).value ?? const <Contact>[];
    final items = [
      (
        complete: projects.isNotEmpty,
        label: l10n.checklistProject,
        route: '/work/projects/new',
      ),
      (
        complete: tasks.isNotEmpty,
        label: l10n.checklistTask,
        route: '/work/tasks/new',
      ),
      (
        complete: contacts.isNotEmpty,
        label: l10n.checklistContact,
        route: '/contacts/new',
      ),
    ];
    final completeCount = items.where((item) => item.complete).length;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.checklistTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.checklistProgress(completeCount, items.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.dismissAction,
                  onPressed: () =>
                      ref.read(onboardingProvider.notifier).dismissChecklist(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.complete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: item.complete ? tokens.success : tokens.ink2,
                ),
                title: Text(item.label),
                trailing: item.complete
                    ? null
                    : const Icon(Icons.chevron_right_rounded),
                onTap: item.complete ? null : () => context.push(item.route),
              ),
            if (onboarding.demoManifest != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(l10n.removeDemoAction),
                  onPressed: () async {
                    final manifest = onboarding.demoManifest!;
                    if (ref.read(selectedWorkspaceIdProvider) ==
                        manifest.workspaceId) {
                      ref
                          .read(selectedWorkspaceIdProvider.notifier)
                          .select(null);
                    }
                    await ref.read(demoDataServiceProvider).remove(manifest);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
