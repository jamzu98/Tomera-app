import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/editorial.dart';
import '../../core/widgets/pulsing_dot.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../l10n/app_localizations.dart';
import '../finance/finance_providers.dart';
import '../finance/recoverable_timer_list.dart';
import '../finance/timer_math.dart';
import '../onboarding/setup_checklist.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';
import 'today_providers.dart';

DateFormat _clockFormat(BuildContext context, WidgetRef ref) {
  final uses24Hour = ref
      .watch(timeFormatSettingProvider)
      .resolveUses24Hour(
        systemUses24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      );
  return DateFormat(uses24Hour ? 'HH:mm' : 'h:mm a');
}

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayClockProvider.notifier).refresh();
    }
  }

  void _refreshSections() {
    ref.read(todayClockProvider.notifier).refresh();
    ref.invalidate(todayActiveTimerProvider);
    ref.invalidate(todayRecoverableTimerSessionsProvider);
    ref.invalidate(todayEventProvider);
    ref.invalidate(todayTasksProvider);
    ref.invalidate(todayUnbilledSummaryProvider);
    ref.invalidate(todayRecentNotesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.watch(todayClockProvider);
    final dateLabel = DateFormat.yMMMMEEEEd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(now);
    return Scaffold(
      appBar: AppBar(
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshSections(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: EditorialScreenHeader(
                title: l10n.tabToday,
                subtitle: dateLabel,
              ),
            ),
            const SliverToBoxAdapter(child: SetupChecklistCard()),
            const SliverToBoxAdapter(child: _NowAndNextRail()),
            const SliverToBoxAdapter(child: _RecoverableTimersSection()),
            const SliverToBoxAdapter(child: _TasksSection()),
            const SliverToBoxAdapter(child: _UnbilledSection()),
            const SliverToBoxAdapter(child: _NotesSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }
}

class _NowAndNextRail extends StatelessWidget {
  const _NowAndNextRail();

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 56)
        .clamp(280.0, 340.0)
        .toDouble();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: width, child: const _ActiveTimerSection()),
          const SizedBox(width: 12),
          SizedBox(width: width, child: const _EventSection()),
        ],
      ),
    );
  }
}

class _RecoverableTimersSection extends ConsumerWidget {
  const _RecoverableTimersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayRecoverableTimerSessionsProvider);
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => _TodaySection(
        title: l10n.unconvertedTime,
        child: _SectionError(
          onRetry: () => ref.invalidate(todayRecoverableTimerSessionsProvider),
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return _TodaySection(
          title: l10n.unconvertedTime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.unconvertedTimeBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              RecoverableTimerList(sessions: sessions, maxItems: 2),
              if (sessions.length > 2)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/finance'),
                    child: Text(l10n.tabFinance),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveTimerSection extends ConsumerWidget {
  const _ActiveTimerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayActiveTimerProvider);
    return _TodaySection(
      title: l10n.todayActiveTimer,
      featured: true,
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) => _SectionError(
          onRetry: () => ref.invalidate(todayActiveTimerProvider),
        ),
        data: (session) {
          if (session == null) {
            return _SectionEmpty(
              icon: Icons.timer_outlined,
              message: l10n.todayNoActiveTimer,
            );
          }
          ref.watch(timerTickProvider);
          final workspace = (ref.watch(allWorkspacesProvider).value ?? [])
              .where((item) => item.id == session.workspaceId)
              .firstOrNull;
          final project = (ref.watch(allProjectsForLookupProvider).value ?? [])
              .where((item) => item.id == session.projectId)
              .firstOrNull;
          return SoftTile(
            margin: EdgeInsets.zero,
            leading: const PulsingDot(),
            title: Text(
              session.description?.isNotEmpty == true
                  ? session.description!
                  : l10n.timerRunning,
            ),
            subtitle: Text(
              [
                workspace?.name ?? l10n.noWorkspace,
                if (project != null) project.name,
              ].join(' · '),
            ),
            trailing: Text(
              formatElapsed(
                elapsedMs(startedAtMs: session.startedAt, nowMs: utcNowMs()),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures,
              ),
            ),
            onTap: () => context.go('/finance'),
          );
        },
      ),
    );
  }
}

class _EventSection extends ConsumerWidget {
  const _EventSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayEventProvider);
    final now = ref.watch(todayClockProvider);
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final day = localDayRange(now);
    final clockFormat = _clockFormat(context, ref);
    return _TodaySection(
      title: l10n.todaySchedule,
      featured: true,
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) =>
            _SectionError(onRetry: () => ref.invalidate(todayEventProvider)),
        data: (event) {
          if (event == null) {
            return _SectionEmpty(
              icon: Icons.event_available_outlined,
              message: l10n.todayNoEvent,
            );
          }
          final starts = DateTime.fromMillisecondsSinceEpoch(
            event.startsAt,
            isUtc: true,
          ).toLocal();
          final ends = DateTime.fromMillisecondsSinceEpoch(
            event.endsAt,
            isUtc: true,
          ).toLocal();
          final ongoing = event.startsAt <= nowMs;
          var time = event.allDay
              ? l10n.allDayLabel
              : '${clockFormat.format(starts)}–${clockFormat.format(ends)}';
          if (event.startsAt >= day.end) {
            time = '${DateFormat.MMMEd().format(starts)} · $time';
          }
          return SoftTile(
            margin: EdgeInsets.zero,
            leading: _LeadingIcon(
              icon: ongoing
                  ? Icons.play_circle_outline_rounded
                  : Icons.calendar_today_outlined,
            ),
            title: Text(event.title),
            subtitle: Text(
              '${ongoing ? l10n.todayOngoing : l10n.todayNext} · $time',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/calendar/${event.id}'),
          );
        },
      ),
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayTasksProvider);
    final start = localDayRange(ref.watch(todayClockProvider)).start;
    final clockFormat = _clockFormat(context, ref);
    return _TodaySection(
      title: l10n.todayTasks,
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) =>
            _SectionError(onRetry: () => ref.invalidate(todayTasksProvider)),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _SectionEmpty(
              icon: Icons.task_alt_rounded,
              message: l10n.todayNoTasks,
            );
          }
          return Column(
            children: [
              for (final task in tasks)
                SoftTile(
                  margin: const EdgeInsets.only(bottom: 8),
                  leading: _LeadingIcon(
                    icon: task.dueAt! < start
                        ? Icons.event_busy_outlined
                        : Icons.schedule_rounded,
                    error: task.dueAt! < start,
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                    task.dueAt! < start
                        ? l10n.dueSectionOverdue
                        : clockFormat.format(
                            DateTime.fromMillisecondsSinceEpoch(
                              task.dueAt!,
                              isUtc: true,
                            ).toLocal(),
                          ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/work/tasks/${task.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UnbilledSection extends ConsumerWidget {
  const _UnbilledSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayUnbilledSummaryProvider);
    return _TodaySection(
      title: l10n.todayUnbilled,
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) => _SectionError(
          onRetry: () => ref.invalidate(todayUnbilledSummaryProvider),
        ),
        data: (summary) {
          if (summary.minutes == 0 && summary.totalsByCurrency.isEmpty) {
            return _SectionEmpty(
              icon: Icons.receipt_long_outlined,
              message: l10n.todayNoUnbilled,
            );
          }
          final hours = summary.minutes ~/ 60;
          final minutes = summary.minutes % 60;
          final duration = hours == 0
              ? l10n.todayMinutes(minutes)
              : l10n.todayHoursMinutes(hours, minutes);
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(editorialCardRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(editorialCardRadius),
              onTap: () => context.go('/finance'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _SummaryRow(label: l10n.todayUnbilledTime, value: duration),
                    for (final entry in summary.totalsByCurrency.entries)
                      _SummaryRow(
                        label: entry.key,
                        value: '${formatCents(entry.value)} ${entry.key}',
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotesSection extends ConsumerWidget {
  const _NotesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(todayRecentNotesProvider);
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    return _TodaySection(
      title: l10n.todayRecentNotes,
      child: value.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) => _SectionError(
          onRetry: () => ref.invalidate(todayRecentNotesProvider),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return _SectionEmpty(
              icon: Icons.notes_rounded,
              message: l10n.todayNoNotes,
            );
          }
          return Column(
            children: [
              for (final note in notes)
                SoftTile(
                  margin: const EdgeInsets.only(bottom: 8),
                  leading: _LeadingIcon(icon: Icons.description_outlined),
                  title: Text(note.title),
                  subtitle: Text(
                    workspaces
                            .where((item) => item.id == note.workspaceId)
                            .firstOrNull
                            ?.name ??
                        l10n.noWorkspace,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/work/notes/${note.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.title,
    required this.child,
    this.featured = false,
  });

  final String title;
  final Widget child;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    if (featured) {
      return EditorialFeaturedCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        Padding(padding: editorialPagePadding, child: child),
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 64,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionSurface(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.unableToLoadBody)),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => _SectionSurface(
    child: Row(
      children: [
        Icon(icon, color: context.tokens.textTertiary),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(editorialControlRadius),
    ),
    child: child,
  );
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, this.error = false});

  final IconData icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? context.tokens.danger
        : Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
