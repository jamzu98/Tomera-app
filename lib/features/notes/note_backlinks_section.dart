import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/soft_tile.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'note_providers.dart';

/// Shows both directly-parented notes and reference backlinks for a record.
class NoteBacklinksSection extends ConsumerWidget {
  const NoteBacklinksSection({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.workspaceId,
  });

  final ParentType targetType;
  final String targetId;
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final target = (type: targetType, id: targetId);
    final parented = ref.watch(notesByParentProvider(target)).value ?? [];
    final backlinks = ref.watch(noteBacklinksProvider(target)).value ?? [];
    final byId = <String, Note>{
      for (final note in parented) note.id: note,
      for (final note in backlinks) note.id: note,
    };
    final notes = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.linkedNotes,
          padding: const EdgeInsets.fromLTRB(22, 18, 16, 4),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.addNoteAction),
              onPressed: () => context.push(
                Uri(
                  path: '/work/notes/new',
                  queryParameters: {
                    'parentType': targetType.dbValue,
                    'parentId': targetId,
                    if (workspaceId != null) 'workspaceId': workspaceId!,
                  },
                ).toString(),
              ),
            ),
          ),
        ),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              l10n.nothingLinkedYet,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final note in notes)
            SoftTile(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              leading: Icon(
                Icons.description_outlined,
                size: 20,
                color: context.tokens.ink2,
              ),
              title: Text(note.title),
              onTap: () => context.push('/work/notes/${note.id}'),
            ),
      ],
    );
  }
}
