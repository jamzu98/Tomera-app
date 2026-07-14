import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/editorial.dart';
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
    final moduleDisabled =
        selectedWorkspace != null &&
        !selectedWorkspace.enabledModules.contains(ModuleKey.contacts);

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Center(child: WorkspaceSwitcherPill(compact: true)),
          SizedBox(width: 4),
          AppBarOverflowMenu(),
        ],
      ),
      body: Column(
        children: [
          EditorialScreenHeader(
            title: l10n.tabContacts,
            subtitle: selectedWorkspace?.name,
          ),
          Expanded(
            child: moduleDisabled
                ? EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: l10n.moduleDisabledTitle,
                    body: l10n.contactsModuleDisabled,
                    primaryAction: EmptyStateAction(
                      label: l10n.editWorkspace,
                      icon: Icons.tune_rounded,
                      onPressed: () =>
                          context.push('/workspaces/${selectedWorkspace.id}'),
                    ),
                  )
                : switch (contactsValue) {
                    AsyncValue(value: final contacts?)
                        when contacts.isNotEmpty =>
                      ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          EditorialPanel(
                            children: [
                              for (final contact in contacts)
                                _ContactTile(contact: contact, embedded: true),
                            ],
                          ),
                        ],
                      ),
                    AsyncValue(isLoading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    AsyncValue(hasError: true) => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.unableToLoadTitle,
                      body: l10n.unableToLoadBody,
                      retryLabel: l10n.retry,
                      onRetry: () => ref.invalidate(visibleContactsProvider),
                    ),
                    _ => EmptyState(
                      icon: Icons.group_outlined,
                      title: l10n.emptyContactsTitle,
                      body: l10n.emptyContactsBody,
                      primaryAction: EmptyStateAction(
                        label: l10n.newContact,
                        icon: Icons.add_rounded,
                        onPressed: () => context.go('/contacts/new'),
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
  const _ContactTile({required this.contact, this.embedded = false});

  final Contact contact;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Deterministic identity color per contact from the workspace palette.
    final color = Color(
      workspaceColors[contact.name.hashCode % workspaceColors.length],
    );
    return SoftTile(
      embedded: embedded,
      margin: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
