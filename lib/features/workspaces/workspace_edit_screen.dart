import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'module_labels.dart';
import 'workspace_style.dart';

class WorkspaceEditScreen extends ConsumerStatefulWidget {
  const WorkspaceEditScreen({super.key, this.workspaceId});

  /// Null when creating a new workspace.
  final String? workspaceId;

  @override
  ConsumerState<WorkspaceEditScreen> createState() =>
      _WorkspaceEditScreenState();
}

class _WorkspaceEditScreenState extends ConsumerState<WorkspaceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _color = workspaceColors.first;
  String _icon = workspaceIcons.keys.first;
  Set<ModuleKey> _modules = {...ModuleKey.values};
  bool _initialized = false;

  bool get _isNew => widget.workspaceId == null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFrom(Workspace workspace) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = workspace.name;
    _color = workspace.color;
    _icon = workspace.icon;
    _modules = {...workspace.enabledModules};
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(workspaceRepositoryProvider);
    final name = _nameController.text.trim();
    if (_isNew) {
      await repository.create(
        name: name,
        color: _color,
        icon: _icon,
        enabledModules: _modules,
      );
    } else {
      await repository.update(
        widget.workspaceId!,
        name: name,
        color: _color,
        icon: _icon,
        enabledModules: _modules,
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete(Workspace workspace) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteWorkspaceTitle),
        content: Text(l10n.deleteWorkspaceBody(workspace.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workspaceRepositoryProvider).delete(workspace.id);
    // Reset the filter if it pointed at the deleted workspace.
    if (ref.read(selectedWorkspaceIdProvider) == workspace.id) {
      ref.read(selectedWorkspaceIdProvider.notifier).select(null);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Workspace? workspace;
    if (!_isNew) {
      final value = ref.watch(workspaceByIdProvider(widget.workspaceId!));
      workspace = value.value;
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (workspace != null) _initFrom(workspace);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newWorkspace : l10n.editWorkspace),
        actions: [
          if (workspace != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(workspace!),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.workspaceName,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.nameRequired
                      : null,
            ),
            const SizedBox(height: 24),
            Text(l10n.colorLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in workspaceColors)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(color),
                      child: _color == color
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.iconLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in workspaceIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _icon = entry.key),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _icon == entry.key
                          ? Color(_color)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        entry.value,
                        color: _icon == entry.key
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.modulesLabel,
                style: Theme.of(context).textTheme.titleSmall),
            for (final module in ModuleKey.values)
              SwitchListTile(
                title: Text(moduleLabel(l10n, module)),
                value: _modules.contains(module),
                onChanged: (enabled) => setState(() {
                  if (enabled) {
                    _modules.add(module);
                  } else {
                    _modules.remove(module);
                  }
                }),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
