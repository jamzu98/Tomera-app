import 'package:flutter/material.dart';

import '../../core/widgets/workspace_filter_button.dart';
import '../../l10n/app_localizations.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabTasks),
        actions: const [WorkspaceFilterButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
