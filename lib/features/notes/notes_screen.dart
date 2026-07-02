import 'package:flutter/material.dart';

import '../../core/widgets/workspace_filter_button.dart';
import '../../l10n/app_localizations.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabNotes),
        actions: const [WorkspaceFilterButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
