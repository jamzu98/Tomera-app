import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/workspace_filter_button.dart';
import '../../core/widgets/workspaces_button.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'contact_providers.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contactsValue = ref.watch(visibleContactsProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider).value;
    final moduleDisabled = selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.contacts);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabContacts),
        actions: const [WorkspaceFilterButton(), WorkspacesButton()],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newContact,
        onPressed: () => context.go('/contacts/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (moduleDisabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.contactsModuleDisabled,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: switch (contactsValue) {
              AsyncValue(value: final contacts?) when contacts.isNotEmpty =>
                ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) =>
                      _ContactTile(contact: contacts[index]),
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.emptyContactsTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(l10n.emptyContactsBody),
                    ],
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(contact.name))),
      title: Text(contact.name),
      subtitle: contact.organization?.isNotEmpty == true
          ? Text(contact.organization!)
          : null,
      onTap: () => context.go('/contacts/${contact.id}'),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
