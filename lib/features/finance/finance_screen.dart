import 'package:flutter/material.dart';

import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../l10n/app_localizations.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabFinance),
        actions: const [WorkspaceFilterButton(), WorkspacesButton()],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
