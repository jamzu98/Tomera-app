import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/more_options_section.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
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
  final _rateController = TextEditingController();
  String? _workspaceId;
  String? _contactId;

  /// Null means "inherit the workspace color".
  int? _color;
  bool _archived = false;
  bool _initialized = false;
  List<Object?>? _baseline;
  bool _isDirty = false;

  bool get _isNew => widget.projectId == null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _initFrom(Project project) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = project.name;
    _descriptionController.text = project.description ?? '';
    final rate = project.hourlyRateCents;
    _rateController.text = rate == null ? '' : formatCents(rate);
    _workspaceId = project.workspaceId;
    _contactId = project.contactId;
    _color = project.color;
    _archived = project.archived;
  }

  List<Object?> _snapshot() => [
    _nameController.text,
    _descriptionController.text,
    _rateController.text,
    _workspaceId,
    _contactId,
    _color,
    _archived,
  ];

  void _captureBaseline() => _baseline ??= _snapshot();

  void _syncDirty() {
    final baseline = _baseline;
    if (baseline == null || !mounted) return;
    final isDirty = !listEquals(baseline, _snapshot());
    if (isDirty != _isDirty) setState(() => _isDirty = isDirty);
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
      final baseline = _baseline;
      if (baseline != null) {
        _isDirty = !listEquals(baseline, _snapshot());
      }
    });
  }

  void _clearDirtyAndPop() {
    if (!mounted) return;
    setState(() {
      _baseline = _snapshot();
      _isDirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final repository = ref.read(projectRepositoryProvider);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final hourlyRateCents = parseCents(_rateController.text);

    if (_isNew) {
      await repository.create(
        workspaceId: workspaceId,
        name: name,
        description: description.isEmpty ? null : description,
        color: _color,
        contactId: _contactId,
        hourlyRateCents: hourlyRateCents,
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
        hourlyRateCents: Value(hourlyRateCents),
      );
    }
    _clearDirtyAndPop();
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
    _workspaceId ??=
        ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newProject : l10n.editProject),
        ),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }
    _captureBaseline();

    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label);

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newProject : l10n.editProject),
        ),
        bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
        body: Form(
          key: _formKey,
          onChanged: _syncDirty,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                onChanged: (id) => _change(() => _workspaceId = id),
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
                onChanged: (id) => _change(() => _contactId = id),
              ),
              const SizedBox(height: 16),
              MoreOptionsSection(
                padding: EdgeInsets.zero,
                initiallyExpanded:
                    _descriptionController.text.trim().isNotEmpty ||
                    _rateController.text.trim().isNotEmpty ||
                    _color != null ||
                    _archived,
                children: [
                  FormFieldRow(
                    icon: Icons.palette_outlined,
                    label: l10n.colorLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          Tooltip(
                            message: l10n.useWorkspaceColor,
                            child: _ColorSwatch(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              selected: _color == null,
                              icon: _color == null
                                  ? Icons.check_rounded
                                  : Icons.format_color_reset_rounded,
                              iconColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              onTap: () => _change(() => _color = null),
                            ),
                          ),
                          for (final color in workspaceColors)
                            _ColorSwatch(
                              color: Color(color),
                              selected: _color == color,
                              icon: _color == color
                                  ? Icons.check_rounded
                                  : null,
                              iconColor: workspaceForeground(Color(color)),
                              onTap: () => _change(() => _color = color),
                            ),
                        ],
                      ),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.payments_outlined,
                    label: l10n.defaultRateLabel,
                    child: TextFormField(
                      controller: _rateController,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context, hint: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          (value != null &&
                              value.trim().isNotEmpty &&
                              parseCents(value) == null)
                          ? l10n.invalidAmount
                          : null,
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.notes_rounded,
                    label: l10n.descriptionLabel,
                    child: TextFormField(
                      controller: _descriptionController,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.descriptionLabel,
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                  ),
                  if (!_isNew)
                    FormFieldRow(
                      icon: Icons.archive_outlined,
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.archivedLabel)),
                          Switch(
                            value: _archived,
                            onChanged: (value) =>
                                _change(() => _archived = value),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
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
