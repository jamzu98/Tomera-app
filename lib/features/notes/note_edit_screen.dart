import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'note_providers.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({super.key, this.noteId, this.parentType, this.parentId});

  /// Null when creating a new note.
  final String? noteId;

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
  bool _preview = false;
  bool _initialized = false;

  bool get _isNew => widget.noteId == null;

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
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(noteRepositoryProvider);
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    if (_isNew) {
      final parentType = ParentType.values
          .where((t) => t.dbValue == widget.parentType)
          .firstOrNull;
      await repository.create(
        workspaceId: _workspaceId,
        title: title,
        body: body,
        parentType: parentType,
        parentId: parentType != null ? widget.parentId : null,
      );
    } else {
      await repository.update(
        widget.noteId!,
        title: title,
        body: body,
        workspaceId: Value(_workspaceId),
      );
    }
    if (mounted) context.pop();
  }

  Future<void> _delete(Note note) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNoteTitle),
        content: Text(l10n.deleteNoteBody(note.title)),
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
    await ref.read(noteRepositoryProvider).delete(note.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];

    Note? note;
    if (!_isNew) {
      final value = ref.watch(noteByIdProvider(widget.noteId!));
      note = value.value;
      if (value.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (note != null) _initFrom(note);
    } else if (!_initialized) {
      _initialized = true;
      _workspaceId = ref.read(selectedWorkspaceIdProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newNote : l10n.editNote),
        actions: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
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
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: () => _delete(note!),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l10n.noteTitle,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.titleRequired
                            : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _workspaceId,
                    decoration: InputDecoration(
                      labelText: l10n.workspaceLabel,
                      border: const OutlineInputBorder(),
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
                              Icon(Icons.circle,
                                  size: 12, color: Color(w.color)),
                              const SizedBox(width: 8),
                              Text(w.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _workspaceId = id),
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
                      )
                    : TextFormField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          hintText: l10n.noteBodyHint,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
