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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newBillable : l10n.editBillable),
        actions: [
          if (item != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.delete,
              onPressed: () => _delete(item!),
            ),
        ],
      ),
      bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            FormGroupCard(
              title: l10n.formGroupDetails,
              children: [
                FormFieldRow(
                  icon: Icons.title_rounded,
                  label: l10n.taskTitle,
                  child: TextFormField(
                    controller: _titleController,
                    style: inlineFieldStyle(context),
                    decoration:
                        inlineFieldDecoration(context, hint: l10n.taskTitle),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.titleRequired
                            : null,
                  ),
                ),
                FormFieldRow(
                  icon: Icons.notes_rounded,
                  label: l10n.descriptionLabel,
                  child: TextFormField(
                    controller: _descriptionController,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context,
                        hint: l10n.descriptionLabel),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                FormFieldRow(
                  icon: Icons.flag_outlined,
                  label: l10n.billableStatusLabel,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SegmentedButton<BillableStatus>(
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
                  ),
                ),
              ],
            ),
            FormGroupCard(
              title: l10n.formGroupAmount,
              children: [
                FormFieldRow(
                  icon: Icons.payments_outlined,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SegmentedButton<BillableType>(
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
                  ),
                ),
                if (_type == BillableType.hourly) ...[
                  FormFieldRow(
                    icon: Icons.speed_rounded,
                    label: l10n.rateLabel,
                    child: TextFormField(
                      controller: _rateController,
                      style: inlineFieldStyle(context),
                      decoration:
                          inlineFieldDecoration(context, hint: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) =>
                          _validateMoney(value, required: true),
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.timelapse_rounded,
                    label: l10n.durationMinutesLabel,
                    child: TextFormField(
                      controller: _durationController,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context, hint: '60'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          int.tryParse(value?.trim() ?? '') == null
                              ? l10n.invalidDuration
                              : null,
                    ),
                  ),
                ] else
                  FormFieldRow(
                    icon: Icons.request_quote_outlined,
                    label: l10n.amountLabel,
                    child: TextFormField(
                      controller: _amountController,
                      style: inlineFieldStyle(context),
                      decoration:
                          inlineFieldDecoration(context, hint: '0.00'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) =>
                          _validateMoney(value, required: true),
                    ),
                  ),
                FormFieldRow(
                  icon: Icons.currency_exchange_rounded,
                  label: l10n.currencyLabel,
                  child: TextFormField(
                    controller: _currencyController,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context, hint: 'EUR'),
                  ),
                ),
              ],
            ),
            FormGroupCard(
              title: l10n.formGroupLinks,
              children: [
                FormFieldRow(
                  icon: Icons.workspaces_outline,
                  label: l10n.workspaceLabel,
                  child: DropdownButtonFormField<String>(
                    initialValue: _workspaceId,
                    isDense: true,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context),
                    items: [
                      for (final w in workspaces)
                        DropdownMenuItem(
                          value: w.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                ),
                FormFieldRow(
                  icon: Icons.person_outline_rounded,
                  label: l10n.contactLabel,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _contactId,
                    isDense: true,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l10n.noContact)),
                      for (final contact in contacts)
                        DropdownMenuItem(
                          value: contact.id,
                          child: Text(contact.name),
                        ),
                    ],
                    onChanged: _onContactChanged,
                  ),
                ),
                FormFieldRow(
                  icon: Icons.layers_outlined,
                  label: l10n.projectLabel,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    isDense: true,
                    style: inlineFieldStyle(context),
                    decoration: inlineFieldDecoration(context),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l10n.noProject)),
                      for (final project in
                          ref.watch(allProjectsProvider).value ?? <Project>[])
                        DropdownMenuItem(
                          value: project.id,
                          child: Text(project.name),
                        ),
                    ],
                    onChanged: (id) => setState(() => _projectId = id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
