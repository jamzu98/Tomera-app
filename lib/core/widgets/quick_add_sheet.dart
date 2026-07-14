import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../providers.dart';
import 'workspace_avatar.dart';

/// Context inherited by creation flows opened from the global quick-add menu.
///
/// Workspace is always made explicit by [QuickAddSheet]. Project and contact
/// context are never remembered globally; callers provide them only when the
/// user opens quick-add from a related record.
@immutable
class CreationContext {
  const CreationContext({this.workspaceId, this.projectId, this.contactId});

  final String? workspaceId;
  final String? projectId;
  final String? contactId;

  CreationContext copyWith({
    String? workspaceId,
    String? projectId,
    String? contactId,
    bool clearProject = false,
    bool clearContact = false,
  }) => CreationContext(
    workspaceId: workspaceId ?? this.workspaceId,
    projectId: clearProject ? null : projectId ?? this.projectId,
    contactId: clearContact ? null : contactId ?? this.contactId,
  );

  Map<String, String> get _sharedQuery => {
    if (workspaceId != null) 'workspaceId': workspaceId!,
    if (projectId != null) 'projectId': projectId!,
    if (contactId != null) 'contactId': contactId!,
  };

  /// Canonical editor destination for an action. The shell may handle
  /// [QuickAddAction.startTimer] directly instead of navigating to its URI.
  Uri destinationFor(QuickAddAction action) {
    final path = switch (action) {
      QuickAddAction.task => '/work/tasks/new',
      QuickAddAction.event => '/calendar/new',
      QuickAddAction.note => '/work/notes/new',
      QuickAddAction.contact => '/contacts/new',
      QuickAddAction.billable => '/finance/new',
      QuickAddAction.startTimer => '/finance',
    };
    final query = <String, String>{..._sharedQuery};
    if (action == QuickAddAction.note) {
      if (projectId != null) {
        query
          ..['parentType'] = 'project'
          ..['parentId'] = projectId!;
      } else if (contactId != null) {
        query
          ..['parentType'] = 'contact'
          ..['parentId'] = contactId!;
      }
    }
    if (action == QuickAddAction.startTimer) query['startTimer'] = 'true';
    return Uri(path: path, queryParameters: query.isEmpty ? null : query);
  }
}

enum QuickAddAction {
  task(ModuleKey.tasks),
  event(ModuleKey.calendar),
  note(ModuleKey.notes),
  contact(ModuleKey.contacts),
  billable(ModuleKey.finance),
  startTimer(ModuleKey.finance);

  const QuickAddAction(this.requiredModule);

  final ModuleKey requiredModule;
}

@immutable
class QuickAddSelection {
  const QuickAddSelection({required this.action, required this.context});

  final QuickAddAction action;
  final CreationContext context;

  Uri get destination => context.destinationFor(action);
}

/// Shows quick-add and returns the selected action with an explicit workspace.
Future<QuickAddSelection?> showQuickAddSheet(
  BuildContext context, {
  CreationContext creationContext = const CreationContext(),
}) => showModalBottomSheet<QuickAddSelection>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => QuickAddSheet(creationContext: creationContext),
);

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.creationContext = const CreationContext(),
  });

  final CreationContext creationContext;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  String? _workspaceId;
  bool _initialized = false;

  void _select(QuickAddAction action) {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    final workspaceChanged =
        widget.creationContext.workspaceId != null &&
        widget.creationContext.workspaceId != workspaceId;
    final context = widget.creationContext.copyWith(
      workspaceId: workspaceId,
      clearProject: workspaceChanged,
      clearContact: workspaceChanged,
    );
    Navigator.of(
      this.context,
    ).pop(QuickAddSelection(action: action, context: context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspacesValue = ref.watch(allWorkspacesProvider);
    final workspaces = workspacesValue.value ?? const <Workspace>[];
    if (!_initialized && !workspacesValue.isLoading) {
      final preferred =
          widget.creationContext.workspaceId ??
          ref.read(selectedWorkspaceIdProvider);
      _workspaceId = workspaces.any((workspace) => workspace.id == preferred)
          ? preferred
          : null;
      _initialized = true;
    }
    final workspace = workspaces
        .where((candidate) => candidate.id == _workspaceId)
        .firstOrNull;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.quickAdd,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(_workspaceId),
              initialValue: _workspaceId,
              decoration: InputDecoration(
                labelText: l10n.workspaceLabel,
                helperText: _workspaceId == null
                    ? l10n.quickAddChooseWorkspace
                    : null,
              ),
              isExpanded: true,
              items: [
                for (final candidate in workspaces)
                  DropdownMenuItem(
                    value: candidate.id,
                    child: Row(
                      children: [
                        WorkspaceDot(color: Color(candidate.color), size: 11),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            candidate.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: workspaces.isEmpty
                  ? null
                  : (id) => setState(() => _workspaceId = id),
            ),
            const SizedBox(height: 12),
            if (workspacesValue.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (workspaces.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l10n.createWorkspaceFirst,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final action in QuickAddAction.values)
                        _QuickAddTile(
                          action: action,
                          enabled:
                              workspace != null &&
                              workspace.enabledModules.contains(
                                action.requiredModule,
                              ),
                          onTap: () => _select(action),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final QuickAddAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, icon) = switch (action) {
      QuickAddAction.task => (l10n.newTask, Icons.task_alt_rounded),
      QuickAddAction.event => (l10n.newEvent, Icons.event_rounded),
      QuickAddAction.note => (l10n.newNote, Icons.note_add_rounded),
      QuickAddAction.contact => (l10n.newContact, Icons.person_add_rounded),
      QuickAddAction.billable => (l10n.newBillable, Icons.receipt_long_rounded),
      QuickAddAction.startTimer => (l10n.startTimer, Icons.play_arrow_rounded),
    };
    return ListTile(
      enabled: enabled,
      minTileHeight: 52,
      leading: Icon(icon),
      title: Text(label),
      subtitle: enabled ? null : Text(l10n.moduleUnavailableInWorkspace),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    );
  }
}
