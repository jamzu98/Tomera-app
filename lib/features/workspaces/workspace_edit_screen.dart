import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/section_header.dart';
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newWorkspace : l10n.editWorkspace),
        actions: [
          if (workspace != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.delete,
              onPressed: () => _delete(workspace!),
            ),
        ],
      ),
      bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.workspaceName),
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? l10n.nameRequired
                      : null,
            ),
            SectionHeader(
              title: l10n.colorLabel,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final color in workspaceColors)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _color = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(14),
                        border: _color == color
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 2.5)
                            : Border.all(
                                color: theme.colorScheme.outlineVariant),
                      ),
                      child: _color == color
                          ? Icon(Icons.check_rounded,
                              size: 22,
                              color: workspaceForeground(Color(color)))
                          : null,
                    ),
                  ),
              ],
            ),
            SectionHeader(
              title: l10n.iconLabel,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              children: [
                for (final entry in workspaceIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _icon = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: _icon == entry.key
                            ? Color(_color)
                            : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _icon == entry.key
                              ? Colors.transparent
                              : theme.colorScheme.outline,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        size: 22,
                        color: _icon == entry.key
                            ? workspaceForeground(Color(_color))
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            SectionHeader(
              title: l10n.modulesLabel,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            // Material (not a decorated Container) so ListTile ink renders.
            Material(
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, module) in ModuleKey.values.indexed) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant),
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
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
