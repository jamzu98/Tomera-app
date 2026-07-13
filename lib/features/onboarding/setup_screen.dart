import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../workspaces/workspace_style.dart';
import 'demo_data.dart';
import 'onboarding_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _color = workspaceColors.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createWorkspace() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final repository = ref.read(workspaceRepositoryProvider);
    final selectedWorkspace = ref.read(selectedWorkspaceIdProvider.notifier);
    final onboarding = ref.read(onboardingProvider.notifier);
    setState(() => _saving = true);
    try {
      final id = await repository.create(
        name: _nameController.text.trim(),
        color: _color,
        icon: 'work',
        enabledModules: {...ModuleKey.values},
      );
      selectedWorkspace.select(id);
      await onboarding.completeSetup();
      if (mounted) context.go('/today');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createDemo() async {
    if (_saving) return;
    final demoData = ref.read(demoDataServiceProvider);
    final selectedWorkspace = ref.read(selectedWorkspaceIdProvider.notifier);
    final onboarding = ref.read(onboardingProvider.notifier);
    setState(() => _saving = true);
    try {
      final manifest = await demoData.create();
      selectedWorkspace.select(manifest.workspaceId);
      await onboarding.completeSetup();
      if (mounted) context.go('/today');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.setupTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.setupBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    enabled: !_saving,
                    decoration: InputDecoration(labelText: l10n.workspaceName),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _createWorkspace(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.nameRequired
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    label: l10n.colorLabel,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in workspaceColors.take(8))
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _saving
                                ? null
                                : () => setState(() => _color = color),
                            child: SizedBox.square(
                              dimension: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(color),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _color == color
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.outlineVariant,
                                    width: _color == color ? 3 : 1,
                                  ),
                                ),
                                child: _color == color
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: workspaceForeground(
                                          Color(color),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _createWorkspace,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.createWorkspaceAction),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving ? null : _createDemo,
                    child: Text(l10n.tryDemoAction),
                  ),
                  Text(
                    l10n.demoDataNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
