import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../workspaces/workspace_style.dart';
import 'project_providers.dart';

class ProjectEditScreen extends ConsumerStatefulWidget {
  const ProjectEditScreen({super.key, this.projectId});

  /// Null when creating a new project.
  final String? projectId;

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _workspaceId;
  String? _contactId;

  /// Null means "inherit the workspace color".
  int? _color;
  bool _archived = false;
  bool _initialized = false;

  bool get _isNew => widget.projectId == null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFrom(Project project) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = project.name;
    _descriptionController.text = project.description ?? '';
    _workspaceId = project.workspaceId;
    _contactId = project.contactId;
    _color = project.color;
    _archived = project.archived;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final repository = ref.read(projectRepositoryProvider);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (_isNew) {
      await repository.create(
        workspaceId: workspaceId,
        name: name,
        description: description.isEmpty ? null : description,
        color: _color,
        contactId: _contactId,
      );
    } else {
      await repository.update(
        widget.projectId!,
        workspaceId: workspaceId,
        name: name,
        archived: _archived,
        description: Value(description.isEmpty ? null : description),
        color: Value(_color),
        contactId: Value(_contactId),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];

    if (!_isNew) {
      final value = ref.watch(projectByIdProvider(widget.projectId!));
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final project = value.value;
      if (project != null) _initFrom(project);
    }
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? l10n.newProject : l10n.editProject)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }

    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newProject : l10n.editProject),
      ),
      bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: decoration(l10n.contactName),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.nameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _workspaceId,
              decoration: decoration(l10n.workspaceLabel),
              items: [
                for (final w in workspaces)
                  DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        WorkspaceDot(color: Color(w.color), size: 12),
                        const SizedBox(width: 8),
                        Text(w.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _workspaceId = id),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _contactId,
              decoration: decoration(l10n.contactLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noContact)),
                for (final contact in contacts)
                  DropdownMenuItem(
                    value: contact.id,
                    child: Text(contact.name),
                  ),
              ],
              onChanged: (id) => setState(() => _contactId = id),
            ),
            const SizedBox(height: 16),
            Text(l10n.colorLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                // First option: inherit the workspace color (null).
                Tooltip(
                  message: l10n.useWorkspaceColor,
                  child: _ColorSwatch(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    selected: _color == null,
                    icon: _color == null
                        ? Icons.check_rounded
                        : Icons.format_color_reset_rounded,
                    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    onTap: () => setState(() => _color = null),
                  ),
                ),
                for (final color in workspaceColors)
                  _ColorSwatch(
                    color: Color(color),
                    selected: _color == color,
                    icon: _color == color ? Icons.check_rounded : null,
                    iconColor: workspaceForeground(Color(color)),
                    onTap: () => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: decoration(l10n.descriptionLabel),
              minLines: 2,
              maxLines: 5,
            ),
            if (!_isNew)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.archivedLabel),
                value: _archived,
                onChanged: (value) => setState(() => _archived = value),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounded-square palette swatch with a selection ring (mock's picker style).
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: icon != null ? Icon(icon, size: 20, color: iconColor) : null,
      ),
    );
  }
}
