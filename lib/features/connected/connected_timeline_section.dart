import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../l10n/app_localizations.dart';
import '../settings/date_time_format.dart';
import 'connected_timeline.dart';

class ConnectedTimelineSection extends ConsumerWidget {
  const ConnectedTimelineSection({
    super.key,
    required this.activities,
    this.maximumEntries = 20,
  });

  final List<ConnectedActivity> activities;
  final int maximumEntries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activities.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final date = DateFormat.yMMMEd();
    final time = appTimeFormat(context, ref);
    final visible = activities.take(maximumEntries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.activityTimeline,
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
        ),
        for (final activity in visible)
          SoftTile(
            margin: const EdgeInsets.symmetric(vertical: 4),
            leading: Icon(
              _icon(activity.type),
              size: 20,
              color: context.tokens.textSecondary,
            ),
            title: Text(activity.title),
            subtitle: Text(
              '${_typeLabel(l10n, activity.type)} · '
              '${date.format(_local(activity.timestamp))} '
              '${time.format(_local(activity.timestamp))}',
            ),
            onTap: () => context.push(activity.route),
          ),
      ],
    );
  }

  DateTime _local(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();

  IconData _icon(ConnectedActivityType type) => switch (type) {
    ConnectedActivityType.event => Icons.event_outlined,
    ConnectedActivityType.completedTask => Icons.task_alt_rounded,
    ConnectedActivityType.note => Icons.description_outlined,
    ConnectedActivityType.timer => Icons.timer_outlined,
    ConnectedActivityType.billable => Icons.receipt_long_outlined,
  };

  String _typeLabel(AppLocalizations l10n, ConnectedActivityType type) =>
      switch (type) {
        ConnectedActivityType.event => l10n.activityEvent,
        ConnectedActivityType.completedTask => l10n.activityCompletedTask,
        ConnectedActivityType.note => l10n.activityNote,
        ConnectedActivityType.timer => l10n.activityTimer,
        ConnectedActivityType.billable => l10n.activityBillable,
      };
}
