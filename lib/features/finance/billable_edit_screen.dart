import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/more_options_section.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_providers.dart';
import '../contacts/contact_providers.dart';
import '../projects/project_providers.dart';
import '../tasks/task_providers.dart';
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
    this.initialTimerSessionId,
    this.initialTaskId,
    this.initialEventId,
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
  final String? initialTimerSessionId;
  final String? initialTaskId;
  final String? initialEventId;

  @override
  ConsumerState<BillableEditScreen> createState() => _BillableEditScreenState();
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
  bool _rateAutofilled = false;
  int _rateRequestRevision = 0;
  List<Object?>? _baseline;
  bool _isDirty = false;

  bool get _isNew => widget.billableId == null;
  bool get _isTimerConversion => _isNew && widget.initialTimerSessionId != null;
  bool get _hasLockedSource =>
      _isTimerConversion ||
      (_isNew &&
          (widget.initialTaskId != null || widget.initialEventId != null));

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
      Future.microtask(_refreshResolvedRate);
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
    _rateController.text = item.rateCents != null
        ? formatCents(item.rateCents!)
        : '';
    _durationController.text = item.durationMinutes?.toString() ?? '';
    _amountController.text = item.amountCents != null
        ? formatCents(item.amountCents!)
        : '';
    _currencyController.text = item.currency;
    _workspaceId = item.workspaceId;
    _contactId = item.contactId;
    _projectId = item.projectId;
    _type = item.type;
    _status = item.status;
  }

  List<Object?> _snapshot() => [
    _titleController.text,
    _descriptionController.text,
    _rateController.text,
    _durationController.text,
    _amountController.text,
    _currencyController.text,
    _workspaceId,
    _contactId,
    _projectId,
    _type,
    _status,
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

  void _clearDirtyAndPop({VoidCallback? afterPop}) {
    if (!mounted) return;
    setState(() {
      _baseline = _snapshot();
      _isDirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
        afterPop?.call();
      }
    });
  }

  /// Pre-fills the effective rate using project → workspace/contact →
  /// contact → workspace precedence. A value typed by the user is never
  /// overwritten when link context changes.
  Future<void> _refreshResolvedRate() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null ||
        _type != BillableType.hourly ||
        (_rateController.text.trim().isNotEmpty && !_rateAutofilled)) {
      return;
    }
    final revision = ++_rateRequestRevision;
    final contactId = _contactId;
    final projectId = _projectId;
    final rate = await ref
        .read(billableRepositoryProvider)
        .resolveHourlyRateCents(
          workspaceId: workspaceId,
          contactId: contactId,
          projectId: projectId,
        );
    if (!mounted || revision != _rateRequestRevision || rate == null) return;
    final wasDirty = _isDirty;
    setState(() {
      _rateController.text = formatCents(rate);
      _rateAutofilled = true;
      if (!wasDirty && _baseline != null) {
        _baseline = _snapshot();
        _isDirty = false;
      }
    });
  }

  Future<void> _onContactChanged(String? contactId) async {
    _change(() => _contactId = contactId);
    await _refreshResolvedRate();
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
    final rateCents = _type == BillableType.hourly
        ? parseCents(_rateController.text)
        : null;
    final durationMinutes = _type == BillableType.hourly
        ? int.tryParse(_durationController.text.trim())
        : null;
    final amountCents = _type == BillableType.fixed
        ? parseCents(_amountController.text)
        : null;

    if (_isNew) {
      final timerSessionId = widget.initialTimerSessionId;
      if (timerSessionId != null) {
        final session = await ref
            .read(timerRepositoryProvider)
            .getById(timerSessionId);
        if (session == null || session.stoppedAt == null) return;
        await repository.createFromTimer(
          session: session,
          title: title,
          description: description.isEmpty ? null : description,
          rateCents: rateCents,
          durationMinutes: durationMinutes,
          currency: currency,
          status: _status,
        );
      } else {
        await repository.create(
          workspaceId: workspaceId,
          contactId: _contactId,
          eventId: widget.initialEventId,
          taskId: widget.initialTaskId,
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
      }
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
    _clearDirtyAndPop();
  }

  Future<void> _delete(BillableItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(billableRepositoryProvider);
    await repository.delete(item.id);
    _clearDirtyAndPop(
      afterPop: () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.billableDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => repository.restore(item.id),
          ),
        ),
      ),
    );
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
    final sourceTaskId = item?.taskId ?? widget.initialTaskId;
    final sourceEventId = item?.eventId ?? widget.initialEventId;
    final sourceTask = sourceTaskId == null
        ? null
        : ref.watch(taskByIdProvider(sourceTaskId)).value;
    final sourceEvent = sourceEventId == null
        ? null
        : ref.watch(eventByIdProvider(sourceEventId)).value;
    _workspaceId ??=
        ref.read(selectedWorkspaceIdProvider) ??
        (workspaces.isNotEmpty ? workspaces.first.id : null);
    if (_isNew &&
        _type == BillableType.hourly &&
        _rateController.text.trim().isEmpty) {
      Future.microtask(_refreshResolvedRate);
    }
    final projects = (ref.watch(allProjectsProvider).value ?? <Project>[])
        .where((project) => project.workspaceId == _workspaceId)
        .toList(growable: false);

    if (workspaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newBillable : l10n.editBillable),
        ),
        body: Center(child: Text(l10n.createWorkspaceFirst)),
      );
    }
    _captureBaseline();

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
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
          onChanged: _syncDirty,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      textInputAction: TextInputAction.next,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.taskTitle,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.titleRequired
                          : null,
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.flag_outlined,
                    label: l10n.billableStatusLabel,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 300) {
                            return DropdownButton<BillableStatus>(
                              value: _status,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final status in BillableStatus.values)
                                  DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      billableStatusLabel(l10n, status),
                                    ),
                                  ),
                              ],
                              onChanged: (status) {
                                if (status != null) {
                                  _change(() => _status = status);
                                }
                              },
                            );
                          }
                          return SegmentedButton<BillableStatus>(
                            segments: [
                              for (final status in BillableStatus.values)
                                ButtonSegment(
                                  value: status,
                                  label: Text(
                                    billableStatusLabel(l10n, status),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                            ],
                            selected: {_status},
                            onSelectionChanged: (selection) =>
                                _change(() => _status = selection.first),
                          );
                        },
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
                            _change(() => _type = selection.first),
                      ),
                    ),
                  ),
                  if (_type == BillableType.hourly) ...[
                    FormFieldRow(
                      icon: Icons.speed_rounded,
                      label: l10n.rateLabel,
                      child: TextFormField(
                        controller: _rateController,
                        onChanged: (_) => _rateAutofilled = false,
                        style: inlineFieldStyle(context),
                        decoration: inlineFieldDecoration(
                          context,
                          hint: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
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
                        textInputAction: TextInputAction.next,
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
                        decoration: inlineFieldDecoration(
                          context,
                          hint: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            _validateMoney(value, required: true),
                      ),
                    ),
                  FormFieldRow(
                    icon: Icons.currency_exchange_rounded,
                    label: l10n.currencyLabel,
                    child: TextFormField(
                      controller: _currencyController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
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
                      key: ValueKey('billable-workspace-$_workspaceId'),
                      initialValue:
                          workspaces.any(
                            (workspace) => workspace.id == _workspaceId,
                          )
                          ? _workspaceId
                          : null,
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
                      onChanged: _hasLockedSource
                          ? null
                          : (id) {
                              _change(() {
                                if (_workspaceId != id) {
                                  _contactId = null;
                                  _projectId = null;
                                }
                                _workspaceId = id;
                              });
                              _refreshResolvedRate();
                            },
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.contactLabel,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('billable-contact-$_contactId'),
                      initialValue:
                          contacts.any((contact) => contact.id == _contactId)
                          ? _contactId
                          : null,
                      isDense: true,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.noContact),
                        ),
                        for (final contact in contacts)
                          DropdownMenuItem(
                            value: contact.id,
                            child: Text(contact.name),
                          ),
                      ],
                      onChanged: _hasLockedSource ? null : _onContactChanged,
                    ),
                  ),
                  FormFieldRow(
                    icon: Icons.layers_outlined,
                    label: l10n.projectLabel,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('billable-project-$_projectId'),
                      initialValue:
                          projects.any((project) => project.id == _projectId)
                          ? _projectId
                          : null,
                      isDense: true,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(context),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.noProject),
                        ),
                        for (final project in projects)
                          DropdownMenuItem(
                            value: project.id,
                            child: Text(project.name),
                          ),
                      ],
                      onChanged: _hasLockedSource
                          ? null
                          : (id) {
                              _change(() {
                                _projectId = id;
                                final project = projects
                                    .where((candidate) => candidate.id == id)
                                    .firstOrNull;
                                if (project?.contactId != null) {
                                  _contactId = project!.contactId;
                                }
                              });
                              _refreshResolvedRate();
                            },
                    ),
                  ),
                  if (sourceTask != null)
                    FormFieldRow(
                      icon: Icons.task_alt_outlined,
                      label: l10n.tabTasks,
                      onTap: () => context.push('/work/tasks/${sourceTask.id}'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                      child: Text(
                        sourceTask.title,
                        style: inlineFieldStyle(context),
                      ),
                    ),
                  if (sourceEvent != null)
                    FormFieldRow(
                      icon: Icons.event_outlined,
                      label: l10n.activityEvent,
                      onTap: () => context.push('/calendar/${sourceEvent.id}'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                      child: Text(
                        sourceEvent.title,
                        style: inlineFieldStyle(context),
                      ),
                    ),
                ],
              ),
              MoreOptionsSection(
                initiallyExpanded: _descriptionController.text
                    .trim()
                    .isNotEmpty,
                children: [
                  FormFieldRow(
                    icon: Icons.notes_rounded,
                    label: l10n.descriptionLabel,
                    child: TextFormField(
                      controller: _descriptionController,
                      textInputAction: TextInputAction.newline,
                      style: inlineFieldStyle(context),
                      decoration: inlineFieldDecoration(
                        context,
                        hint: l10n.descriptionLabel,
                      ),
                      minLines: 1,
                      maxLines: 5,
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
