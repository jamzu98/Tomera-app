import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/soft_tile.dart';
import '../../core/widgets/workspace_switcher_pill.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../workspaces/workspace_style.dart';
import 'contact_detail_screen.dart' show initialsOf;
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
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-contacts',
        tooltip: l10n.newContact,
        onPressed: () => context.go('/contacts/new'),
        child: const Icon(Icons.add_rounded),
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
                  padding: const EdgeInsets.only(top: 6, bottom: 88),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) =>
                      _ContactTile(contact: contacts[index]),
                ),
              AsyncValue(isLoading: true) =>
                const Center(child: CircularProgressIndicator()),
              _ => EmptyState(
                  icon: Icons.group_outlined,
                  title: l10n.emptyContactsTitle,
                  body: l10n.emptyContactsBody,
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
    // Deterministic identity color per contact from the workspace palette.
    final color =
        Color(workspaceColors[contact.name.hashCode % workspaceColors.length]);
    return SoftTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          initialsOf(contact.name),
          style: TextStyle(
            fontFamily: displayFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: workspaceForeground(color),
          ),
        ),
      ),
      title: Text(contact.name),
      subtitle: contact.organization?.isNotEmpty == true
          ? Text(contact.organization!)
          : null,
      onTap: () => context.go('/contacts/${contact.id}'),
    );
  }
}
