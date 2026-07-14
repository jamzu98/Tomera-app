import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

enum WorkSection { tasks, projects, notes }

/// Editorial pill navigation for the three route-addressable Work lists.
/// It lives in list content so the app retains a single primary bottom bar.
class WorkSectionSwitcher extends StatelessWidget {
  const WorkSectionSwitcher({super.key, required this.selected});

  final WorkSection selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sections = [
      (WorkSection.tasks, l10n.tabTasks, '/work/tasks'),
      (WorkSection.projects, l10n.projectsTitle, '/work/projects'),
      (WorkSection.notes, l10n.tabNotes, '/work/notes'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final (section, label, path) in sections)
              Expanded(
                child: Semantics(
                  selected: section == selected,
                  button: true,
                  child: InkWell(
                    onTap: section == selected ? null : () => context.go(path),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: section == selected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: section == selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: section == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
