import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:tomera/core/notifications/notification_service.dart';
import 'package:tomera/core/providers.dart';
import 'package:tomera/data/db/database.dart';
import 'package:tomera/features/today/today_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local day ranges use local calendar boundaries', () {
    final range = localDayRange(DateTime(2026, 3, 29, 12));
    final start = DateTime.fromMillisecondsSinceEpoch(
      range.start,
      isUtc: true,
    ).toLocal();
    final end = DateTime.fromMillisecondsSinceEpoch(
      range.end,
      isUtc: true,
    ).toLocal();
    expect(start, DateTime(2026, 3, 29));
    expect(end, DateTime(2026, 3, 30));
  });

  test('local day ranges preserve 23 and 25 hour DST days', () {
    tz_data.initializeTimeZones();
    final helsinki = tz.getLocation('Europe/Helsinki');

    final spring = localDayRange(DateTime(2026, 3, 29, 12), location: helsinki);
    final autumn = localDayRange(
      DateTime(2026, 10, 25, 12),
      location: helsinki,
    );

    expect(spring.end - spring.start, const Duration(hours: 23).inMilliseconds);
    expect(autumn.end - autumn.start, const Duration(hours: 25).inMilliseconds);
  });

  test(
    'Today sections are filtered independently by workspace modules',
    () async {
      final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          notificationServiceProvider.overrideWith(
            (ref) => const NoopNotificationService(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final workspaceId = await container
          .read(workspaceRepositoryProvider)
          .create(
            name: 'Visible',
            color: 0xFF336699,
            icon: 'work',
            enabledModules: {...ModuleKey.values},
          );
      final disabledWorkspaceId = await container
          .read(workspaceRepositoryProvider)
          .create(
            name: 'Disabled',
            color: 0xFF999999,
            icon: 'work',
            enabledModules: {ModuleKey.contacts},
          );
      final workspacesSubscription = container.listen(
        allWorkspacesProvider,
        (previous, next) {},
      );
      addTearDown(workspacesSubscription.close);
      await container.read(allWorkspacesProvider.future);
      final eventSubscription = container.listen(
        todayEventProvider,
        (previous, next) {},
      );
      final taskSubscription = container.listen(
        todayTasksProvider,
        (previous, next) {},
      );
      final unbilledSubscription = container.listen(
        todayUnbilledSummaryProvider,
        (previous, next) {},
      );
      final notesSubscription = container.listen(
        todayRecentNotesProvider,
        (previous, next) {},
      );
      final timerSubscription = container.listen(
        todayActiveTimerProvider,
        (previous, next) {},
      );
      addTearDown(eventSubscription.close);
      addTearDown(taskSubscription.close);
      addTearDown(unbilledSubscription.close);
      addTearDown(notesSubscription.close);
      addTearDown(timerSubscription.close);

      final now = DateTime.now();
      final ongoingStart = now.subtract(const Duration(minutes: 20));
      final ongoingEnd = now.add(const Duration(minutes: 40));
      await container
          .read(eventRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Ongoing event',
            startsAt: ongoingStart.toUtc().millisecondsSinceEpoch,
            endsAt: ongoingEnd.toUtc().millisecondsSinceEpoch,
          );
      await container
          .read(eventRepositoryProvider)
          .create(
            workspaceId: disabledWorkspaceId,
            title: 'Hidden event',
            startsAt: ongoingStart.toUtc().millisecondsSinceEpoch,
            endsAt: ongoingEnd.toUtc().millisecondsSinceEpoch,
          );
      await container
          .read(taskRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Due today',
            dueAt: DateTime(
              now.year,
              now.month,
              now.day,
              17,
            ).toUtc().millisecondsSinceEpoch,
          );
      await container
          .read(taskRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            title: 'Tomorrow',
            dueAt: DateTime(
              now.year,
              now.month,
              now.day + 1,
              9,
            ).toUtc().millisecondsSinceEpoch,
          );
      await container
          .read(billableRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            type: BillableType.hourly,
            title: 'EUR work',
            rateCents: 6000,
            durationMinutes: 90,
            currency: 'EUR',
          );
      await container
          .read(billableRepositoryProvider)
          .create(
            workspaceId: workspaceId,
            type: BillableType.fixed,
            title: 'USD work',
            amountCents: 2500,
            currency: 'USD',
          );
      for (var i = 0; i < 4; i++) {
        await container
            .read(noteRepositoryProvider)
            .create(workspaceId: workspaceId, title: 'Note $i', body: 'Body');
      }
      await container
          .read(timerRepositoryProvider)
          .start(workspaceId: disabledWorkspaceId, notificationTitle: 'Timer');

      expect(
        (await container.read(todayEventProvider.future))?.title,
        'Ongoing event',
      );
      expect(await container.read(todayTasksProvider.future), hasLength(1));
      final unbilled = await container.read(
        todayUnbilledSummaryProvider.future,
      );
      expect(unbilled.minutes, 90);
      expect(unbilled.totalsByCurrency, {'EUR': 9000, 'USD': 2500});
      expect(
        await container.read(todayRecentNotesProvider.future),
        hasLength(3),
      );

      container
          .read(selectedWorkspaceIdProvider.notifier)
          .select(disabledWorkspaceId);
      expect(await container.read(todayEventProvider.future), isNull);
      expect(await container.read(todayTasksProvider.future), isEmpty);
      expect(
        (await container.read(
          todayUnbilledSummaryProvider.future,
        )).totalsByCurrency,
        isEmpty,
      );
      expect(await container.read(todayRecentNotesProvider.future), isEmpty);
      expect(await container.read(todayActiveTimerProvider.future), isNotNull);
    },
  );
}
