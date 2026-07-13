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
import 'contact_providers.dart';

class ContactEditScreen extends ConsumerStatefulWidget {
  const ContactEditScreen({super.key, this.contactId, this.initialWorkspaceId});

  /// Null when creating a new contact.
  final String? contactId;
  final String? initialWorkspaceId;

  @override
  ConsumerState<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends ConsumerState<ContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();
  final _notesController = TextEditingController();
  final _rateController = TextEditingController();

  /// Workspace id → role label for workspaces this contact belongs to.
  final Map<String, TextEditingController> _roleControllers = {};
  final Map<String, TextEditingController> _workspaceRateControllers = {};
  Set<String> _memberWorkspaceIds = {};
  bool _initialized = false;
  bool _rolesInitialized = false;
  List<Object?>? _baseline;
  bool _isDirty = false;

  bool get _isNew => widget.contactId == null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _notesController.dispose();
    _rateController.dispose();
    for (final controller in _roleControllers.values) {
      controller.dispose();
    }
    for (final controller in _workspaceRateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initFrom(Contact contact) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = contact.name;
    _emailController.text = contact.email ?? '';
    _phoneController.text = contact.phone ?? '';
    _organizationController.text = contact.organization ?? '';
    _notesController.text = contact.notesText ?? '';
    final rate = contact.defaultHourlyRateCents;
    _rateController.text = rate != null ? formatCents(rate) : '';
  }

  void _initRoles(List<WorkspaceContact> roles) {
    if (_rolesInitialized) return;
    _rolesInitialized = true;
    _memberWorkspaceIds = roles.map((r) => r.workspaceId).toSet();
    for (final role in roles) {
      _roleControllers[role.workspaceId] = TextEditingController(
        text: role.roleLabel ?? '',
      );
      _workspaceRateControllers[role.workspaceId] = TextEditingController(
        text: role.hourlyRateCents == null
            ? ''
            : formatCents(role.hourlyRateCents!),
      );
    }
    if (_isNew) {
      final workspaceId = widget.initialWorkspaceId;
      if (workspaceId != null) {
        _memberWorkspaceIds.add(workspaceId);
        _roleControllerFor(workspaceId);
      }
    }
  }

  TextEditingController _roleControllerFor(String workspaceId) =>
      _roleControllers.putIfAbsent(workspaceId, TextEditingController.new);

  TextEditingController _workspaceRateControllerFor(String workspaceId) =>
      _workspaceRateControllers.putIfAbsent(
        workspaceId,
        TextEditingController.new,
      );

  List<Object?> _snapshot() {
    final workspaceIds = _memberWorkspaceIds.toList()..sort();
    return [
      _nameController.text,
      _emailController.text,
      _phoneController.text,
      _organizationController.text,
      _notesController.text,
      _rateController.text,
      for (final id in workspaceIds)
        '$id\u0000${_roleControllerFor(id).text}'
            '\u0000${_workspaceRateControllerFor(id).text}',
    ];
  }

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
    final repository = ref.read(contactRepositoryProvider);
    final name = _nameController.text.trim();
    String? emptyToNull(String text) =>
        text.trim().isEmpty ? null : text.trim();
    final rateCents = parseCents(_rateController.text);

    final String contactId;
    if (_isNew) {
      contactId = await repository.create(
        name: name,
        email: emptyToNull(_emailController.text),
        phone: emptyToNull(_phoneController.text),
        organization: emptyToNull(_organizationController.text),
        notesText: emptyToNull(_notesController.text),
        defaultHourlyRateCents: rateCents,
      );
    } else {
      contactId = widget.contactId!;
      await repository.update(
        contactId,
        name: name,
        email: Value(emptyToNull(_emailController.text)),
        phone: Value(emptyToNull(_phoneController.text)),
        organization: Value(emptyToNull(_organizationController.text)),
        notesText: Value(emptyToNull(_notesController.text)),
        defaultHourlyRateCents: Value(rateCents),
      );
    }

    // Sync workspace roles against the edited membership set.
    final existing = _isNew
        ? const <WorkspaceContact>[]
        : await repository.getRoles(contactId);
    final existingIds = existing.map((r) => r.workspaceId).toSet();
    for (final workspaceId in _memberWorkspaceIds) {
      final label = emptyToNull(_roleControllerFor(workspaceId).text);
      final workspaceRateCents = parseCents(
        _workspaceRateControllerFor(workspaceId).text,
      );
      final current = existing
          .where((r) => r.workspaceId == workspaceId)
          .firstOrNull;
      if (current == null ||
          current.roleLabel != label ||
          current.hourlyRateCents != workspaceRateCents) {
        await repository.setRole(
          contactId,
          workspaceId,
          label,
          hourlyRateCents: Value(workspaceRateCents),
        );
      }
    }
    for (final workspaceId in existingIds.difference(_memberWorkspaceIds)) {
      await repository.removeRole(contactId, workspaceId);
    }

    _clearDirtyAndPop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    if (!_isNew) {
      final contactValue = ref.watch(contactByIdProvider(widget.contactId!));
      final rolesValue = ref.watch(contactRolesProvider(widget.contactId!));
      if (contactValue.isLoading || rolesValue.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final contact = contactValue.value;
      if (contact != null) _initFrom(contact);
      _initRoles(rolesValue.value ?? const []);
    } else {
      _initRoles(const []);
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
          title: Text(_isNew ? l10n.newContact : l10n.editContact),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: decoration(l10n.emailLabel),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: decoration(l10n.phoneLabel),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _organizationController,
                decoration: decoration(l10n.organizationLabel),
              ),
              const SizedBox(height: 12),
              MoreOptionsSection(
                padding: EdgeInsets.zero,
                initiallyExpanded:
                    _rateController.text.trim().isNotEmpty ||
                    _notesController.text.trim().isNotEmpty,
                children: [
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
                    label: l10n.contactNotesLabel,
                    child: TextFormField(
                      controller: _notesController,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.contactNotesLabel,
                      ),
                      minLines: 2,
                      maxLines: 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                l10n.rolesLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final workspace in workspaces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _memberWorkspaceIds.contains(workspace.id),
                            onChanged: (checked) => _change(() {
                              if (checked == true) {
                                _memberWorkspaceIds.add(workspace.id);
                              } else {
                                _memberWorkspaceIds.remove(workspace.id);
                              }
                            }),
                          ),
                          WorkspaceDot(color: Color(workspace.color), size: 12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              workspace.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_memberWorkspaceIds.contains(workspace.id))
                        Padding(
                          padding: const EdgeInsets.only(left: 48, bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _roleControllerFor(workspace.id),
                                  decoration: InputDecoration(
                                    labelText: l10n.roleHint,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _workspaceRateControllerFor(
                                    workspace.id,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.workspaceRateLabel,
                                    isDense: true,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
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
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
