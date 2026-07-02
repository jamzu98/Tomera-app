import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'contact_providers.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Contact contact) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteContactTitle),
        content: Text(l10n.deleteContactBody(contact.name)),
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
    await ref.read(contactRepositoryProvider).delete(contact.id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final contactValue = ref.watch(contactByIdProvider(contactId));
    final contact = contactValue.value;
    if (contactValue.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (contact == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final roles = ref.watch(contactRolesProvider(contactId)).value ?? [];
    final workspaces = ref.watch(allWorkspacesProvider).value ?? [];
    final tasks = ref.watch(tasksForContactProvider(contactId)).value ?? [];
    final events = ref.watch(eventsForContactProvider(contactId)).value ?? [];
    final notes = ref.watch(notesForContactProvider(contactId)).value ?? [];

    Workspace? workspaceOf(String id) =>
        workspaces.where((w) => w.id == id).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editContact,
            onPressed: () => context.go('/contacts/$contactId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _delete(context, ref, contact),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (roles.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final role in roles)
                  if (workspaceOf(role.workspaceId) case final workspace?)
                    Chip(
                      avatar: Icon(Icons.circle,
                          size: 12, color: Color(workspace.color)),
                      label: Text(role.roleLabel?.isNotEmpty == true
                          ? '${workspace.name} · ${role.roleLabel}'
                          : workspace.name),
                    ),
              ],
            ),
          if (contact.organization?.isNotEmpty == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined),
              title: Text(contact.organization!),
            ),
          if (contact.email?.isNotEmpty == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: Text(contact.email!),
            ),
          if (contact.phone?.isNotEmpty == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(contact.phone!),
            ),
          if (contact.notesText?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(contact.notesText!,
                  style: theme.textTheme.bodyMedium),
            ),
          _Section(
            title: l10n.linkedTasks,
            children: [
              for (final task in tasks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    task.status == TaskStatus.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  title: Text(task.title),
                  onTap: () => context.go('/tasks/${task.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedEvents,
            children: [
              for (final event in events)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.circle,
                      size: 12,
                      color: Color(workspaceOf(event.workspaceId)?.color ??
                          0xFF888888)),
                  title: Text(event.title),
                  subtitle: Text(DateFormat.yMMMEd().add_Hm().format(
                      DateTime.fromMillisecondsSinceEpoch(event.startsAt,
                              isUtc: true)
                          .toLocal())),
                  onTap: () => context.go('/calendar/${event.id}'),
                ),
            ],
          ),
          _Section(
            title: l10n.linkedNotes,
            action: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addNoteAction),
              onPressed: () => context.go(
                  '/notes/new?parentType=contact&parentId=$contactId'),
            ),
            children: [
              for (final note in notes)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 18),
                  title: Text(note.title),
                  onTap: () => context.go('/notes/${note.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        if (children.isEmpty)
          Text(l10n.nothingLinkedYet, style: theme.textTheme.bodySmall)
        else
          ...children,
      ],
    );
  }
}
