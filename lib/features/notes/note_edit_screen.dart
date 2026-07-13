import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/markdown_style.dart';
import '../../core/providers.dart';
import '../../core/widgets/form_group.dart';
import '../../core/widgets/unsaved_changes_scope.dart';
import '../../core/widgets/workspace_avatar.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contact_providers.dart';
import '../finance/finance_providers.dart';
import '../projects/project_providers.dart';
import 'note_providers.dart';
import 'note_relationships.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({
    super.key,
    this.noteId,
    this.initialWorkspaceId,
    this.parentType,
    this.parentId,
  });

  /// Null when creating a new note.
  final String? noteId;
  final String? initialWorkspaceId;

  /// Optional polymorphic parent for a new note (e.g. created from a contact
  /// detail screen). Ignored when editing.
  final String? parentType;
  final String? parentId;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _workspaceId;
  ParentType? _parentType;
  String? _parentId;
  Set<NoteLinkTarget> _linkTargets = {};
  Set<NoteLinkTarget> _persistedLinkTargets = {};
  bool _preview = false;
  bool _initialized = false;
  bool _linksInitialized = false;
  List<Object?>? _baseline;
  bool _isDirty = false;

  bool get _isNew => widget.noteId == null;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.initialWorkspaceId;
    final requestedParentType = ParentType.values
        .where((type) => type.dbValue == widget.parentType)
        .firstOrNull;
    final requestedParentId = widget.parentId;
    if (_isNew &&
        requestedParentId != null &&
        (requestedParentType == ParentType.billable ||
            requestedParentType == ParentType.timerSession)) {
      _linkTargets = {(type: requestedParentType!, id: requestedParentId)};
    } else {
      _parentType = requestedParentType;
      _parentId = requestedParentType == null ? null : requestedParentId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _initFrom(Note note) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = note.title;
    _bodyController.text = note.body;
    _workspaceId = note.workspaceId;
    _parentType = note.parentType;
    _parentId = note.parentId;
  }

  void _initLinks(List<NoteLink> links) {
    if (_linksInitialized) return;
    _linksInitialized = true;
    final targets = {
      for (final link in links) (type: link.targetType, id: link.targetId),
    };
    _linkTargets = {...targets};
    _persistedLinkTargets = {...targets};
  }

  List<Object?> _snapshot() {
    final links =
        _linkTargets
            .map((target) => '${target.type.dbValue}:${target.id}')
            .toList()
          ..sort();
    return [
      _titleController.text,
      _bodyController.text,
      _workspaceId,
      _parentType,
      _parentId,
      ...links,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(noteRepositoryProvider);
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    final String noteId;
    if (_isNew) {
      noteId = await repository.create(
        workspaceId: _workspaceId,
        title: title,
        body: body,
        parentType: _parentType,
        parentId: _parentType != null ? _parentId : null,
      );
    } else {
      noteId = widget.noteId!;
      await repository.update(
        noteId,
        title: title,
        body: body,
        workspaceId: Value(_workspaceId),
        parentType: Value(_parentType),
        parentId: Value(_parentType == null ? null : _parentId),
      );
    }
    for (final target in _linkTargets.difference(_persistedLinkTargets)) {
      await repository.addLink(noteId, target.type, target.id);
    }
    for (final target in _persistedLinkTargets.difference(_linkTargets)) {
      await repository.removeLink(noteId, target.type, target.id);
    }
    _clearDirtyAndPop();
  }

  Future<void> _createTaskFromSelection() async {
    final l10n = AppLocalizations.of(context)!;
    final noteId = widget.noteId;
    final selection = _bodyController.selection;
    if (noteId == null ||
        !selection.isValid ||
        selection.isCollapsed ||
        selection.start < 0 ||
        selection.end > _bodyController.text.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectNoteTextFirst)));
      return;
    }
    final selected = _bodyController.text
        .substring(selection.start, selection.end)
        .trim();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectNoteTextFirst)));
      return;
    }
    final firstLine = selected
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => selected);
    final title = firstLine.length > 120
        ? '${firstLine.substring(0, 117)}…'
        : firstLine;
    await context.push(
      Uri(
        path: '/work/tasks/new',
        queryParameters: {
          if (_workspaceId != null) 'workspaceId': _workspaceId!,
          'title': title,
          if (selected != title) 'description': selected,
          'sourceNoteId': noteId,
        },
      ).toString(),
    );
  }

  Future<void> _showReferencePicker(List<NoteTargetOption> options) async {
    final l10n = AppLocalizations.of(context)!;
    final available = options
        .where((option) => !_linkTargets.contains(option.target))
        .toList();
    final selected = await showModalBottomSheet<NoteTargetOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l10n.addReferenceAction)),
            for (final option in available)
              ListTile(
                leading: Icon(option.icon),
                title: Text(option.label),
                subtitle: Text(noteTargetTypeLabel(l10n, option.target.type)),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      _change(() => _linkTargets.add(selected.target));
    }
  }

  Future<void> _delete(Note note) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(noteRepositoryProvider);
    await repository.delete(note.id);
    _clearDirtyAndPop(
      afterPop: () => messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.noteDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => repository.restore(note.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final contacts = ref.watch(allContactsProvider).value ?? [];
    final projects = ref.watch(allProjectsProvider).value ?? [];
    final tasks = ref.watch(allTasksForNoteLinksProvider).value ?? [];
    final events = ref.watch(allEventsForNoteLinksProvider).value ?? [];
    final billables = ref.watch(allBillablesProvider).value ?? [];
    final timers = ref.watch(allTimersForNoteLinksProvider).value ?? [];

    Note? note;
    if (!_isNew) {
      final value = ref.watch(noteByIdProvider(widget.noteId!));
      final linksValue = ref.watch(noteLinksProvider(widget.noteId!));
      note = value.value;
      if (value.isLoading || linksValue.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (note != null) {
        _initFrom(note);
        _initLinks(linksValue.value ?? const []);
      }
    } else if (!_initialized) {
      _initialized = true;
      _workspaceId ??= ref.read(selectedWorkspaceIdProvider);
      _linksInitialized = true;
    }
    _captureBaseline();

    final targetOptions = buildNoteTargetOptions(
      workspaces: workspaces,
      contacts: contacts,
      projects: projects,
      tasks: tasks,
      events: events,
      billables: billables,
      timers: timers,
    );
    final optionByKey = {
      for (final option in targetOptions) option.key: option,
    };
    final parentOptions = targetOptions
        .where(
          (option) => switch (option.target.type) {
            ParentType.workspace ||
            ParentType.contact ||
            ParentType.project ||
            ParentType.task ||
            ParentType.event => true,
            ParentType.billable || ParentType.timerSession => false,
          },
        )
        .toList();
    final parentKey = _parentType == null || _parentId == null
        ? null
        : '${_parentType!.dbValue}:$_parentId';
    final parentOption = parentKey == null ? null : optionByKey[parentKey];

    return UnsavedChangesScope(
      isDirty: _isDirty,
      dialogTitle: l10n.discardChangesTitle,
      dialogBody: l10n.discardChangesBody,
      keepEditingLabel: l10n.keepEditingAction,
      discardLabel: l10n.discardChangesAction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.newNote : l10n.editNote),
          actions: [
            if (note != null && !_preview)
              IconButton(
                icon: const Icon(Icons.add_task_rounded),
                tooltip: l10n.createTaskFromSelectionAction,
                onPressed: _createTaskFromSelection,
              ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.editTab)),
                ButtonSegment(value: true, label: Text(l10n.previewTab)),
              ],
              selected: {_preview},
              onSelectionChanged: (selection) =>
                  setState(() => _preview = selection.first),
            ),
            if (note != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.delete,
                onPressed: () => _delete(note!),
              ),
          ],
        ),
        bottomNavigationBar: SaveBar(label: l10n.save, onPressed: _save),
        body: Form(
          key: _formKey,
          onChanged: _syncDirty,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l10n.noteTitle),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.titleRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('note-workspace-$_workspaceId'),
                      initialValue: _workspaceId,
                      decoration: InputDecoration(
                        labelText: l10n.workspaceLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.noWorkspace),
                        ),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('parent-$parentKey'),
                            initialValue: parentKey,
                            decoration: InputDecoration(
                              labelText: l10n.parentRecordLabel,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.noParentRecord),
                              ),
                              if (parentKey != null &&
                                  !parentOptions.any(
                                    (option) => option.key == parentKey,
                                  ))
                                DropdownMenuItem(
                                  value: parentKey,
                                  child: Text(
                                    parentOption == null
                                        ? _parentId!
                                        : '${noteTargetTypeLabel(l10n, parentOption.target.type)} · ${parentOption.label}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              for (final option in parentOptions)
                                DropdownMenuItem(
                                  value: option.key,
                                  child: Text(
                                    '${noteTargetTypeLabel(l10n, option.target.type)} · '
                                    '${option.label}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (key) => _change(() {
                              final selected = key == null
                                  ? null
                                  : optionByKey[key];
                              _parentType = selected?.target.type;
                              _parentId = selected?.target.id;
                              if (selected?.workspaceId != null) {
                                _workspaceId = selected!.workspaceId;
                              }
                            }),
                          ),
                        ),
                        if (parentOption != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded),
                            tooltip: parentOption.label,
                            onPressed: () => context.push(parentOption.route),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.referencesLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final target in _linkTargets)
                            InputChip(
                              avatar: Icon(
                                noteTargetIcon(target.type),
                                size: 16,
                              ),
                              label: Text(
                                optionByKey['${target.type.dbValue}:${target.id}']
                                        ?.label ??
                                    noteTargetTypeLabel(l10n, target.type),
                              ),
                              onPressed: () => context.push(
                                optionByKey['${target.type.dbValue}:${target.id}']
                                        ?.route ??
                                    noteTargetRoute(target),
                              ),
                              onDeleted: () =>
                                  _change(() => _linkTargets.remove(target)),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 17),
                            label: Text(l10n.addReferenceAction),
                            onPressed: () =>
                                _showReferencePicker(targetOptions),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _preview
                      ? Markdown(
                          data: _bodyController.text,
                          padding: EdgeInsets.zero,
                          styleSheet: tomeraMarkdownStyleSheet(context),
                        )
                      : TextFormField(
                          controller: _bodyController,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: l10n.noteBodyHint,
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
