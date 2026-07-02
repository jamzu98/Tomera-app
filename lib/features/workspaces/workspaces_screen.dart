import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabWorkspaces),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
