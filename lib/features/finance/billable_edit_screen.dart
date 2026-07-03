import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import 'finance_providers.dart';
import 'finance_screen.dart' show billableStatusLabel;

class BillableEditScreen extends ConsumerStatefulWidget {
  const BillableEditScreen({
    super.key,
    this.billableId,
    this.initialContactId,
    this.initialWorkspaceId,
    this.initialTitle,
    this.initialDurationMinutes,
    this.initialProjectId,
  });

  /// Null when creating a new item.
  final String? billableId;

  /// Pre-selected values when created from a contact detail screen or a
  /// stopped work timer (spec §6.6). Ignored when editing.
  final String? initialContactId;
  final String? initialWorkspaceId;
  final String? initialTitle;
  final int? initialDurationMinutes;
  final String? initialProjectId;

  @override
  ConsumerState<BillableEditScreen> createState() =>
      _BillableEditScreenState();
}

class _BillableEditScreenState extends ConsumerState<BillableEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rateController = TextEditingController();
  final _durationController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'EUR');
  String? _workspaceId;
  String? _contactId;
  String? _projectId;
  BillableType _type = BillableType.hourly;
  BillableStatus _status = BillableStatus.unbilled;
  bool _initialized = false;

  bool get _isNew => widget.billableId == null;

  @override
  void initState() {
    super.initState();
    _contactId = widget.initialContactId;
    if (_isNew) {
      _workspaceId = widget.initialWorkspaceId;
      _projectId = widget.initialProjectId;
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialDurationMinutes != null) {
        _durationController.text = '${widget.initialDurationMinutes}';
      }
      if (_contactId != null) {
        // Pre-fill the rate when opened with a contact pre-selected too.
        Future.microtask(() => _onContactChanged(_contactId));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _durationController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _initFrom(BillableItem item) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = item.title;
    _descriptionController.text = item.description ?? '';
    _rateController.text =
        item.rateCents != null ? formatCents(item.rateCents!) : '';
    _durationController.text = item.durationMinutes?.toString() ?? '';
    _amountController.text =
        item.amountCents != null ? formatCents(item.amountCents!) : '';
    _currencyController.text = item.currency;
    _workspaceId = item.workspaceId;
    _contactId = item.contactId;
    _projectId = item.projectId;
    _type = item.type;
    _status = item.status;
  }

  /// Pre-fill the hourly rate from the contact's default (spec §6.6).
  Future<void> _onContactChanged(String? contactId) async {
    setState(() => _contactId = contactId);
    if (contactId == null || _rateController.text.trim().isNotEmpty) return;
    final contact =
        await ref.read(contactRepositoryProvider).getById(contactId);
    final rate = contact?.defaultHourlyRateCents;
    if (rate != null && mounted && _rateController.text.trim().isEmpty) {
      setState(() => _rateController.text = formatCents(rate));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final repository = ref.read(billableRepositoryProvider);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final currency = _currencyController.text.trim().isEmpty
        ? 'EUR'
        : _currencyController.text.trim().toUpperCase();
    final rateCents =
        _type == BillableType.hourly ? parseCents(_rateController.text) : null;
    final durationMinutes = _type == BillableType.hourly
        ? int.tryParse(_durationController.text.trim())
        : null;
    final amountCents =
        _type == BillableType.fixed ? parseCents(_amountController.text) : null;

    if (_isNew) {
      await repository.create(
        workspaceId: workspaceId,
        contactId: _contactId,
        projectId: _projectId,
        type: _type,
        title: title,
        description: description.isEmpty ? null : description,
        rateCents: rateCents,
        durationMinutes: durationMinutes,
        amountCents: amountCents,
        currency: currency,
        status: _status,
      );
    } else {
      await repository.update(
        widget.billableId!,
        workspaceId: workspaceId,
        type: _type,
        title: title,
        currency: currency,
        status: _status,
        contactId: Value(_contactId),
        projectId: Value(_projectId),
        description: Value(description.isEmpty ? null : description),
        rateCents: Value(rateCents),
        durationMinutes: Value(durationMinutes),
        amountCents: Value(amountCents),
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete(BillableItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBillableTitle),
        content: Text(l10n.deleteBillableBody(item.title)),
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
    await ref.read(billableRepositoryProvider).delete(item.id);
    if (mounted) context.pop();
  }

  String? _validateMoney(String? value, {required bool required}) {
    final l10n = AppLocalizations.of(context)!;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? l10n.invalidAmount : null;
    return parseCents(text) == null ? l10n.invalidAmount : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];

    BillableItem? item;
    if (!_isNew) {
      final value = ref.watch(billableByIdProvider(widget.billableId!));
      item = value.value;
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (item != null) _initFrom(item);
    }
    _workspaceId ??= ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: Text(_isNew ? l10n.newBillable : l10n.editBillable)),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }

    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newBillable : l10n.editBillable),
        actions: [
          if (item != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(item!),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: decoration(l10n.taskTitle),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.titleRequired
                  : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<BillableType>(
              segments: [
                ButtonSegment(
                  value: BillableType.hourly,
                  label: Text(l10n.typeHourly),
                ),
                ButtonSegment(
                  value: BillableType.fixed,
                  label: Text(l10n.typeFixed),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            if (_type == BillableType.hourly) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      decoration: decoration(l10n.rateLabel),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) =>
                          _validateMoney(value, required: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: decoration(l10n.durationMinutesLabel),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          int.tryParse(value?.trim() ?? '') == null
                              ? l10n.invalidDuration
                              : null,
                    ),
                  ),
                ],
              ),
            ] else
              TextFormField(
                controller: _amountController,
                decoration: decoration(l10n.amountLabel),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateMoney(value, required: true),
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
                        Icon(Icons.circle, size: 12, color: Color(w.color)),
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
              onChanged: _onContactChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _projectId,
              decoration: decoration(l10n.projectLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noProject)),
                for (final project
                    in ref.watch(allProjectsProvider).value ?? <Project>[])
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
              ],
              onChanged: (id) => setState(() => _projectId = id),
            ),
            const SizedBox(height: 16),
            Text(l10n.billableStatusLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<BillableStatus>(
              segments: [
                for (final status in BillableStatus.values)
                  ButtonSegment(
                    value: status,
                    label: Text(billableStatusLabel(l10n, status)),
                  ),
              ],
              selected: {_status},
              onSelectionChanged: (selection) =>
                  setState(() => _status = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyController,
              decoration: decoration(l10n.currencyLabel),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: decoration(l10n.descriptionLabel),
              minLines: 2,
              maxLines: 5,
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
