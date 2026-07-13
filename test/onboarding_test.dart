import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomera/features/onboarding/onboarding_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'onboarding state is versioned and persists checklist dismissal',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);

      expect(
        (await first.read(onboardingProvider.future)).setupComplete,
        isFalse,
      );
      await first.read(onboardingProvider.notifier).completeSetup();
      await first.read(onboardingProvider.notifier).dismissChecklist();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final restored = await second.read(onboardingProvider.future);
      expect(restored.version, currentOnboardingVersion);
      expect(restored.setupComplete, isTrue);
      expect(restored.checklistDismissed, isTrue);
    },
  );

  test('demo manifest round-trips through preferences', () async {
    const manifest = DemoDataManifest(
      workspaceId: 'workspace',
      projectId: 'project',
      contactId: 'contact',
      eventId: 'event',
      taskId: 'task',
      noteId: 'note',
      billableId: 'billable',
    );
    final first = ProviderContainer();
    addTearDown(first.dispose);
    await first.read(onboardingProvider.future);
    await first.read(onboardingProvider.notifier).setDemoManifest(manifest);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(onboardingProvider.future);
    expect(restored.demoManifest?.toJson(), manifest.toJson());

    await second.read(onboardingProvider.notifier).clearDemoManifest();
    expect(second.read(onboardingProvider).value?.demoManifest, isNull);
  });
}
