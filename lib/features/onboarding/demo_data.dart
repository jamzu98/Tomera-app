import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../workspaces/workspace_style.dart';
import 'onboarding_providers.dart';

class DemoDataService {
  const DemoDataService(this.ref);

  final Ref ref;

  Future<DemoDataManifest> create() async {
    final db = ref.read(appDatabaseProvider);
    late DemoDataManifest manifest;
    await db.transaction(() async {
      final workspaceId = await ref
          .read(workspaceRepositoryProvider)
          .create(
            name: 'Tomera demo',
            color: workspaceColors.first,
            icon: 'code',
            enabledModules: {...ModuleKey.values},
          );
      final contactId = await ref
          .read(contactRepositoryProvider)
          .create(
            name: 'Alex Example',
            email: 'alex@example.com',
            organization: 'Northstar Studio',
            defaultHourlyRateCents: 7500,
          );
      await ref
          .read(contactRepositoryProvider)
          .setRole(contactId, workspaceId, 'Client');
      final projectId = await ref
          .read(projectRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            name: 'Website launch',
            description: 'A small example showing how Tomera records connect.',
            contactId: contactId,
          );
      final now = DateTime.now();
      final tomorrowAtTen = DateTime(now.year, now.month, now.day + 1, 10);
      final eventId = await ref
          .read(eventRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Project kickoff',
            description: 'Confirm goals and next steps.',
            startsAt: tomorrowAtTen.toUtc().millisecondsSinceEpoch,
            endsAt: tomorrowAtTen
                .add(const Duration(hours: 1))
                .toUtc()
                .millisecondsSinceEpoch,
            projectId: projectId,
          );
      await ref.read(eventRepositoryProvider).setContacts(eventId, {contactId});
      final todayAtFive = DateTime(now.year, now.month, now.day, 17);
      final taskId = await ref
          .read(taskRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Send the project update',
            description: 'Summarize progress and confirm the kickoff agenda.',
            priority: TaskPriority.high,
            dueAt: todayAtFive.toUtc().millisecondsSinceEpoch,
            contactId: contactId,
            projectId: projectId,
          );
      final noteId = await ref
          .read(noteRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Project brief',
            body:
                '## Goal\nLaunch a clear, focused site.\n\n- Confirm scope\n- Prepare kickoff',
            parentType: ParentType.project,
            parentId: projectId,
          );
      final billableId = await ref
          .read(billableRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            contactId: contactId,
            projectId: projectId,
            type: BillableType.hourly,
            title: 'Discovery session',
            rateCents: 7500,
            durationMinutes: 60,
          );
      manifest = DemoDataManifest(
        workspaceId: workspaceId,
        projectId: projectId,
        contactId: contactId,
        eventId: eventId,
        taskId: taskId,
        noteId: noteId,
        billableId: billableId,
      );
    });

    try {
      await ref.read(onboardingProvider.notifier).setDemoManifest(manifest);
    } on Object {
      await remove(manifest, clearManifest: false);
      rethrow;
    }
    return manifest;
  }

  Future<void> remove(
    DemoDataManifest manifest, {
    bool clearManifest = true,
  }) async {
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      await ref.read(billableRepositoryProvider).delete(manifest.billableId);
      await ref.read(noteRepositoryProvider).delete(manifest.noteId);
      await ref.read(taskRepositoryProvider).delete(manifest.taskId);
      await ref.read(eventRepositoryProvider).delete(manifest.eventId);
      await ref.read(projectRepositoryProvider).delete(manifest.projectId);
      await ref.read(contactRepositoryProvider).delete(manifest.contactId);
      await ref.read(workspaceRepositoryProvider).delete(manifest.workspaceId);
    });
    if (clearManifest) {
      await ref.read(onboardingProvider.notifier).clearDemoManifest();
    }
  }
}

final demoDataServiceProvider = Provider(DemoDataService.new);
