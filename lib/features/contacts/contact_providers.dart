import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';

/// Contacts visible under the current workspace filter: all contacts in the
/// all-workspaces view, or only contacts linked to the selected workspace.
final visibleContactsProvider = StreamProvider.autoDispose<List<Contact>>(
  (ref) => ref
      .watch(contactRepositoryProvider)
      .watchAll(workspaceId: ref.watch(selectedWorkspaceIdProvider)),
);

/// All contacts regardless of filter (for link pickers in editors).
final allContactsProvider = StreamProvider.autoDispose<List<Contact>>(
  (ref) => ref.watch(contactRepositoryProvider).watchAll(),
);

/// One contact by id (detail/edit screens).
final contactByIdProvider = StreamProvider.autoDispose.family<Contact?, String>(
  (ref, id) => ref.watch(contactRepositoryProvider).watchById(id),
);

/// Active workspace-role rows for one contact.
final contactRolesProvider = StreamProvider.autoDispose
    .family<List<WorkspaceContact>, String>(
      (ref, contactId) =>
          ref.watch(contactRepositoryProvider).watchRoles(contactId),
    );

/// Linked entities for the contact detail screen (spec §6.5).
final tasksForContactProvider = StreamProvider.autoDispose
    .family<List<Task>, String>(
      (ref, contactId) =>
          ref.watch(taskRepositoryProvider).watchForContact(contactId),
    );

final eventsForContactProvider = StreamProvider.autoDispose
    .family<List<Event>, String>(
      (ref, contactId) =>
          ref.watch(eventRepositoryProvider).watchForContact(contactId),
    );

final notesForContactProvider = StreamProvider.autoDispose
    .family<List<Note>, String>(
      (ref, contactId) => ref
          .watch(noteRepositoryProvider)
          .watchByParent(ParentType.contact, contactId),
    );

/// Contact ids linked to an event (event editor chips).
final eventContactIdsProvider = StreamProvider.autoDispose
    .family<Set<String>, String>(
      (ref, eventId) =>
          ref.watch(eventRepositoryProvider).watchContactIds(eventId),
    );

final timersForContactProvider = StreamProvider.autoDispose
    .family<List<TimerSession>, String>(
      (ref, contactId) =>
          ref.watch(timerRepositoryProvider).watchAll(contactId: contactId),
    );
