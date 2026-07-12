import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'contact_providers.dart';

class ContactEditScreen extends ConsumerStatefulWidget {
  const ContactEditScreen({super.key, this.contactId});

  /// Null when creating a new contact.
  final String? contactId;

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
  Set<String> _memberWorkspaceIds = {};
  bool _initialized = false;
  bool _rolesInitialized = false;

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
      _roleControllers[role.workspaceId] =
          TextEditingController(text: role.roleLabel ?? '');
    }
  }

  TextEditingController _roleControllerFor(String workspaceId) =>
      _roleControllers.putIfAbsent(workspaceId, TextEditingController.new);

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
    final existing =
        _isNew ? const <WorkspaceContact>[] : await repository.getRoles(contactId);
    final existingIds = existing.map((r) => r.workspaceId).toSet();
    for (final workspaceId in _memberWorkspaceIds) {
      final label = emptyToNull(_roleControllerFor(workspaceId).text);
      final current =
          existing.where((r) => r.workspaceId == workspaceId).firstOrNull;
      if (current == null || current.roleLabel != label) {
        await repository.setRole(contactId, workspaceId, label);
      }
    }
    for (final workspaceId in existingIds.difference(_memberWorkspaceIds)) {
      await repository.removeRole(contactId, workspaceId);
    }

    if (mounted) context.pop();
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
    }

    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newContact : l10n.editContact),
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
            TextFormField(
              controller: _rateController,
              decoration: decoration(l10n.defaultRateLabel),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) =>
                  (value != null && value.trim().isNotEmpty &&
                          parseCents(value) == null)
                      ? l10n.invalidAmount
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: decoration(l10n.contactNotesLabel),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Text(l10n.rolesLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final workspace in workspaces)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _memberWorkspaceIds.contains(workspace.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _memberWorkspaceIds.add(workspace.id);
                        } else {
                          _memberWorkspaceIds.remove(workspace.id);
                        }
                      }),
                    ),
                    WorkspaceDot(color: Color(workspace.color), size: 12),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: Text(workspace.name,
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _roleControllerFor(workspace.id),
                        enabled: _memberWorkspaceIds.contains(workspace.id),
                        decoration: InputDecoration(
                          hintText: l10n.roleHint,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
