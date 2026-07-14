import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// One extra entry in the app bar overflow menu.
typedef OverflowEntry = ({IconData icon, String label, VoidCallback onTap});

/// The redesign declutters app bars: secondary destinations collapse into a
/// single overflow menu. Workspace management is always available here.
class AppBarOverflowMenu extends StatelessWidget {
  const AppBarOverflowMenu({super.key, this.entries = const []});

  final List<OverflowEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<int>(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (index) {
        if (index == -2) {
          context.push('/settings');
        } else if (index == -1) {
          context.push('/workspaces');
        } else {
          entries[index].onTap();
        }
      },
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(entries[i].icon, size: 20),
                const SizedBox(width: 12),
                Text(entries[i].label),
              ],
            ),
          ),
        PopupMenuItem(
          value: -1,
          child: Row(
            children: [
              const Icon(Icons.workspaces_outline, size: 20),
              const SizedBox(width: 12),
              Text(l10n.tabWorkspaces),
            ],
          ),
        ),
        PopupMenuItem(
          value: -2,
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 20),
              const SizedBox(width: 12),
              Text(l10n.settingsTitle),
            ],
          ),
        ),
      ],
    );
  }
}
