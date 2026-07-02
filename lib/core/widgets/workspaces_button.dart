import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// App bar action that opens workspace management over the current tab.
class WorkspacesButton extends StatelessWidget {
  const WorkspacesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.folder_outlined),
      tooltip: AppLocalizations.of(context)!.tabWorkspaces,
      onPressed: () => context.push('/workspaces'),
    );
  }
}
